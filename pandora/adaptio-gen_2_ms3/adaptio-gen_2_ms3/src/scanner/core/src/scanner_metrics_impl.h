#pragma once

#include <prometheus/counter.h>
#include <prometheus/gauge.h>
#include <prometheus/histogram.h>
#include <prometheus/registry.h>

#include <map>

#include "scanner/core/src/scanner_metrics.h"
#include "scanner/joint_model/joint_model.h"

namespace scanner {

class ScannerMetricsImpl : public ScannerMetrics {
 public:
  explicit ScannerMetricsImpl(prometheus::Registry* registry);

  void IncImageProcessed(int num_walls_found) override;
  void IncImageProcessingError(joint_model::JointModelErrorCode error) override;
  void ObserveImageProcessingDuration(double seconds) override;
  void SetConsecutiveErrors(double value) override;
  void IncConsecutiveErrors(double value) override;
  auto GetConsecutiveErrors() -> double override;

 private:
  std::map<joint_model::JointModelErrorCode, prometheus::Counter*> image_errors_;
  std::map<uint64_t, prometheus::Counter*> image_;
  prometheus::Histogram* image_processing_time_;
  prometheus::Gauge* image_consecutive_errors_;
};

}  // namespace scanner