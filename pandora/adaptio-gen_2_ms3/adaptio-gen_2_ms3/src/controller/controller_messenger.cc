#include "controller_messenger.h"

#include <fmt/core.h>

#include <boost/outcome/result.hpp>
#include <chrono>
#include <cstdint>
#include <memory>
#include <string>
#include <thread>
#include <utility>

#include "common/clock_functions.h"
#include "common/logging/application_log.h"
#include "common/zevs/zevs_core.h"
#include "common/zevs/zevs_socket.h"
#include "controller/axis_output_plc_adapter.h"
#include "controller/controller.h"
#include "controller/controller_data.h"
#include "controller/hwhmi_server_impl.h"
#include "controller/plc_oam_server_impl.h"
#include "controller/slide_position_buffer.h"
#include "controller/weld_axis_buffer.h"
#include "controller/weld_axis_filter.h"
#include "controller/weld_system_server_impl.h"
#include "kinematics_server_impl.h"

using controller::ControllerMessenger;

namespace {
class KinematicsObserverWrapper : public controller::KinematicsServerObserver {
 public:
  KinematicsObserverWrapper(controller::ControllerMessenger* messenger, controller::AxisOutputPlcAdapter* adapter)
      : messenger_(messenger), adapter_(adapter) {}
  void OnWeldAxisOutput(controller::WeldAxis_AdaptioToPlc data) override {
    messenger_->OnKinematicWeldAxisOutputUpdate(data);
  }
  void OnWeldHeadManipulatorOutput(controller::WeldHeadManipulator_AdaptioToPlc data) override {
    messenger_->OnKinematicWeldHeadManipulatorOutputUpdate(data);
  }
  void Release() override { adapter_->Release(); }

 private:
  controller::ControllerMessenger* messenger_;
  controller::AxisOutputPlcAdapter* adapter_;
};
}  // namespace

ControllerMessenger::ControllerMessenger(ControllerPtr controller, uint32_t cycle_time,
                                         clock_functions::SystemClockNowFunc system_clock_now_func,
                                         clock_functions::SteadyClockNowFunc steady_clock_now_func,
                                         std::string endpoint_base_url)
    : steady_clock_now_func_(std::move(steady_clock_now_func)),
      controller_(std::move(controller)),
      cycle_time_(cycle_time),
      system_clock_now_func_(std::move(system_clock_now_func)) {
  kinematics_endpoint_url_  = fmt::format("inproc://{}/kinematics", endpoint_base_url);
  weld_system_endpoint_url_ = fmt::format("inproc://{}/weld-system", endpoint_base_url);
  hwhmi_endpoint_url_       = fmt::format("inproc://{}/hwhmi", endpoint_base_url);
  plc_oam_endpoint_url_     = fmt::format("inproc://{}/plc-oam", endpoint_base_url);

  axis_output_plc_adapter_ = std::make_unique<AxisOutputPlcAdapter>(
      [this](WeldHeadManipulator_AdaptioToPlc data) { this->OnKinematicWeldHeadManipulatorOutputUpdate(data); });

  kinematics_observer_wrapper_ = std::make_unique<KinematicsObserverWrapper>(this, axis_output_plc_adapter_.get());

  controller_->SetCallbackInterface(this);
}

ControllerMessenger::~ControllerMessenger() {
  LOG_DEBUG("Destroying Controller Messenger");
  controller_->Disconnect();
}

void ControllerMessenger::StartThread(const std::string& event_loop_name) {
  thread_ = std::thread(&ControllerMessenger::ThreadEntry, this, event_loop_name);
}

void ControllerMessenger::JoinThread() { thread_.join(); }

auto ControllerMessenger::DetermineButtonState(bool start_request, bool stop_request, bool quick_stop_request)
    -> ButtonState {
  // Priority: stop over start
  if (stop_request || quick_stop_request) {
    return ButtonState::STOP;
  }
  if (start_request) {
    return ButtonState::START;
  }
  return ButtonState::NONE;
}

void ControllerMessenger::OnSystemControlInputUpdate(SystemControl_PlcToAdaptio data) {
  previous_heartbeat_ = heartbeat_;
  heartbeat_          = data.get_heartbeat();

  auto const current_button_state = DetermineButtonState(
      data.get_commands_start_request(), data.get_commands_stop_request(), data.get_commands_quick_stop_request());

  if (current_button_state != previous_button_state_) {
    previous_button_state_ = current_button_state;
    hwhmi_server_->OnButtonStateChange(current_button_state);
  }

  if (data.get_commands_shutdown_request()) {
    plc_oam_server_->OnShutdownRequestInput();
  }

  // Heartbeat loopback
  SystemControl_AdaptioToPlc output;
  output.set_heartbeat(heartbeat_);
  controller_->SetSystemControl(output);
}

