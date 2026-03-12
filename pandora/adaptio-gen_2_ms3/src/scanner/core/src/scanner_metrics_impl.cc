#include "scanner/core/src/scanner_metrics_impl.h"

#include <vector>

namespace scanner {

ScannerMetricsImpl::ScannerMetricsImpl(prometheus::Registry* registry) {
  {
    auto& counter = prometheus::BuildCounter()
                        .Name("scanner_image_process_success")
                        .Help("Number of processed successful images including the number of walls found.")
                        .Register(*registry);

    image_.emplace(0, &counter.Add({
                          {"found", "0"}
    }));
    image_.emplace(1, &counter.Add({
                          {"found", "1"}
    }));
    image_.emplace(2, &counter.Add({
                          {"found", "2"}
    }));
  }

  {
    auto& counter = prometheus::BuildCounter()
                        .Name("scanner_image_process_errors")
                        .Help("Number of processed error images including the failure reason.")
                        .Register(*registry);

    auto const codes = {
        joint_model::JointModelErrorCode::NO_ERROR,
        joint_model::JointModelErrorCode::SURFACE_NOT_FOUND,
        joint_model::JointModelErrorCode::WEDGE_FIT_FAILED,
        joint_model::JointModelErrorCode::GROOVE_BOTTOM_NOT_FOUND,
        joint_model::JointModelErrorCode::GROOVE_WALL_CENTROIDS_NOT_FOUND,
        joint_model::JointModelErrorCode::MISSING_WEDGE_HISTORY,
        joint_model::JointModelErrorCode::INVALID_SNAKE,
        joint_model::JointModelErrorCode::INVALID_WALL_HEIGHT_DIFFERENCE,
        joint_model::JointModelErrorCode::SURFACE_ANGLE_TOLERANCE_EXCEEDED,
        joint_model::JointModelErrorCode::JOINT_WIDTH_OUT_OF_TOLERANCE,
        joint_model::JointModelErrorCode::TWO_WALLS_NOT_FOUND,
    };

    for (auto code : codes) {
      image_errors_.emplace(code, &counter.Add({
                                      {"error", joint_model::JointModelErrorCodeToSnakeCaseString(code)}
      }));
    }
  }

  {
    const std::vector<double> buckets = {
        0.005,  // 5 ms
        0.010,  // 10 ms
        0.020,  // 20 ms
        0.030,  // 30 ms
        0.040,  // 40 ms
        0.050,  // 50 ms
        0.060,  // 60 ms
        0.070,  // 70 ms
        0.080,  // 80 ms
        0.090,  // 90 ms
        0.100,  // 100 ms
        0.150,  // 150 ms
        0.200,  // 200 ms
    };

    auto& histogram = prometheus::BuildHistogram()
                          .Name("scanner_image_processing_duration_seconds")
                          .Help("Histogram of image processing durations for both successful and failed images.")
                          .Register(*registry);

    image_processing_time_ = &histogram.Add({}, buckets);
  }

  {
    image_consecutive_errors_ = &prometheus::BuildGauge()
                                     .Name("scanner_image_process_consecutive_errors")
                                     .Help("Number of consecutive error for processed.")
                                     .Register(*registry)
                                     .Add({});
  }
}

void ScannerMetricsImpl::IncImageProcessed(int num_walls_found) {
  if (image_.contains(num_walls_found)) {
    image_.at(num_walls_found)->Increment();
  }
}

void ScannerMetricsImpl::IncImageProcessingError(joint_model::JointModelErrorCode error) {
  if (image_errors_.contains(error)) {
    image_errors_.at(error)->Increment();
  }
}

void ScannerMetricsImpl::ObserveImageProcessingDuration(double seconds) { image_processing_time_->Observe(seconds); }

void ScannerMetricsImpl::SetConsecutiveErrors(double value) { image_consecutive_errors_->Set(value); }

void ScannerMetricsImpl::IncConsecutiveErrors(double value) { image_consecutive_errors_->Increment(value); }

auto ScannerMetricsImpl::GetConsecutiveErrors() -> double { return image_consecutive_errors_->Value(); }

}  // namespace scanner