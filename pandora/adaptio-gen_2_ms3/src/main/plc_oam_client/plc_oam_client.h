#pragma once

#include <cstdint>
#include <functional>

namespace plc_oam_client {

struct PlcSwVersion {
  uint32_t aws_major{0};
  uint32_t aws_minor{0};
  uint32_t aws_patch{0};
};

using GetPlcSwVersionCb = std::function<void(PlcSwVersion const& version)>;
using HeartbeatLostCb   = std::function<void()>;
using ShutdownCb        = std::function<void()>;

class PlcOamClient {
 public:
  virtual ~PlcOamClient() = default;

  virtual void GetPlcSwVersion(GetPlcSwVersionCb on_response)              = 0;
  virtual void SetHeartbeatLostCallback(HeartbeatLostCb on_heartbeat_lost) = 0;
  virtual void SetShutdownCallback(ShutdownCb on_shutdown)                 = 0;
};

}  // namespace plc_oam_client
