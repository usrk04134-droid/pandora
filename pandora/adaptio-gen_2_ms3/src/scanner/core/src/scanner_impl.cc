#include "scanner/core/src/scanner_impl.h"

#include <boost/asio/post.hpp>
#include <chrono>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <ctime>
#include <Eigen/Core>
#include <functional>
#include <memory>
#include <optional>
#include <string>
#include <system_error>
#include <tuple>
#include <utility>

#include "common/logging/application_log.h"
#include "scanner/core/src/scanner.h"
#include "scanner/core/src/scanner_metrics.h"
#include "scanner/image/image.h"
#include "scanner/image/image_types.h"  // IWYU pragma: keep
#include "scanner/image_logger/image_logger.h"
#include "scanner/image_provider/image_provider.h"
#include "scanner/joint_model/joint_model.h"
#include "scanner/slice_provider/slice_provider.h"

namespace scanner {
// #define DEBUG_RESULT_OUTPUT 1

#if defined(DEBUG_RESULT_OUTPUT)
#include <format>
#include <fstream>
#include <ios>
#include <ostream>
#endif

ScannerImpl::ScannerImpl(image_provider::ImageProvider* image_provider, slice_provider::SliceProviderPtr slice_provider,
                         LaserCallback laser_toggle, ScannerOutputCB* scanner_output,
                         joint_model::JointModelPtr joint_model, image_logger::ImageLogger* image_logger,
                         ScannerMetrics* metrics)
    : image_provider_(image_provider),
      joint_model_(std::move(joint_model)),
      slice_provider_(std::move(slice_provider)),
      laser_toggle_(std::move(laser_toggle)),
      scanner_output_(scanner_output),
      image_logger_(image_logger),
      metrics_(metrics),
      m_threadpool(12),
      store_image_data_(false) {
  post_ = [this](std::function<void()> fn) { boost::asio::post(m_threadpool, std::move(fn)); };
}

auto ScannerImpl::NewOffsetAndHeight(int top, int bottom) -> std::tuple<int, int> {
  auto new_offset = (top > WINDOW_MARGIN) ? (top - WINDOW_MARGIN) : 0;
  auto new_height = (bottom - new_offset) + WINDOW_MARGIN;

  if (new_height < MINIMUM_FOV_HEIGHT) {
    const auto adjust = (MINIMUM_FOV_HEIGHT - new_height) / 2;
    new_offset        = (new_offset > adjust) ? (new_offset - adjust) : 0;
    new_height        = MINIMUM_FOV_HEIGHT;
  }
  return {new_offset, new_height};
}

void ScannerImpl::ImageGrabbed(std::unique_ptr<image::Image> image) {
  auto sp_image = std::shared_ptr<image::Image>(std::move(image));
  post_([this, image = std::move(sp_image)]() {
    // When image capture is faster than parsing we need to be able to evaluate concurrently across multiple cores
    // This means that Parse should be a constant function. Any state should be recoverable from the latest slice.

    auto const start_timstamp = std::chrono::steady_clock::now();
    auto log_failed_image     = false;
    std::string reason_failed_image;

    m_buffer_mutex.lock();
    auto median_profile    = slice_provider_->GetSlice();
    auto use_approximation = slice_provider_->SliceDegraded();
    m_buffer_mutex.unlock();

    m_config_mutex.lock();
    auto properties                 = properties_;
    auto properties_updated         = properties_updated_;
    auto maybe_abw0_abw6_horizontal = maybe_abw0_abw6_horizontal_;
    m_config_mutex.unlock();

    num_received++;

    std::optional<joint_model::JointModelErrorCode> error = {};

    auto profile_result = joint_model_->ImageToProfiles(*image.get(), median_profile);

    if (!profile_result) {
      error = profile_result.error();
    } else {
      auto [snake, interpolated_snake, min_pixel_value, crop_start, profile_processing_time] = profile_result.value();

      if (interpolated_snake) {
        std::lock_guard<std::mutex> lock(m_buffer_mutex);
        latest_raw_profile_ = interpolated_snake.value();
      }

      auto parse_result = joint_model_->ParseProfile(snake, min_pixel_value, crop_start, median_profile, properties,
                                                     properties_updated, use_approximation, maybe_abw0_abw6_horizontal);

      if (!parse_result) {
        error = parse_result.error();
      } else {
        auto [profile, parse_processing_time, num_walls_found] = *parse_result;
        auto processing_time                                   = parse_processing_time + profile_processing_time;
        LOG_TRACE("Processed image {} in {} + {} = {} ms.", image->GetImageName(), profile_processing_time,
                  parse_processing_time, processing_time);
        slice_provider::JointSlice slice = {.uuid                = image->GetUuid(),
                                            .timestamp           = image->GetTimestamp(),
                                            .image_name          = image->GetImageName(),
                                            .profile             = profile,
                                            .num_walls_found     = num_walls_found,
                                            .processing_time     = processing_time,
                                            .vertical_crop_start = image->GetVerticalCropStart(),
                                            .approximation_used  = profile.approximation_used};
        if (store_image_data_) {
          // Store image data only if necessary. Not needed when running Adaptio
          slice.image_data = image->Data();
        }

        {
          std::lock_guard<std::mutex> lock(m_buffer_mutex);
          slice_provider_->AddSlice(slice);
        }

        const int current_offset = image->GetVerticalCropStart();
        const int current_height = image->Data().rows();

        UpdateFovAndGainFromProfile(profile, current_offset, current_height);

        metrics_->IncImageProcessed(slice.num_walls_found);
        metrics_->SetConsecutiveErrors(0);
      }
    }

    if (error) {
      LOG_ERROR("Unable to parse joint in image {}: {}", image->GetImageName(),
                JointModelErrorCodeToString(error.value()));

      CheckResetOfFOV(error.value(), median_profile, image->GetVerticalCropStart());

      metrics_->IncImageProcessingError(error.value());

      /* only log the first image consecutive when the image processing fails */
      log_failed_image    = metrics_->GetConsecutiveErrors() == 0;
      reason_failed_image = joint_model::JointModelErrorCodeToSnakeCaseString(error.value());

      metrics_->IncConsecutiveErrors(1);
    }

    image_logger::ImageLoggerEntry entry = {
        .image    = image.get(),
        .x_offset = 0,
        .y_offset = static_cast<uint32_t>(image->GetVerticalCropStart()),
    };

    if (log_failed_image) {
      image_logger_->LogImageError(entry, reason_failed_image);
    } else {
      image_logger_->LogImage(entry);
    }

    std::chrono::duration<double> const duration_seconds = std::chrono::steady_clock::now() - start_timstamp;
    metrics_->ObserveImageProcessingDuration(duration_seconds.count());
  });
}

void ScannerImpl::UpdateFovAndGainFromProfile(const joint_model::JointProfile& profile, int current_offset,
                                              int current_height) {
  const auto [top, bottom] = profile.vertical_limits;

  std::lock_guard<std::mutex> lock(m_config_mutex);

  // On successful parse we have a surface.
  frames_without_surface_ = 0;

  const bool dims_ok = awaiting_new_dimensions_
                           .transform([&](std::tuple<int, int> requested) {
                             auto [requested_offset, requested_height] = requested;
                             return requested_offset == current_offset && requested_height == current_height;
                           })
                           .value_or(true);

  if (dims_ok) {
    // Check min/max vertical pixels in the image and evaluate whether we want to adjust the FOV
    // Note: this assumes that the original offset is 0.
    // We want current_offset + WINDOW_MARGIN = top
    // and current_offset + height - WINDOW_MARGIN = bottom
    // If we are more than MOVE_MARGIN away from either of these two we recalculate

    const bool reduced_fov_valid =
        current_height == MINIMUM_FOV_HEIGHT && bottom - top + 2 * WINDOW_MARGIN <= MINIMUM_FOV_HEIGHT &&
        current_offset + WINDOW_MARGIN <= top && bottom + WINDOW_MARGIN <= current_offset + current_height;

    const bool needs_move =
        !reduced_fov_valid && ((std::abs((top - WINDOW_MARGIN) - current_offset) > MOVE_MARGIN) ||
                               (std::abs((bottom + WINDOW_MARGIN) - (current_offset + current_height)) > MOVE_MARGIN));

    if (needs_move) {
      auto [new_offset, new_height] = ScannerImpl::NewOffsetAndHeight(top, bottom);

      if (new_offset != current_offset || new_height != current_height) {
        LOG_TRACE(
            "Change FOV based on top {} bottom {}, current_offset {}, current_height {}, new_offset {} new_height {}",
            top, bottom, current_offset, current_height, new_offset, new_height);

        awaiting_new_dimensions_ = {new_offset, new_height};
        image_provider_->SetVerticalFOV(new_offset, new_height);
      }
    } else {
      awaiting_new_dimensions_ = std::nullopt;
    }
  }

  if (++frames_since_gain_change_ > 100 && profile.suggested_gain_change.has_value()) {
    image_provider_->AdjustGain(profile.suggested_gain_change.value());
    frames_since_gain_change_ = 0;
  }
}

auto CheckIfValueInRange(double value, double target, double range) -> bool {
  return value >= target - range && value <= target + range;
}

auto ScannerImpl::CountOfReceivedImages() -> size_t { return num_received; }

void ScannerImpl::Update() {
  m_buffer_mutex.lock();
  auto tracking_data = slice_provider_->GetTrackingSlice();
  auto raw_profile   = latest_raw_profile_;
  m_buffer_mutex.unlock();

  if (tracking_data.has_value()) {
    auto [groove, confidence, time_stamp] = tracking_data.value();
    scanner_output_->ScannerOutput(groove, raw_profile, time_stamp, confidence);
  } else {
    LOG_ERROR("No slice sent due to missing ABW points.");
  }
}

void ScannerImpl::UpdateJointApproximation(const joint_model::JointProperties& properties,
                                           const std::tuple<double, double>& abw0_abw6_horizontal) {
  if (!properties.Valid()) {
    LOG_ERROR(
        "Faulty joint geometry: width {:.5f} width tolerance {:.5f} left angle {} right angle {:.5f} angle tolerance "
        "{:.5f}",
        properties.upper_joint_width, properties.upper_joint_width_tolerance, properties.left_joint_angle,
        properties.right_joint_angle, properties.groove_angle_tolerance);

    return;
  }

  m_config_mutex.lock();
  properties_         = properties;
  properties_updated_ = true;

  auto [abw0_horizontal, abw6_horizontal] = abw0_abw6_horizontal;
  if (abw6_horizontal > abw0_horizontal) {
    maybe_abw0_abw6_horizontal_ = abw0_abw6_horizontal;
  }

  m_config_mutex.unlock();

  LOG_TRACE("Joint properties updated: width {:.5f} left angle {:.5f} right angle {:.5f}", properties.upper_joint_width,
            properties.left_joint_angle, properties.right_joint_angle);

  if (abw6_horizontal > abw0_horizontal) {
    LOG_TRACE("Joint approximation updated: abw0 horizontal {:.5f} abw6 horizontal {:.5f}", abw0_horizontal,
              abw6_horizontal);
  }
}

void ScannerImpl::CheckResetOfFOV(joint_model::JointModelErrorCode error,
                                  std::optional<joint_model::JointProfile>& median, int vertical_crop_start) {
  std::lock_guard<std::mutex> lock(m_config_mutex);
  auto const surface_missing = (error == joint_model::JointModelErrorCode::SURFACE_NOT_FOUND);

  frames_without_surface_ = surface_missing ? frames_without_surface_ + 1 : 0;

  auto const too_many_frames_no_surface = frames_without_surface_ == MAX_SURFACE_MISSING_FRAMES;

  if (!median.has_value()) {
    if ((!awaiting_new_dimensions_.has_value() && vertical_crop_start != 0 && frames_since_gain_change_ > 25) ||
        too_many_frames_no_surface) {
      LOG_TRACE("Resetting FOV and gain due to empty history and unsuccessful joint parsing.");
      image_provider_->ResetFOVAndGain();
      awaiting_new_dimensions_ = {image_provider_->GetVerticalFOVOffset(), image_provider_->GetVerticalFOVHeight()};
    }
  }
}

// Error code implementation
namespace {

struct ErrorCategory : std::error_category {
  auto name() const noexcept -> const char* final;          // NOLINT(*-use-nodiscard)
  auto message(int error_code) const -> std::string final;  // NOLINT(*-use-nodiscard)
  auto default_error_condition(int other) const noexcept    // NOLINT(*-use-nodiscard)
      -> std::error_condition final;                        // NOLINT(*-use-nodiscard)
};

auto ErrorCategory::name() const noexcept -> const char* { return "ScannerError"; }

auto ErrorCategory::message(int error_code) const -> std::string {
  switch (static_cast<ScannerErrorCode>(error_code)) {
    case ScannerErrorCode::NO_ERROR:
      return "No error";
    case ScannerErrorCode::NO_JOINT_PROPERTIES:
      return "Joint properties is not set";
  }
}

auto ErrorCategory::default_error_condition(int other) const noexcept -> std::error_condition {
  switch (static_cast<ScannerErrorCode>(other)) {
    default:
      return {other, *this};
  }
}

const ErrorCategory ERROR_CATEGORY{};

}  // namespace

[[maybe_unused]] auto make_error_code(ScannerErrorCode error_code) -> std::error_code {  // NOLINT(*-identifier-naming)
  return {static_cast<int>(error_code), ERROR_CATEGORY};
}

void ScannerImpl::SetPostExecutorForTests(std::function<void(std::function<void()>)> exec) { post_ = std::move(exec); }

void ScannerImpl::SetJointGeometry(const joint_model::JointProperties& properties) {
  LOG_DEBUG("ScannerImpl::SetJointGeometry");

  {
    std::lock_guard<std::mutex> lock(m_config_mutex);
    if (image_provider_ && !image_provider_->Started()) {
      auto on_image = [this](std::unique_ptr<image::Image> img) -> void { ImageGrabbed(std::move(img)); };
      image_provider_->SetOnImage(on_image);

      if (!image_provider_->Start()) {
        LOG_ERROR("ScannerApplication::Failed to start image provider");
      }
      LOG_DEBUG("ScannerApplication::Image provider started");
    }
    maybe_abw0_abw6_horizontal_ = {};
    properties_                 = properties;
    properties_updated_         = false;
    awaiting_new_dimensions_    = std::nullopt;
  }
}
}  // namespace scanner
