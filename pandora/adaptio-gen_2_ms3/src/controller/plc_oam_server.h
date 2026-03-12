#pragma once

#include <cstdint>

namespace controller {

class PlcOamServer {
 public:
  virtual ~PlcOamServer() = default;

  virtual void OnShutdownRequestInput()                                                          = 0;
  virtual void OnHeartbeatLostInput()                                                            = 0;
  virtual void OnSystemVersionsInput(uint32_t aws_major, uint32_t aws_minor, uint32_t aws_patch) = 0;
};

}  // namespace controller
