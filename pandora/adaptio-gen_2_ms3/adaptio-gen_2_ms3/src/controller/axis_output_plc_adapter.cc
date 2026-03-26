#include "axis_output_plc_adapter.h"

#include <functional>
#include <optional>

#include "common/logging/application_log.h"
#include "controller/controller_data.h"

using controller::AxisOutputPlcAdapter;

AxisOutputPlcAdapter::AxisOutputPlcAdapter(
    const std::function<void(WeldHeadManipulator_AdaptioToPlc)>& weld_head_writer)
    : weld_head_writer_(weld_head_writer) {}

void AxisOutputPlcAdapter::OnWeldAxisOutput(WeldAxis_AdaptioToPlc data) {}

void AxisOutputPlcAdapter::Release() { release_ = true; }

void AxisOutputPlcAdapter::OnWeldHeadManipulatorOutput(WeldHeadManipulator_AdaptioToPlc data) {
  weld_head_manipulator_output_to_write_ = data;
}

void AxisOutputPlcAdapter::OnPlcCycleWrite() {
  if (release_) {
    if (weld_head_manipulator_last_written_) {
      auto weld_head_release = weld_head_manipulator_last_written_.value();
      weld_head_release.set_commands_enable_motion(false);
      weld_head_writer_(weld_head_release);
    }

    release_ = false;
    return;
  }

  if (weld_head_manipulator_output_to_write_) {
    weld_head_writer_(*weld_head_manipulator_output_to_write_);
    weld_head_manipulator_last_written_    = *weld_head_manipulator_output_to_write_;  // save for use in release()
    weld_head_manipulator_output_to_write_ = {};
  }
}