void ControllerMessenger::OnSystemVersionsInputUpdate(SystemVersions_PlcToAdaptio data) {
  plc_oam_server_->OnSystemVersionsInput(data.get_aws_major(), data.get_aws_minor(), data.get_aws_patch());
}

void ControllerMessenger::OnJoystickInputUpdate(Joystick_PlcToAdaptio data) {
  auto const current_joystick_state = ConvertJoystickState(data.get_state());

  if (current_joystick_state != previous_joystick_state_) {
    previous_joystick_state_ = current_joystick_state;
    hwhmi_server_->OnJoystickStateChange(current_joystick_state);
  }
}

auto ControllerMessenger::ConvertJoystickState(uint32_t state) -> JoystickState {
  switch (state) {
    case 0:
      return JoystickState::IDLE;
    case 1:
      return JoystickState::CLICKED_UP;
    case 2:
      return JoystickState::CLICKED_DOWN;
    case 3:
      return JoystickState::CLICKED_SQUARE;
    case 4:
      return JoystickState::CLICKED_TRIANGLE;
    case 5:
      return JoystickState::HELD_UP;
    case 6:
      return JoystickState::HELD_DOWN;
    case 7:
      return JoystickState::HELD_SQUARE;
    case 8:
      return JoystickState::HELD_TRIANGLE;
    default:
      return JoystickState::INVALID;
  }
}

void ControllerMessenger::OnFluxSystemInputUpdate(FluxSystem_PlcToAdaptio data) {}

void ControllerMessenger::OnWeldControlInputUpdate(WeldControl_PlcToAdaptio data) {}

void ControllerMessenger::OnWeldAxisInputUpdate(WeldAxis_PlcToAdaptio data) {
  float filtered_velocity             = weld_axis_median_filter_->ProcessSignal(data.get_velocity());
  WeldAxis_PlcToAdaptio filtered_data = data;
  filtered_data.set_velocity(filtered_velocity);

  if (weld_axis_input_data_cache_ != filtered_data) {
    kinematics_server_->OnWeldAxisInput(filtered_data);
    weld_axis_input_data_cache_ = filtered_data;
  }
}

void ControllerMessenger::OnWeldHeadManipulatorInputUpdate(WeldHeadManipulator_PlcToAdaptio data) {
  if (weld_head_manipulator_input_data_cache_ != data) {
    kinematics_server_->OnWeldHeadManipulatorInput(data);
    weld_head_manipulator_input_data_cache_ = data;
  }
}

void ControllerMessenger::OnPowerSource1InputUpdate(WeldSystem_PlcToAdaptio data) {
  weld_system_server_->OnPowerSourceInput(1, data);
}

void ControllerMessenger::OnPowerSource2InputUpdate(WeldSystem_PlcToAdaptio data) {
  weld_system_server_->OnPowerSourceInput(2, data);
}

void ControllerMessenger::OnHeartbeatLost() { plc_oam_server_->OnHeartbeatLostInput(); }

void ControllerMessenger::OnDisconnected(uint32_t reason_code) {}

auto ControllerMessenger::ValidateHeartbeat() -> bool { return heartbeat_ != previous_heartbeat_; }

void ControllerMessenger::CheckAdaptioHeartbeat() {
  using namespace std::chrono_literals;

  if (ValidateHeartbeat()) {
    heartbeat_last_changed_ = steady_clock_now_func_();
  } else {
    if (steady_clock_now_func_() - heartbeat_last_changed_ > 500ms) {
      LOG_ERROR("Detected the PLC heartbeat lost");
      heartbeat_last_changed_ = steady_clock_now_func_();
      OnHeartbeatLost();
    }
  }
}

void ControllerMessenger::OnPowerSourceOutput(uint32_t index, WeldSystem_AdaptioToPlc const& data) {
  if (index == 1) {
    controller_->SetPowerSource1(data);
  } else if (index == 2) {
    controller_->SetPowerSource2(data);
  } else {
    LOG_ERROR("Invalid power-souce index: {} - ignored", index);
  }
}

void ControllerMessenger::OnWeldControlOutput(WeldControl_AdaptioToPlc const& data) {
  controller_->SetWeldControl(data);
}

