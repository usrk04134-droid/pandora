#pragma once

#include "common/messages/plc_oam.h"
#include "common/zevs/zevs_socket.h"
#include "plc_oam_client/plc_oam_client.h"

namespace plc_oam_client {

class PlcOamClientImpl : public PlcOamClient {
 public:
  explicit PlcOamClientImpl(zevs::Socket* socket);

  void GetPlcSwVersion(GetPlcSwVersionCb on_response) override;
  void SetHeartbeatLostCallback(HeartbeatLostCb on_heartbeat_lost) override;
  void SetShutdownCallback(ShutdownCb on_shutdown) override;

 private:
  void OnGetPlcSwVersionRsp(common::msg::plc_oam::GetPlcSwVersionRsp data);
  void OnHeartbeatLost(common::msg::plc_oam::HeartbeatLost data);
  void OnShutdown(common::msg::plc_oam::Shutdown data);

  zevs::Socket* socket_;
  GetPlcSwVersionCb on_get_version_;
  HeartbeatLostCb on_heartbeat_lost_;
  ShutdownCb on_shutdown_;
};

}  // namespace plc_oam_client
