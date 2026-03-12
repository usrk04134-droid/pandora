#include "simulation.h"

#include <boost/outcome/result.hpp>
#include <cmath>
#include <cstdint>
#include <numbers>

#include "common/logging/application_log.h"
#include "controller/controller.h"
#include "controller/controller_data.h"

using controller::simulation::Simulation;

namespace {
enum class SimAxisId : uint32_t {
  INVALID,
  SLIDE_CROSS_HORIZONTAL,
  SLIDE_CROSS_VERTICAL,
  WELD_AXIS,
  SIZE,
};

unsigned edge_update_count = 0;

}  // namespace

Simulation::Simulation(clock_functions::SteadyClockNowFunc steady_clock_now_func)
    : is_connected_(false), shutdown_(false), steady_clock_now_func_(std::move(steady_clock_now_func)) {}

auto Simulation::Connect() -> boost::outcome_v2::result<bool> {
  is_connected_ = true;
  return true;
}

void Simulation::Disconnect() { is_connected_ = false; }

auto Simulation::IsConnected() -> bool { return is_connected_; }

auto Simulation::RetrieveInputs() -> boost::outcome_v2::result<bool> {
  if (wds_selected_time_.has_value() && !start_fired_) {
    auto const elapsed = steady_clock_now_func_() - wds_selected_time_.value();
    if (elapsed >= AUTO_START_DELAY) {
      LOG_INFO("Simulation: firing weld start button after {}s delay",
               std::chrono::duration_cast<std::chrono::seconds>(elapsed).count());
      system_control_start_request_ = true;
      start_request_time_           = steady_clock_now_func_();
      start_fired_                  = true;
    }
  }

  if (start_request_time_.has_value() &&
      steady_clock_now_func_() - start_request_time_.value() >= std::chrono::milliseconds(500)) {
    system_control_start_request_ = false;
    start_request_time_.reset();
  }

  ps1_.Update();
  ps2_.Update();
  kinematics_.Update();
  ++edge_update_count;

  SetInputs();

  return true;
}

void Simulation::WriteWeldHeadManipulatorOutput(controller::WeldHeadManipulator_AdaptioToPlc data) {
  if (data.get_commands_enable_motion()) {
    kinematics_.commands.x.execute = true;
    kinematics_.commands.y.execute = true;
    kinematics_.commands.x.stop    = false;
    kinematics_.commands.y.stop    = false;
  } else {
    kinematics_.commands.x.execute = false;
    kinematics_.commands.y.execute = false;
  }

  kinematics_.commands.x.position = data.get_x_position();
  kinematics_.commands.y.position = data.get_y_position();

  kinematics_.commands.x.speed = data.get_x_speed();
  kinematics_.commands.y.speed = data.get_y_speed();
}

void Simulation::WriteWeldAxisOutput(controller::WeldAxis_AdaptioToPlc data) {
  kinematics_.commands.a.execute         = data.get_commands_enable_motion();
  kinematics_.commands.a.stop            = false;  // Not directly mapped
  kinematics_.commands.a.follow_position = false;  // Not directly mapped
  kinematics_.commands.a.position        = data.get_position();
  kinematics_.commands.a.speed           = data.get_velocity();
}

void Simulation::WritePowerSource1Output(controller::WeldSystem_AdaptioToPlc data) {
  ps1_.commands.voltage      = static_cast<double>(data.get_voltage());
  ps1_.commands.current      = static_cast<double>(data.get_current());
  ps1_.status.ready_to_start = true;
  if (!wds_selected_time_.has_value()) {
    wds_selected_time_ = steady_clock_now_func_();
    LOG_INFO("Simulation: WDS selected, auto-start in {}s", AUTO_START_DELAY.count());
  }
}

void Simulation::WritePowerSource2Output(controller::WeldSystem_AdaptioToPlc data) {
  ps2_.commands.voltage      = static_cast<double>(data.get_voltage());
  ps2_.commands.current      = static_cast<double>(data.get_current());
  ps2_.status.ready_to_start = true;
}