void ControllerMessenger::ThreadEntry(const std::string& name) {
  LOG_DEBUG("Starting Controller Messenger");
  event_loop_ = zevs::GetCoreFactory()->CreateEventLoop(name);

  horizontal_position_buffer_ = std::make_unique<SlidePositionBufferImpl>();
  vertical_position_buffer_   = std::make_unique<SlidePositionBufferImpl>();
  weld_axis_buffer_           = std::make_unique<WeldAxisBufferImpl>();
  weld_axis_median_filter_    = std::make_unique<WeldAxisFilterMedianImpl>(filter_median_window_size_);
  weld_axis_median_filter_->ClearSignalBuffer();

  kinematics_socket_ = zevs::GetFactory()->CreatePairSocket(*event_loop_);
  kinematics_socket_->Bind(kinematics_endpoint_url_);
  auto target_path_position_update = [this](double target_path_position) {
    target_path_position_ = target_path_position;
  };

  kinematics_server_ = std::make_unique<KinematicsServerImpl>(
      kinematics_socket_.get(), kinematics_observer_wrapper_.get(), horizontal_position_buffer_.get(),
      vertical_position_buffer_.get(), weld_axis_buffer_.get(), system_clock_now_func_, target_path_position_update);

  weld_system_socket_ = zevs::GetFactory()->CreatePairSocket(*event_loop_);
  weld_system_socket_->Bind(weld_system_endpoint_url_);
  weld_system_server_ = std::make_unique<WeldSystemServerImpl>(weld_system_socket_.get(), this);

  hwhmi_socket_ = zevs::GetFactory()->CreatePairSocket(*event_loop_);
  hwhmi_socket_->Bind(hwhmi_endpoint_url_);
  hwhmi_server_ = std::make_unique<HwHmiServerImpl>(hwhmi_socket_.get(), this);

  plc_oam_socket_ = zevs::GetFactory()->CreatePairSocket(*event_loop_);
  plc_oam_socket_->Bind(plc_oam_endpoint_url_);
  plc_oam_server_ = std::make_unique<PlcOamServerImpl>(plc_oam_socket_.get());

  auto result = Connect();
  if (result.has_error()) {
    LOG_ERROR("Failed connect: {}", result.error().to_string());
  }

  StartTimer();
  event_loop_->Run();
}

void ControllerMessenger::SuperviseHeartbeat() {
  supervise_heartbeat_    = true;
  heartbeat_last_changed_ = steady_clock_now_func_();
}

auto ControllerMessenger::Connect() -> boost::outcome_v2::result<bool> {
  const std::uint32_t max_number_of_attempts    = 10;
  const std::uint32_t sleep_before_next_attempt = 10;  // sec
  for (std::uint32_t attempt = 1; attempt < max_number_of_attempts + 1; attempt++) {
    auto result = controller_->Connect();
    if (!result.has_error()) {
      return result;
    }
    LOG_ERROR("Connection attempt {} failed: {}", attempt, result.error().to_string());
    std::this_thread::sleep_for(std::chrono::seconds(sleep_before_next_attempt));
  }

  return ControllerErrorCode::MAX_NUMBER_OF_ATTEMPTS;
}

void ControllerMessenger::StartTimer() {
  uint32_t duration_ms = cycle_time_;
  timer_               = zevs::GetFactory()->CreateTimer(*event_loop_);
  timer_->RequestPeriodic(&ControllerMessenger::OnTimeout, this, duration_ms, "controller_periodic_update");
}

void ControllerMessenger::OnTimeout() {
  if (controller_->IsConnected()) {
    axis_output_plc_adapter_->OnPlcCycleWrite();

    auto retrieve_result = controller_->RetrieveInputs();
    if (supervise_heartbeat_ && retrieve_result.has_value()) {
      CheckAdaptioHeartbeat();
    }

    if (auto result = controller_->WriteOutputs(); result.has_error()) {
      LOG_ERROR("Failed to write outputs: {}", result.error().to_string());
    }
  }
}

void ControllerMessenger::OnKinematicWeldAxisOutputUpdate(const WeldAxis_AdaptioToPlc& data) {
  controller_->SetWeldAxis(data);
}

void ControllerMessenger::OnKinematicWeldHeadManipulatorOutputUpdate(const WeldHeadManipulator_AdaptioToPlc& data) {
  controller_->SetWeldHeadManipulator(data);
}

void ControllerMessenger::OnJoystickControlModeOutput(JoystickControlMode control_mode) {
  uint32_t plc_value = 0;
  switch (control_mode) {
    case JoystickControlMode::INVALID:
      LOG_ERROR("Invalid joystick control mode received");
      plc_value = 0;
      break;
    case JoystickControlMode::NO_CONTROL:
      plc_value = 0;
      break;
    case JoystickControlMode::SLIDE_CROSS:
      plc_value = 1;
      break;
    case JoystickControlMode::ROLLERBED:
      plc_value = 2;
      break;
    case JoystickControlMode::COLUMN_AND_BOOM:
      plc_value = 3;
      break;
    default:
      LOG_ERROR("Unknown joystick control mode: {}", static_cast<uint32_t>(control_mode));
      plc_value = 0;
      break;
  }
  Joystick_AdaptioToPlc output;
  output.set_control_mode(plc_value);
  controller_->SetJoystick(output);
}
