#pragma once

#include <pthread.h>

#include <chrono>
#include <mutex>
#include <string>
#include <unordered_map>
#include <vector>

namespace zevs {

struct StaleEntry {
  std::string name;
  pthread_t thread_id;
};

// Thread-safe registry for EventLoop heartbeat timestamps.
class HeartbeatRegistry {
 public:
  // Register the calling thread's event loop. Captures the calling thread's ID automatically.
  void Register(const std::string& name);

  // Update the heartbeat timestamp for an EventLoop
  void Update(const std::string& name);

  // Unregister an EventLoop
  void Unregister(const std::string& name);

  // Check all registered EventLoops and return stale entries (name + thread handle)
  auto CheckAll(std::chrono::milliseconds threshold) -> std::vector<StaleEntry>;

  void Clear();

 private:
  struct Entry {
    std::chrono::steady_clock::time_point last_heartbeat;
    pthread_t thread_id{};
  };

  std::mutex mutex_;
  std::unordered_map<std::string, Entry> entries_;
};

auto GetHeartbeatRegistry() -> HeartbeatRegistry*;

}  // namespace zevs
