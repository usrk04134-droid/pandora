#include "heartbeat_registry.h"

#include <pthread.h>

#include <chrono>
#include <mutex>
#include <string>
#include <vector>

namespace zevs {

void HeartbeatRegistry::Register(const std::string& name) {
  std::lock_guard<std::mutex> lock(mutex_);
  entries_[name] = {.last_heartbeat = std::chrono::steady_clock::now(), .thread_id = pthread_self()};
}

void HeartbeatRegistry::Update(const std::string& name) {
  std::lock_guard<std::mutex> lock(mutex_);
  auto it = entries_.find(name);
  if (it != entries_.end()) {
    it->second.last_heartbeat = std::chrono::steady_clock::now();
  }
}

void HeartbeatRegistry::Unregister(const std::string& name) {
  std::lock_guard<std::mutex> lock(mutex_);
  entries_.erase(name);
}

auto HeartbeatRegistry::CheckAll(std::chrono::milliseconds threshold) -> std::vector<StaleEntry> {
  std::lock_guard<std::mutex> lock(mutex_);
  std::vector<StaleEntry> stale;
  auto now = std::chrono::steady_clock::now();

  for (const auto& [name, entry] : entries_) {
    auto age = std::chrono::duration_cast<std::chrono::milliseconds>(now - entry.last_heartbeat);
    if (age > threshold) {
      stale.push_back({name, entry.thread_id});
    }
  }

  return stale;
}

void HeartbeatRegistry::Clear() {
  std::lock_guard<std::mutex> lock(mutex_);
  entries_.clear();
}

}  // namespace zevs
