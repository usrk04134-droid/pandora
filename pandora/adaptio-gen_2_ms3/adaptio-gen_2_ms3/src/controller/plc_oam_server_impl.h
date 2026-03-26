#pragma once

#include <cstdint>

#include "common/messages/plc_oam.h"
#include "common/zevs/zevs_socket.h"
#include "plc_oam_server.h"

namespace controller {

class PlcOamServerImpl : public PlcOamServer {
 public:
  explicit PlcOamServerImpl(zevs::Socket* socket);

  void OnShutdownRequestInput() override;
  void OnHeartbeatLostInput() override;
  void OnSystemVersionsInput(uint32_t aws_major, uint32_t aws_minor, uint32_t aws_patch) override;

 private:
  zevs::Socket* socket_;
  uint32_t aws_major_{0};
  uint32_t aws_minor_{0};
  uint32_t aws_patch_{0};
  bool shutdown_sent_{false};

  void OnGetPlcSwVersion(common::msg::plc_oam::GetPlcSwVersion data);
};

}  // namespace controller