void Simulation::WriteWeldControlOutput(controller::WeldControl_AdaptioToPlc data) {
  if (data.get_commands_start()) {
    LOG_INFO("Simulation: weld start command received, power sources going to ARCING");
    ps1_.commands.weld_start = true;
    ps2_.commands.weld_start = true;
  }
}

void Simulation::SetInputs() {
  // Power source 1
  WeldSystem_PlcToAdaptio power_source_1;

  uint32_t state_1 = 5;  // Default to INIT (not yet configured)
  if (ps1_.status.error || ps1_.status.start_failure) {
    state_1 = 1;  // Error
  } else if (ps1_.status.arcing) {
    state_1 = 3;  // Arcing
  } else if (ps1_.status.ready_to_start) {
    state_1 = 0;  // Ready to start
  }
  power_source_1.set_state(state_1);
  power_source_1.set_status_enabled(ps1_.status.ready_to_start);

  power_source_1.set_measured_voltage(static_cast<float>(ps1_.status.voltage));
  power_source_1.set_measured_current(static_cast<uint32_t>(ps1_.status.current));
  power_source_1.set_measured_wire_speed(static_cast<uint32_t>(ps1_.commands.wire_speed));

  power_source_1.set_calculated_deposition_rate(static_cast<float>(ps1_.status.deposition_rate));
  power_source_1.set_calculated_heat_input(static_cast<float>(ps1_.status.heat_input));

  HandlePowerSource1Input(power_source_1);

  // Power source 2
  WeldSystem_PlcToAdaptio power_source_2;

  uint32_t state_2 = 5;  // Default to INIT (not yet configured)
  if (ps2_.status.error || ps2_.status.start_failure) {
    state_2 = 1;  // Error
  } else if (ps2_.status.arcing) {
    state_2 = 3;  // Arcing
  } else if (ps2_.status.ready_to_start) {
    state_2 = 0;  // Ready to start
  }
  power_source_2.set_state(state_2);
  power_source_2.set_status_enabled(ps2_.status.ready_to_start);

  power_source_2.set_measured_voltage(static_cast<float>(ps2_.status.voltage));
  power_source_2.set_measured_current(static_cast<uint32_t>(ps2_.status.current));
  power_source_2.set_measured_wire_speed(static_cast<uint32_t>(ps2_.commands.wire_speed));

  power_source_2.set_calculated_deposition_rate(static_cast<float>(ps2_.status.deposition_rate));
  power_source_2.set_calculated_heat_input(static_cast<float>(ps2_.status.heat_input));

  HandlePowerSource2Input(power_source_2);

  WeldHeadManipulator_PlcToAdaptio weld_head_manipulator;

  bool combined_in_position = kinematics_.status.x.in_position && kinematics_.status.y.in_position;
  weld_head_manipulator.set_status_in_position(combined_in_position);

  weld_head_manipulator.set_state(0);

  weld_head_manipulator.set_x_position(kinematics_.status.x.position);
  weld_head_manipulator.set_y_position(kinematics_.status.y.position);

  weld_head_manipulator.set_x_velocity(kinematics_.status.x.velocity);
  weld_head_manipulator.set_y_velocity(kinematics_.status.y.velocity);

  weld_head_manipulator.set_interpolated_velocity(0.0F);

  HandleWeldHeadManipulatorInput(weld_head_manipulator);

  // Weld axis
  WeldAxis_PlcToAdaptio weld_axis;

  weld_axis.set_status_in_position(kinematics_.status.a.in_position);
  weld_axis.set_status_reference_valid(true);

  weld_axis.set_state(0);

  weld_axis.set_error_code(0);

  weld_axis.set_axis_type(0);

  weld_axis.set_radius(1000.0F);

  weld_axis.set_position(kinematics_.status.a.position);
  weld_axis.set_velocity(kinematics_.status.a.velocity);

  weld_axis.set_linear_object_distance(0.0F);

  HandleWeldAxisInput(weld_axis);

  SystemControl_PlcToAdaptio system_control;
  system_control.set_heartbeat(++heartbeat_counter_);
  system_control.set_commands_start_request(system_control_start_request_);
  HandleSystemControlInput(system_control);
}
