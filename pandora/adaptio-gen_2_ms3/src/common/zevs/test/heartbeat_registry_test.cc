#include "../src/heartbeat_registry.h"

#include <doctest/doctest.h>
#include <pthread.h>

#include <chrono>
#include <string>
#include <thread>
#include <vector>

// NOLINTBEGIN(*-magic-numbers)

TEST_SUITE("heartbeat_registry_tests") {
  TEST_CASE("register_and_unregister") {
    zevs::HeartbeatRegistry registry;

    registry.Register("test_loop_1");

    // Should not be stale immediately
    auto stale = registry.CheckAll(std::chrono::milliseconds(1000));
    CHECK(stale.empty());

    registry.Unregister("test_loop_1");
    stale = registry.CheckAll(std::chrono::milliseconds(1000));
    CHECK(stale.empty());
  }

  TEST_CASE("update_prevents_stale") {
    zevs::HeartbeatRegistry registry;

    registry.Register("test_loop_2");

    // Sleep a bit
    std::this_thread::sleep_for(std::chrono::milliseconds(50));

    // Update should reset the timestamp
    registry.Update("test_loop_2");

    // Should not be stale with a reasonable threshold
    auto stale = registry.CheckAll(std::chrono::milliseconds(100));
    CHECK(stale.empty());

    registry.Unregister("test_loop_2");
  }

  TEST_CASE("detect_stale_entry") {
    zevs::HeartbeatRegistry registry;

    registry.Register("test_loop_3");

    // Sleep longer than the threshold
    std::this_thread::sleep_for(std::chrono::milliseconds(60));

    // Should be stale with a short threshold
    auto stale = registry.CheckAll(std::chrono::milliseconds(30));
    REQUIRE(stale.size() == 1);
    CHECK(stale[0].name == "test_loop_3");
    CHECK(stale[0].thread_id == pthread_self());

    registry.Unregister("test_loop_3");
  }

  TEST_CASE("multiple_entries") {
    zevs::HeartbeatRegistry registry;

    registry.Register("loop_a");
    registry.Register("loop_b");
    registry.Register("loop_c");

    // Initially none should be stale
    auto stale = registry.CheckAll(std::chrono::milliseconds(1000));
    CHECK(stale.empty());

    // Sleep and only update some
    std::this_thread::sleep_for(std::chrono::milliseconds(60));
    registry.Update("loop_a");
    registry.Update("loop_c");

    // loop_b should be stale
    stale = registry.CheckAll(std::chrono::milliseconds(30));
    REQUIRE(stale.size() == 1);
    CHECK(stale[0].name == "loop_b");

    registry.Unregister("loop_a");
    registry.Unregister("loop_b");
    registry.Unregister("loop_c");
  }

  TEST_CASE("thread_id_captured_from_registering_thread") {
    zevs::HeartbeatRegistry registry;

    pthread_t registering_thread_id{};
    std::thread t([&] {
      registering_thread_id = pthread_self();
      registry.Register("thread_loop");
      std::this_thread::sleep_for(std::chrono::milliseconds(60));
    });
    t.join();

    auto stale = registry.CheckAll(std::chrono::milliseconds(30));
    REQUIRE(stale.size() == 1);
    CHECK(stale[0].thread_id == registering_thread_id);

    registry.Unregister("thread_loop");
  }

  TEST_CASE("update_nonexistent_entry_is_safe") {
    zevs::HeartbeatRegistry registry;

    // Should not crash or throw
    registry.Update("nonexistent");

    auto stale = registry.CheckAll(std::chrono::milliseconds(100));
    CHECK(stale.empty());
  }

  TEST_CASE("unregister_nonexistent_entry_is_safe") {
    zevs::HeartbeatRegistry registry;

    // Should not crash or throw
    registry.Unregister("nonexistent");
  }

  TEST_CASE("clear_removes_all_entries") {
    zevs::HeartbeatRegistry registry;

    registry.Register("entry_1");
    registry.Register("entry_2");

    // Wait to make them stale
    std::this_thread::sleep_for(std::chrono::milliseconds(60));

    // Should have 2 stale
    auto stale = registry.CheckAll(std::chrono::milliseconds(30));
    CHECK(stale.size() == 2);

    // Clear
    registry.Clear();

    // Should have none
    stale = registry.CheckAll(std::chrono::milliseconds(30));
    CHECK(stale.empty());
  }
}

// NOLINTEND(*-magic-numbers)
