// NOLINTBEGIN(*-magic-numbers, *-optional-access)

#include <doctest/doctest.h>

#include "block_tests/helpers/helpers_settings.h"
#include "common/logging/application_log.h"
#include "controller/controller_data.h"
#include "coordination/activity_status.h"
#include "helpers/helpers.h"
#include "helpers/helpers_joint_geometry.h"
#include "helpers/helpers_mfx.h"
#include "helpers/helpers_web_hmi.h"
#include "web_hmi/web_hmi_json_helpers.h"

const uint32_t HEARTBEAT_1 = 100;
const uint32_t HEARTBEAT_2 = 101;

const uint32_t HEARTBEAT_SUPERVISION_TIME_PLUS_DELTA_WITHIN_LIMIT = 250;
const uint32_t HEARTBEAT_SUPERVISION_TIME_PLUS_DELTA_TIMEOUT      = 501;

TEST_SUITE("Heartbeat") {
  TEST_CASE("Joint_tracking_continues_heartbeat_ok") {
    MultiFixture mfx;

    StoreSettings(mfx.Main(), TestSettings{.use_edge_sensor = false}, true);
    StoreDefaultJointGeometryParams(mfx.Main());

    mfx.Ctrl().Sut()->SuperviseHeartbeat();

    TrackingPreconditions(mfx);

    // Start tracking via WebHMI
    TrackingStart(mfx);

    // Set heartbeat via SystemControl
    controller::SystemControl_PlcToAdaptio system_control_input;
    system_control_input.set_heartbeat(HEARTBEAT_1);
    mfx.Ctrl().Sut()->OnSystemControlInputUpdate(system_control_input);
    mfx.PlcDataUpdate();

    // Check heartbeat loopback
    CHECK_EQ(mfx.Ctrl().Mock()->system_control_output.get_heartbeat(), HEARTBEAT_1);

    // Check activity status is TRACKING
    auto get_activity_status = web_hmi::CreateMessage("GetActivityStatus", std::nullopt, nlohmann::json{});
    mfx.Main().WebHmiIn()->DispatchMessage(std::move(get_activity_status));
    mfx.PlcDataUpdate();
    auto status_payload = ReceiveJsonByName(mfx.Main(), "GetActivityStatusRsp");
    CHECK(status_payload != nullptr);
    auto const activity_status_tracking = static_cast<uint32_t>(coordination::ActivityStatusE::TRACKING);
    CHECK_EQ(status_payload.at("payload").at("value"), activity_status_tracking);

    // Heartbeat ok - increase heartbeat
    system_control_input.set_heartbeat(HEARTBEAT_2);
    mfx.Ctrl().Sut()->OnSystemControlInputUpdate(system_control_input);

    mfx.Main().GetClockNowFuncWrapper()->StepSteadyClock(
        std::chrono::milliseconds{HEARTBEAT_SUPERVISION_TIME_PLUS_DELTA_TIMEOUT});
    mfx.PlcDataUpdate();

    // Check heartbeat loopback updated
    CHECK_EQ(mfx.Ctrl().Mock()->system_control_output.get_heartbeat(), HEARTBEAT_2);

    // Check activity status still TRACKING
    get_activity_status = web_hmi::CreateMessage("GetActivityStatus", std::nullopt, nlohmann::json{});
    mfx.Main().WebHmiIn()->DispatchMessage(std::move(get_activity_status));
    mfx.PlcDataUpdate();
    status_payload = ReceiveJsonByName(mfx.Main(), "GetActivityStatusRsp");
    CHECK(status_payload != nullptr);
    CHECK_EQ(status_payload.at("payload").at("value"), activity_status_tracking);
  }

  TEST_CASE("Joint_tracking_stop_after_500ms_when_heartbeat_fail") {
    MultiFixture mfx;

    StoreSettings(mfx.Main(), TestSettings{.use_edge_sensor = false}, true);
    StoreDefaultJointGeometryParams(mfx.Main());

    mfx.Ctrl().Sut()->SuperviseHeartbeat();
    TrackingPreconditions(mfx);

    // Start tracking via WebHMI
    TrackingStart(mfx);

    // Tracking start with heartbeat
    controller::SystemControl_PlcToAdaptio system_control_input;
    system_control_input.set_heartbeat(HEARTBEAT_1);
    mfx.Ctrl().Sut()->OnSystemControlInputUpdate(system_control_input);
    mfx.PlcDataUpdate();

    CHECK_EQ(mfx.Ctrl().Mock()->system_control_output.get_heartbeat(), HEARTBEAT_1);

    // Check activity status is TRACKING
    auto get_activity_status = web_hmi::CreateMessage("GetActivityStatus", std::nullopt, nlohmann::json{});
    mfx.Main().WebHmiIn()->DispatchMessage(std::move(get_activity_status));
    mfx.PlcDataUpdate();
    auto status_payload = ReceiveJsonByName(mfx.Main(), "GetActivityStatusRsp");
    CHECK(status_payload != nullptr);
    auto const activity_status_tracking = static_cast<uint32_t>(coordination::ActivityStatusE::TRACKING);
    CHECK_EQ(status_payload.at("payload").at("value"), activity_status_tracking);

    // Heartbeat fail to increase - send same heartbeat again
    mfx.Ctrl().Sut()->OnSystemControlInputUpdate(system_control_input);
    mfx.PlcDataUpdate();

    // Check activity status still TRACKING (within timeout)
    get_activity_status = web_hmi::CreateMessage("GetActivityStatus", std::nullopt, nlohmann::json{});
    mfx.Main().WebHmiIn()->DispatchMessage(std::move(get_activity_status));
    mfx.PlcDataUpdate();
    status_payload = ReceiveJsonByName(mfx.Main(), "GetActivityStatusRsp");
    CHECK(status_payload != nullptr);
    CHECK_EQ(status_payload.at("payload").at("value"), activity_status_tracking);

    // Heartbeat fail to increase wait time <500ms
    mfx.Main().GetClockNowFuncWrapper()->StepSteadyClock(
        std::chrono::milliseconds{HEARTBEAT_SUPERVISION_TIME_PLUS_DELTA_WITHIN_LIMIT});
    mfx.PlcDataUpdate();

    // Check activity status still TRACKING
    get_activity_status = web_hmi::CreateMessage("GetActivityStatus", std::nullopt, nlohmann::json{});
    mfx.Main().WebHmiIn()->DispatchMessage(std::move(get_activity_status));
    mfx.PlcDataUpdate();
    status_payload = ReceiveJsonByName(mfx.Main(), "GetActivityStatusRsp");
    CHECK(status_payload != nullptr);
    CHECK_EQ(status_payload.at("payload").at("value"), activity_status_tracking);

    // Heartbeat fail to increase wait time >500ms - should trigger heartbeat lost
    mfx.Main().GetClockNowFuncWrapper()->StepSteadyClock(
        std::chrono::milliseconds{HEARTBEAT_SUPERVISION_TIME_PLUS_DELTA_TIMEOUT});
    mfx.PlcDataUpdate();
    // An extra update ot forward the heartbeat lost to main.
    // Maybe it would be better to always stepSteadyClock to trigger this
    mfx.PlcDataUpdate();

    // Check activity status changed to IDLE (tracking stopped)
    get_activity_status = web_hmi::CreateMessage("GetActivityStatus", std::nullopt, nlohmann::json{});
    mfx.Main().WebHmiIn()->DispatchMessage(std::move(get_activity_status));
    mfx.PlcDataUpdate();
    status_payload = ReceiveJsonByName(mfx.Main(), "GetActivityStatusRsp");
    CHECK(status_payload != nullptr);
    auto const activity_status_idle = static_cast<uint32_t>(coordination::ActivityStatusE::IDLE);
    CHECK_EQ(status_payload.at("payload").at("value"), activity_status_idle);
  }
}
