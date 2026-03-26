#include <doctest/doctest.h>

#include <atomic>
#include <chrono>
#include <string>
#include <thread>

#include "../src/heartbeat_registry.h"
#include "../zevs_core.h"

TEST_SUITE("context_monitor_tests") {
  TEST_CASE("monitor_starts_and_stops_cleanly") {
    std::atomic<bool> handler_called{false};

    {
      auto context = zevs::GetCoreFactory()->CreateContext();

      context->MonitorEventLoops([&](const std::string& /*name*/) { handler_called = true; });

      // Brief sleep to let monitor thread start
      std::this_thread::sleep_for(std::chrono::milliseconds(50));

      // Context destructor should stop the monitor thread
    }

    // If we get here without hanging, the monitor started and stopped cleanly
    CHECK_FALSE(handler_called);
  }

  TEST_CASE("heartbeat_registry_available_with_context") {
    auto context = zevs::GetCoreFactory()->CreateContext();

    auto* registry = zevs::GetHeartbeatRegistry();
    REQUIRE(registry != nullptr);

    // Can register and unregister
    registry->Register("test_loop");
    registry->Update("test_loop");
    registry->Unregister("test_loop");
  }

  TEST_CASE("GetHeartbeatRegistry_returns_null_without_context") {
    // Without a context, GetHeartbeatRegistry should return nullptr
    auto* registry = zevs::GetHeartbeatRegistry();
    CHECK(registry == nullptr);
  }
}
