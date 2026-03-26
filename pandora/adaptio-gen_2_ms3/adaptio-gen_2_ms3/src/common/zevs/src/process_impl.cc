#include "process_impl.h"

#include <pthread.h>

#include <algorithm>
#include <chrono>
#include <csignal>
#include <string>
#include <zmq.hpp>

#include "common/logging/application_log.h"

namespace zevs::adapter {
auto GetGlobalContext() -> zmq::context_t * { return zevs::GetGlobalContext(); }
}  // namespace zevs::adapter

namespace zevs {

uint32_t const MONITOR_CHECK_INTERVAL_MS  = 2000;
uint32_t const MONITOR_STALE_THRESHOLD_MS = 5000;

zmq::context_t *s_ctx       = nullptr;
ContextImpl *s_context_impl = nullptr;

ContextImpl::ContextImpl() {
  // One context is shared in the process
  if (s_ctx) {
    LOG_ERROR("ContextImpl(): Context already exists!");
    return;
  }
  s_ctx          = &ctx_;
  s_context_impl = this;
}

ContextImpl::~ContextImpl() {
  StopMonitorThread();
  s_ctx          = nullptr;
  s_context_impl = nullptr;
}

auto GetGlobalContext() -> zmq::context_t * { return s_ctx; }

auto GetHeartbeatRegistry() -> HeartbeatRegistry * {
  if (s_context_impl) {
    return s_context_impl->GetHeartbeatRegistry();
  }
  return nullptr;
}

void ContextImpl::MonitorEventLoops(std::function<void(const std::string &eventloop_name)> on_hang) {
  if (monitor_running_) {
    LOG_ERROR("MonitorEventLoops(): Monitor already running!");
    return;
  }

  on_hang_         = std::move(on_hang);
  monitor_running_ = true;

  monitor_thread_ = std::thread(&ContextImpl::MonitorThreadEntry, this);
}

void ContextImpl::StopMonitorThread() {
  if (!monitor_running_) {
    return;
  }

  monitor_running_ = false;
  monitor_cv_.notify_one();
  if (monitor_thread_.joinable()) {
    monitor_thread_.join();
  }
}

void ContextImpl::MonitorThreadEntry() {
  LOG_INFO("EventLoop monitor started (check_interval={}ms, stale_threshold={}ms)", MONITOR_CHECK_INTERVAL_MS,
           MONITOR_STALE_THRESHOLD_MS);

  auto const check_interval  = std::chrono::milliseconds(MONITOR_CHECK_INTERVAL_MS);
  auto const stale_threshold = std::chrono::milliseconds(MONITOR_STALE_THRESHOLD_MS);

  std::unique_lock<std::mutex> lock(monitor_mutex_);

  while (monitor_running_) {
    // Wait for the check interval, or until woken by StopMonitorThread
    monitor_cv_.wait_for(lock, check_interval, [this] { return !monitor_running_.load(); });

    if (!monitor_running_) {
      break;
    }

    // Check all registered EventLoops for stale heartbeats
    auto stale_entries = heartbeat_registry_.CheckAll(stale_threshold);

    for (const auto &entry : stale_entries) {
      LOG_ERROR("EventLoop hang detected: {}", entry.name);
      if (on_hang_) {
        on_hang_(entry.name);
      }
      pthread_kill(entry.thread_id, SIGABRT);
    }
  }

  LOG_INFO("EventLoop monitor stopped");
}

}  // namespace zevs
