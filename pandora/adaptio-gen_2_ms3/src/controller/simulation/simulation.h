#pragma once

#include <atomic>
#include <chrono>
#include <memory>
#include <optional>
#include <thread>

#include "common/clock_functions.h"
#include "controller/controller.h"
#include "controller/simulation/kinematics.h"
#include "controller/simulation/power_source.h"

namespace controller::simulation {

static constexpr auto AUTO_START_DELAY = std::chrono::seconds{30};

class Simulation final : public controller::Controller {
 public:
  explicit Simulation(clock_functions::SteadyClockNowFunc steady_clock_now_func);

  Simulation(Simulation&)                     = delete;
  auto operator=(Simulation&) -> Simulation&  = delete;
  Simulation(Simulation&&)                    = delete;
  auto operator=(Simulation&&) -> Simulation& = delete;

  ~Simulation() = default;
  auto Connect() -> boost::outcome_v2::result<bool> override;
  void Disconnect() override;
  auto IsConnected() -> bool override;

  void WriteWeldAxisOutput(controller::WeldAxis_AdaptioToPlc data) override;
  void WriteWeldHeadManipulatorOutput(controller::WeldHeadManipulator_AdaptioToPlc data) override;
  void WritePowerSource1Output(controller::WeldSystem_AdaptioToPlc data) override;
  void WritePowerSource2Output(controller::WeldSystem_AdaptioToPlc data) override;
  void WriteWeldControlOutput(controller::WeldControl_AdaptioToPlc data) override;

 private:
  bool is_connected_;
  std::atomic<bool> shutdown_;
  PowerSource ps1_{};
  PowerSource ps2_{};
  Kinematics kinematics_{};
  bool commands_set_external_command_mode_{false};

  clock_functions::SteadyClockNowFunc steady_clock_now_func_;
  std::optional<std::chrono::steady_clock::time_point> wds_selected_time_{};
  bool start_fired_{false};
  bool system_control_start_request_{false};
  std::optional<std::chrono::steady_clock::time_point> start_request_time_{};
  uint32_t heartbeat_counter_{0};

  std::unique_ptr<std::thread> worker_thread_{};

  void Run();
  auto RetrieveInputs() -> boost::outcome_v2::result<bool> override;

  void SetInputs();
};

}  // namespace controller::simulation
