#pragma once
#include <functional>
#include <optional>

#include "kinematics_server.h"

namespace controller {

class AxisOutputPlcAdapter : public KinematicsServerObserver {
 public:
  explicit AxisOutputPlcAdapter(const std::function<void(WeldHeadManipulator_AdaptioToPlc)>& weld_head_writer);

  void OnPlcCycleWrite();

  // KinematicsServerObserver
  void OnWeldAxisOutput(WeldAxis_AdaptioToPlc data) override;
  void OnWeldHeadManipulatorOutput(WeldHeadManipulator_AdaptioToPlc data) override;
  void Release() override;

 private:
  std::optional<WeldHeadManipulator_AdaptioToPlc> weld_head_manipulator_output_to_write_;
  std::optional<WeldHeadManipulator_AdaptioToPlc> weld_head_manipulator_last_written_;
  bool release_ = false;
  std::function<void(WeldHeadManipulator_AdaptioToPlc)> weld_head_writer_;
};

}  // namespace controller
