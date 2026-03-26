#include "weld_system_server_impl.h"

#include <cstdint>

#include "common/logging/application_log.h"
#include "common/messages/weld_system.h"
#include "common/zevs/zevs_socket.h"
#include "controller/controller_data.h"
#include "controller/weld_system_server.h"

namespace {
constexpr float WIRE_DIAMETER_MM = 4.0F;
constexpr bool TWIN_WIRE         = false;

auto ConvertEnum(common::msg::weld_system::SetWeldSystemSettings::Method data) -> uint32_t {
  switch (data) {
    case common::msg::weld_system::SetWeldSystemSettings::Method::DC:
    case common::msg::weld_system::SetWeldSystemSettings::Method::DC_NEG:
    case common::msg::weld_system::SetWeldSystemSettings::Method::AC:
      return static_cast<uint32_t>(data);
    default:
      LOG_ERROR("Invalid Method: {}", static_cast<uint32_t>(data));
  }
  return -1;
}

auto ConvertEnum(common::msg::weld_system::SetWeldSystemSettings::RegulationType data) -> uint32_t {
  switch (data) {
    case common::msg::weld_system::SetWeldSystemSettings::RegulationType::CW:
    case common::msg::weld_system::SetWeldSystemSettings::RegulationType::CA:
    case common::msg::weld_system::SetWeldSystemSettings::RegulationType::CC:
      return static_cast<uint32_t>(data);
    default:
      LOG_ERROR("Invalid RegulationType: {}", static_cast<uint32_t>(data));
  }
  return -1;
}

}  // namespace

