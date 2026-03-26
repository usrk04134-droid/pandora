#pragma once

#include <cstdint>
#include <limits>
#include <memory>
#include <string>
#include <thread>

#include "axis_output_plc_adapter.h"
#include "common/clock_functions.h"
#include "common/zevs/zevs_core.h"
#include "common/zevs/zevs_socket.h"
#include "controller/controller.h"
#include "controller/controller_data.h"
#include "controller/hwhmi_server.h"
#include "controller/hwhmi_server_impl.h"
#include "controller/plc_oam_server_impl.h"
#include "controller/weld_system_server_impl.h"
#include "kinematics_server.h"
#include "slide_position_buffer.h"
#include "weld_axis_buffer.h"
#include "weld_axis_filter.h"

namespace controller {

enum class AxisId : uint32_t {
  INVALID,
  SLIDE_CROSS_HORIZONTAL,
  SLIDE_CROSS_VERTICAL,
  WELD_AXIS,
  SIZE,
};

namespace input {

struct ExternalControllerInput {
  enum class Metadata : uint32_t { MESSAGE_ID = 0x03000010 };
  bool set_external_command_mode;
};

}  // namespace input

class ControllerMessenger : public ControllerDataCallbacks,
                            public WeldSystemServerObserver,
                            public HwHmiServerObserver {
 public:
  explicit ControllerMessenger(ControllerPtr controller, uint32_t cycle_time,
                               clock_functions::SystemClockNowFunc system_clock_now_func,
                               clock_functions::SteadyClockNowFunc steady_clock_now_func,
                               std::string endpoint_base_url = "controller_messages");

  ControllerMessenger(ControllerMessenger&)                     = delete;
  auto operator=(ControllerMessenger&) -> ControllerMessenger&  = delete;
  ControllerMessenger(ControllerMessenger&&)                    = delete;
  auto operator=(ControllerMessenger&&) -> ControllerMessenger& = delete;

  ~ControllerMessenger() override;

  void OnSystemControlInputUpdate(SystemControl_PlcToAdaptio data) override;
  void OnSystemVersionsInputUpdate(SystemVersions_PlcToAdaptio data) override;
  void OnJoystickInputUpdate(Joystick_PlcToAdaptio data) override;
  void OnFluxSystemInputUpdate(FluxSystem_PlcToAdaptio data) override;
  void OnWeldControlInputUpdate(WeldControl_PlcToAdaptio data) override;
  void OnWeldAxisInputUpdate(WeldAxis_PlcToAdaptio data) override;
  void OnWeldHeadManipulatorInputUpdate(WeldHeadManipulator_PlcToAdaptio data) override;
  void OnPowerSource1InputUpdate(WeldSystem_PlcToAdaptio data) override;
  void OnPowerSource2InputUpdate(WeldSystem_PlcToAdaptio data) override;
  void OnHeartbeatLost() override;
  void OnDisconnected(uint32_t reason_code) override;
  auto ValidateHeartbeat() -> bool override;

  void SuperviseHeartbeat();
  void ThreadEntry(const std::string& name);
  void StartThread(const std::string& event_loop_name);
  void JoinThread();

  void OnPowerSourceOutput(uint32_t index, WeldSystem_AdaptioToPlc const& data) override;
  void OnWeldControlOutput(WeldControl_AdaptioToPlc const& data) override;
  void OnJoystickControlModeOutput(JoystickControlMode control_mode) override;

 protected:
  void CheckAdaptioHeartbeat();

  std::chrono::time_point<std::chrono::steady_clock> heartbeat_last_changed_ = {};
  clock_functions::SteadyClockNowFunc steady_clock_now_func_;

 private:
  ControllerPtr controller_;
  uint32_t cycle_time_               = 100;
  uint8_t filter_median_window_size_ = 5;
  std::thread thread_;
  zevs::EventLoopPtr event_loop_;
  std::string kinematics_endpoint_url_;
  std::string weld_system_endpoint_url_;
  std::string hwhmi_endpoint_url_;
  std::string plc_oam_endpoint_url_;
  zevs::SocketPtr kinematics_socket_;
  zevs::SocketPtr weld_system_socket_;
  zevs::SocketPtr hwhmi_socket_;
  zevs::SocketPtr plc_oam_socket_;
  zevs::TimerPtr timer_;
  std::unique_ptr<KinematicsServer> kinematics_server_;
  std::unique_ptr<SlidePositionBuffer> horizontal_position_buffer_;
  std::unique_ptr<SlidePositionBuffer> vertical_position_buffer_;
  std::unique_ptr<WeldAxisBuffer> weld_axis_buffer_;
  std::unique_ptr<WeldSystemServerImpl> weld_system_server_;
  std::unique_ptr<HwHmiServerImpl> hwhmi_server_;
  std::unique_ptr<PlcOamServerImpl> plc_oam_server_;
  std::unique_ptr<WeldAxisFilter> weld_axis_median_filter_;
  clock_functions::SystemClockNowFunc system_clock_now_func_;
  double target_path_position_{0.0};

  bool supervise_heartbeat_ = false;

  auto Connect() -> boost::outcome_v2::result<bool>;
  void StartTimer();
  void OnTimeout();

  friend class KinematicsObserverWrapper;

 public:
  void OnKinematicWeldAxisOutputUpdate(const WeldAxis_AdaptioToPlc& data);
  void OnKinematicWeldHeadManipulatorOutputUpdate(const WeldHeadManipulator_AdaptioToPlc& data);

 private:
  std::unique_ptr<AxisOutputPlcAdapter> axis_output_plc_adapter_;
  std::unique_ptr<KinematicsServerObserver> kinematics_observer_wrapper_;
  uint32_t heartbeat_{};  // should be different from previous_heartbeat_
  uint32_t previous_heartbeat_{std::numeric_limits<uint32_t>::max()};
  WeldHeadManipulator_PlcToAdaptio weld_head_manipulator_input_data_cache_;
  WeldAxis_PlcToAdaptio weld_axis_input_data_cache_;
  ButtonState previous_button_state_{ButtonState::INVALID};
  JoystickState previous_joystick_state_{JoystickState::INVALID};

  static auto DetermineButtonState(bool start_request, bool stop_request, bool quick_stop_request) -> ButtonState;
  static auto ConvertJoystickState(uint32_t state) -> JoystickState;
};

using ControllerMessengerPtr = std::unique_ptr<ControllerMessenger>;

}  // namespace controller
