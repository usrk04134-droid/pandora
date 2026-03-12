#pragma once
#include <map>

#include "common/messages/weld_system.h"
#include "common/zevs/zevs_socket.h"
#include "controller/controller_data.h"
#include "weld_system_server.h"

namespace controller {

class WeldSystemServerImpl : public WeldSystemServer {
 public:
  explicit WeldSystemServerImpl(zevs::Socket* socket, WeldSystemServerObserver* observer);

  void OnPowerSourceInput(uint32_t index, WeldSystem_PlcToAdaptio const& data) override;

 private:
  zevs::Socket* socket_;
  WeldSystemServerObserver* observer_;
  bool state_change_subscriber_{false};

  std::map<uint32_t, WeldSystem_PlcToAdaptio> weld_systems_;
  WeldControl_AdaptioToPlc weld_control_command_cache_{};
  void OnGetWeldSystemData(common::msg::weld_system::GetWeldSystemData data);
  void OnSetWeldSystemSettings(common::msg::weld_system::SetWeldSystemSettings data);
  void OnWeldControlCommand(common::msg::weld_system::WeldControlCommand data);
  void SendStateChange(uint32_t index, const WeldSystem_PlcToAdaptio& data);
  void SubscribeWeldSystemStateChanges(common::msg::weld_system::SubscribeWeldSystemStateChanges data);
  void UnSubscribeWeldSystemStateChanges(common::msg::weld_system::UnSubscribeWeldSystemStateChanges data);
};

}  // namespace controller