namespace controller {

auto WeldControlCommandToString(WeldControl_AdaptioToPlc const& cmd) -> std::string {
  // Only one of the fields are set at a time.
  if (cmd.get_commands_start()) {
    return "start";
  }
  if (cmd.get_commands_stop()) {
    return "stop";
  }
  if (cmd.get_commands_quick_stop()) {
    return "quick_stop";
  }
  return "idle";
}

WeldSystemServerImpl::WeldSystemServerImpl(zevs::Socket* socket, WeldSystemServerObserver* observer)
    : socket_(socket),
      observer_(observer),
      weld_systems_({
          {1, {}},
          {2, {}}
}) {
  socket_->Serve(&WeldSystemServerImpl::OnGetWeldSystemData, this);
  socket_->Serve(&WeldSystemServerImpl::OnSetWeldSystemSettings, this);
  socket_->Serve(&WeldSystemServerImpl::OnWeldControlCommand, this);
  socket_->Serve(&WeldSystemServerImpl::SubscribeWeldSystemStateChanges, this);
  socket_->Serve(&WeldSystemServerImpl::UnSubscribeWeldSystemStateChanges, this);
}

void WeldSystemServerImpl::OnGetWeldSystemData(common::msg::weld_system::GetWeldSystemData data) {
  common::msg::weld_system::GetWeldSystemDataRsp rsp{};

  auto iter = weld_systems_.find(data.index);
  if (iter != weld_systems_.end()) {
    auto const& weld_system_status = iter->second;

    rsp = common::msg::weld_system::GetWeldSystemDataRsp{
        .transaction_id    = data.transaction_id,
        .voltage           = weld_system_status.get_measured_voltage(),
        .current           = static_cast<float>(weld_system_status.get_measured_current()),
        .wire_lin_velocity = static_cast<float>(weld_system_status.get_measured_wire_speed() * 10. / 60.),
        .deposition_rate   = weld_system_status.get_calculated_deposition_rate(),
        .heat_input        = weld_system_status.get_calculated_heat_input(),
        .twin_wire         = TWIN_WIRE,
        .wire_diameter     = WIRE_DIAMETER_MM,
    };
  }

  socket_->Send(rsp);
}

void WeldSystemServerImpl::OnSetWeldSystemSettings(common::msg::weld_system::SetWeldSystemSettings data) {
  auto output = WeldSystem_AdaptioToPlc{};

  output.set_weld_method(ConvertEnum(data.method));
  output.set_regulation_type(ConvertEnum(data.regulation_type));
  output.set_start_adjust(data.start_adjust);
  output.set_voltage(data.voltage);
  output.set_current(static_cast<uint32_t>(data.current));
  output.set_wire_speed(static_cast<uint32_t>(data.wire_speed));
  output.set_ice_wire_speed(static_cast<uint32_t>(data.ice_wire_speed));
  output.set_ac_frequency(static_cast<uint32_t>(data.ac_frequency));
  output.set_ac_offset(data.ac_offset);
  output.set_ac_phase_shift(static_cast<uint32_t>(data.ac_phase_shift));

  observer_->OnPowerSourceOutput(data.index, output);
}

void WeldSystemServerImpl::OnWeldControlCommand(common::msg::weld_system::WeldControlCommand data) {
  WeldControl_AdaptioToPlc output{};
  switch (data.command) {
    case common::msg::weld_system::WeldControlCommand::Command::START:
      output.set_commands_start(true);
      break;
    case common::msg::weld_system::WeldControlCommand::Command::STOP:
      output.set_commands_stop(true);
      break;
    case common::msg::weld_system::WeldControlCommand::Command::QUICK_STOP:
      output.set_commands_quick_stop(true);
      break;
    case common::msg::weld_system::WeldControlCommand::Command::IDLE:
    case common::msg::weld_system::WeldControlCommand::Command::INVALID:
    default:
      break;
  }

  if (output != weld_control_command_cache_) {
    LOG_INFO("Weld control command transition: {} -> {}", WeldControlCommandToString(weld_control_command_cache_),
             WeldControlCommandToString(output));
  }

  weld_control_command_cache_ = output;
  observer_->OnWeldControlOutput(output);
}

void WeldSystemServerImpl::SendStateChange(uint32_t index, const WeldSystem_PlcToAdaptio& data) {
  if (!state_change_subscriber_) {
    return;
  }

  common::msg::weld_system::OnWeldSystemStateChange rsp{
      .index = index,
      .state = common::msg::weld_system::OnWeldSystemStateChange::State::INIT,
  };

  switch (data.get_state()) {
    case 0:  // Ready
      rsp.state = common::msg::weld_system::OnWeldSystemStateChange::State::READY_TO_START;
      break;
    case 1:  // Error
      rsp.state = common::msg::weld_system::OnWeldSystemStateChange::State::ERROR;
      break;
    case 2:  // Start phase
      rsp.state = common::msg::weld_system::OnWeldSystemStateChange::State::IN_WELDING_SEQUENCE;
      break;
    case 3:  // Welding
      rsp.state = common::msg::weld_system::OnWeldSystemStateChange::State::ARCING;
      break;
    case 4:  // Stop phase
      rsp.state = common::msg::weld_system::OnWeldSystemStateChange::State::IN_WELDING_SEQUENCE;
      break;
    default:
      rsp.state = common::msg::weld_system::OnWeldSystemStateChange::State::INIT;
      break;
  }

  socket_->Send(rsp);
}

void WeldSystemServerImpl::SubscribeWeldSystemStateChanges(
    common::msg::weld_system::SubscribeWeldSystemStateChanges /*data*/) {
  state_change_subscriber_ = true;

  for (auto [id, data] : weld_systems_) {
    SendStateChange(id, data);
  }
}

void WeldSystemServerImpl::UnSubscribeWeldSystemStateChanges(
    common::msg::weld_system::UnSubscribeWeldSystemStateChanges /*data*/) {
  state_change_subscriber_ = false;
}

void WeldSystemServerImpl::OnPowerSourceInput(uint32_t index, WeldSystem_PlcToAdaptio const& data) {
  auto const iter   = weld_systems_.find(index);
  auto const update = iter == weld_systems_.end() || iter->second.get_state() != data.get_state() ||
                      iter->second.get_status_enabled() != data.get_status_enabled();

  weld_systems_[index] = data;

  if (update) {
    SendStateChange(index, data);
  }
}

}  // namespace controller
