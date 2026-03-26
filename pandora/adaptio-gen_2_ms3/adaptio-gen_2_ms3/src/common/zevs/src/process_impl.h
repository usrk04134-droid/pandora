#pragma once

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <functional>
#include <mutex>
#include <string>
#include <thread>
#include <zmq.hpp>

#include "../zevs_core.h"
#include "heartbeat_registry.h"

namespace zevs {

auto GetGlobalContext() -> zmq::context_t*;

class ContextImpl : public Context {
 public:
  ContextImpl();
  ~ContextImpl() override;

  // noncopyable
  ContextImpl(const ContextImpl&)                    = delete;
  auto operator=(const ContextImpl&) -> ContextImpl& = delete;

  void MonitorEventLoops(std::function<void(const std::string& eventloop_name)> on_hang) override;

  auto GetHeartbeatRegistry() -> HeartbeatRegistry* { return &heartbeat_registry_; }

 private:
  void MonitorThreadEntry();
  void StopMonitorThread();

  zmq::context_t ctx_;
  HeartbeatRegistry heartbeat_registry_;

  // Monitor thread state
  std::thread monitor_thread_;
  std::atomic<bool> monitor_running_{false};
  std::mutex monitor_mutex_;
  std::condition_variable monitor_cv_;
  std::function<void(const std::string&)> on_hang_;
};

}  // namespace zevs
