#pragma once

#include "scanner/joint_model/joint_model.h"

namespace scanner {

class ScannerMetrics {
 public:
  virtual ~ScannerMetrics() = default;

  virtual void IncImageProcessed(int num_walls_found)                          = 0;
  virtual void IncImageProcessingError(joint_model::JointModelErrorCode error) = 0;
  virtual void ObserveImageProcessingDuration(double seconds)                  = 0;
  virtual void SetConsecutiveErrors(double value)                              = 0;
  virtual void IncConsecutiveErrors(double value)                              = 0;
  virtual auto GetConsecutiveErrors() -> double                                = 0;
};

}  // namespace scanner