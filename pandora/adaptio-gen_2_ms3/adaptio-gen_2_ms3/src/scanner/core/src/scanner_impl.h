#pragma once

#include <boost/asio/thread_pool.hpp>
#include <functional>

#include "common/groove/groove.h"
#include "scanner/core/src/scanner.h"
#include "scanner/core/src/scanner_metrics.h"
#include "scanner/image_logger/image_logger.h"
#include "scanner/image_provider/image_provider.h"
#include "scanner/joint_model/joint_model.h"
#include "scanner/slice_provider/slice_provider.h"

namespace scanner {

auto const WINDOW_MARGIN              = 100;
auto const MOVE_MARGIN                = 40;
auto const MINIMUM_FOV_HEIGHT         = 500;
auto const MAX_SURFACE_MISSING_FRAMES = 25;

using LaserCallback = std::function<void(bool state)>;

class ScannerImpl : public Scanner {
 public:
  /**
   * Constructs a new scanner that takes in images, processes them and puts the result in a joint model.
   *
   * @param image_provider An image provider
   * @param camera_model   A camera model
   * @param slice_provider The slice provider
   * @param laser_toggle   A callback that sets the laser state
   */
  ScannerImpl(image_provider::ImageProvider* image_provider, slice_provider::SliceProviderPtr slice_provider,
              LaserCallback laser_toggle, ScannerOutputCB* scanner_output, joint_model::JointModelPtr joint_model,
              image_logger::ImageLogger* image_logger, ScannerMetrics* metrics);
  ScannerImpl(const ScannerImpl&)                        = delete;
  auto operator=(const ScannerImpl&) -> ScannerImpl&     = delete;
  ScannerImpl(ScannerImpl&&) noexcept                    = delete;
  auto operator=(ScannerImpl&&) noexcept -> ScannerImpl& = delete;

  ~ScannerImpl() override = default;

  void Update() override;
  void UpdateJointApproximation(const joint_model::JointProperties& properties,
                                const std::tuple<double, double>& abw0_abw6_horizontal) override;
  void ImageGrabbed(std::unique_ptr<image::Image> image) override;
  size_t CountOfReceivedImages() override;

  static auto NewOffsetAndHeight(int top, int bottom) -> std::tuple<int, int>;

  // Test-only hook: let tests run image processing in same thread
  void SetPostExecutorForTests(std::function<void(std::function<void()>)> exec);
  void SetJointGeometry(const joint_model::JointProperties& properties) override;

 private:
  void CheckResetOfFOV(joint_model::JointModelErrorCode error, std::optional<joint_model::JointProfile>& median,
                       int vertical_crop_start);

  void UpdateFovAndGainFromProfile(const joint_model::JointProfile& profile, int current_offset, int current_height);
  image_provider::ImageProvider* image_provider_;
  joint_model::JointModelPtr joint_model_;
  slice_provider::SliceProviderPtr slice_provider_;
  LaserCallback laser_toggle_;
  ScannerOutputCB* scanner_output_;
  image_logger::ImageLogger* image_logger_;
  std::optional<std::tuple<double, double>> maybe_abw0_abw6_horizontal_;
  ScannerMetrics* metrics_;

  boost::asio::thread_pool m_threadpool;
  std::mutex m_buffer_mutex;  // Protects joint_buffer_
  std::mutex m_config_mutex;  // Protects all other members

  size_t num_received = 0;
  std::optional<std::tuple<int, int>> awaiting_new_dimensions_;
  size_t frames_since_gain_change_ = 0;
  bool store_image_data_;
  std::array<common::Point, joint_model::INTERPOLATED_SNAKE_SIZE> latest_raw_profile_{};

  joint_model::JointProperties properties_;
  bool properties_updated_{};
  std::function<void(std::function<void()>)> post_;
  size_t frames_without_surface_ = 0;
};

class ScannerOutputCBImpl : public ScannerOutputCB {
 public:
  void ScannerOutput(const common::Groove& groove,
                     const std::array<common::Point, joint_model::INTERPOLATED_SNAKE_SIZE>& profile,
                     uint64_t time_stamp, slice_provider::SliceConfidence confidence) override {};
};

class ScannerExposed : public ScannerImpl {
 public:
  ScannerExposed(image_provider::ImageProvider* image_provider, slice_provider::SliceProviderPtr slice_provider,
                 const LaserCallback& laser_toggle, ScannerOutputCBImpl* scanner_ouput_cb,
                 joint_model::JointModelPtr joint_model, image_logger::ImageLogger* image_logger,
                 ScannerMetrics* metrics)
      : ScannerImpl(image_provider, std::move(slice_provider), laser_toggle, scanner_ouput_cb, std::move(joint_model),
                    image_logger, metrics) {}

  using ScannerImpl::Update;
};

}  // namespace scanner

namespace std {
template <>
struct is_error_code_enum<scanner::ScannerErrorCode> : true_type {};
}  // namespace std
