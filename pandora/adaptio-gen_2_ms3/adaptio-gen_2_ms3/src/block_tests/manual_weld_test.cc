// NOLINTBEGIN(*-magic-numbers, *-optional-access)

#include <doctest/doctest.h>

#include "common/messages/weld_system.h"
#include "controller/controller_data.h"
#include "helpers/helpers.h"
#include "helpers/helpers_web_hmi.h"
#include "helpers/helpers_weld_data_set.h"
#include "helpers/helpers_weld_parameters.h"
#include "helpers/helpers_weld_process_parameters.h"
#include "helpers/helpers_weld_system.h"
#include "weld_system_client/weld_system_types.h"

namespace {

// Helper: set up two WPPs and one WDS, select the WDS, return the wds id (1)
auto SetupAndSelectWds(MultiFixture& mfx) -> int {
  using weld_parameters_test_data::WPP_DEFAULT_WS1;
  using weld_parameters_test_data::WPP_DEFAULT_WS2;

  AddWeldProcessParameters(mfx.Main(), WPP_DEFAULT_WS1, true);
  AddWeldProcessParameters(mfx.Main(), WPP_DEFAULT_WS2, true);

  CHECK(AddWeldDataSet(mfx.Main(), "TestWeld", 1, 2, true));
  CHECK(SelectWeldDataSet(mfx.Main(), 1, true));
  return 1;
}

// Helper: advance both power sources to READY_TO_START
auto MakeReady(MultiFixture& mfx) {
  DispatchWeldSystemStateChange(mfx.Main(), weld_system::WeldSystemId::ID1,
                                common::msg::weld_system::OnWeldSystemStateChange::State::READY_TO_START);
  DispatchWeldSystemStateChange(mfx.Main(), weld_system::WeldSystemId::ID2,
                                common::msg::weld_system::OnWeldSystemStateChange::State::READY_TO_START);
  mfx.PlcDataUpdate();
}

// Helper: simulate start button press
auto PressStart(MultiFixture& mfx) {
  controller::SystemControl_PlcToAdaptio input;
  input.set_commands_start_request(true);
  mfx.Ctrl().Sut()->OnSystemControlInputUpdate(input);
  mfx.PlcDataUpdate();
}

// Helper: simulate stop button press
auto PressStop(MultiFixture& mfx) {
  controller::SystemControl_PlcToAdaptio input;
  input.set_commands_stop_request(true);
  mfx.Ctrl().Sut()->OnSystemControlInputUpdate(input);
  mfx.PlcDataUpdate();
}

}  // namespace

TEST_SUITE("ManualWeld") {
  TEST_CASE("select_weld_data_set_transitions_state") {
    MultiFixture mfx;

    // Subscribe to state before doing anything
    auto sub_msg = web_hmi::CreateMessage("SubscribeArcState", std::nullopt, nlohmann::json{});
    mfx.Main().WebHmiIn()->DispatchMessage(std::move(sub_msg));

    // Initial push: IDLE
    auto state_msg = ReceiveJsonByName(mfx.Main(), "ArcState");
    CHECK_EQ(state_msg.at("payload").at("state"), "idle");

    // Select WDS → CONFIGURED
    SetupAndSelectWds(mfx);

    state_msg = ReceiveJsonByName(mfx.Main(), "ArcState");
    CHECK_EQ(state_msg.at("payload").at("state"), "configured");

    // Both power sources READY_TO_START → READY
    MakeReady(mfx);

    state_msg = ReceiveJsonByName(mfx.Main(), "ArcState");
    CHECK_EQ(state_msg.at("payload").at("state"), "ready");
  }

  TEST_CASE("start_stop_weld_state_machine") {
    MultiFixture mfx;

    auto sub_msg = web_hmi::CreateMessage("SubscribeArcState", std::nullopt, nlohmann::json{});
    mfx.Main().WebHmiIn()->DispatchMessage(std::move(sub_msg));
    ReceiveJsonByName(mfx.Main(), "ArcState");  // consume IDLE

    SetupAndSelectWds(mfx);
    ReceiveJsonByName(mfx.Main(), "ArcState");  // consume CONFIGURED

    MakeReady(mfx);
    ReceiveJsonByName(mfx.Main(), "ArcState");  // consume READY

    // Start button → STARTING
    PressStart(mfx);

    auto state_msg = ReceiveJsonByName(mfx.Main(), "ArcState");
    CHECK_EQ(state_msg.at("payload").at("state"), "starting");
    CHECK(mfx.Ctrl().Mock()->weld_control_output.get_commands_start());

    // Power source reports ARCING → ACTIVE
    DispatchWeldSystemStateChange(mfx.Main(), weld_system::WeldSystemId::ID1,
                                  common::msg::weld_system::OnWeldSystemStateChange::State::ARCING);
    mfx.PlcDataUpdate();

    state_msg = ReceiveJsonByName(mfx.Main(), "ArcState");
    CHECK_EQ(state_msg.at("payload").at("state"), "active");

    // Stop button → stop command sent
    PressStop(mfx);
    CHECK(mfx.Ctrl().Mock()->weld_control_output.get_commands_stop());

    // Power source leaves ARCING → READY
    DispatchWeldSystemStateChange(mfx.Main(), weld_system::WeldSystemId::ID1,
                                  common::msg::weld_system::OnWeldSystemStateChange::State::READY_TO_START);
    mfx.PlcDataUpdate();

    state_msg = ReceiveJsonByName(mfx.Main(), "ArcState");
    CHECK_EQ(state_msg.at("payload").at("state"), "ready");
  }

  TEST_CASE("weld_data_push_on_timer") {
    MultiFixture mfx;

    SetupAndSelectWds(mfx);
    MakeReady(mfx);
    PressStart(mfx);

    DispatchWeldSystemStateChange(mfx.Main(), weld_system::WeldSystemId::ID1,
                                  common::msg::weld_system::OnWeldSystemStateChange::State::ARCING);
    mfx.PlcDataUpdate();

    // Subscribe to weld data
    auto sub_msg = web_hmi::CreateMessage("SubscribeWeldData", std::nullopt, nlohmann::json{});
    mfx.Main().WebHmiIn()->DispatchMessage(std::move(sub_msg));

    auto sub_rsp = ReceiveJsonByName(mfx.Main(), "SubscribeWeldDataRsp");
    CHECK_EQ(sub_rsp.at("result"), "ok");

    // Fire the 200 ms timer — GetWeldSystemData is dispatched to the controller
    // which responds automatically, triggering WeldData push
    mfx.Main().Timer()->Dispatch("manual_weld_data_timer");

    auto weld_data_msg = ReceiveJsonByName(mfx.Main(), "WeldData");
    CHECK(weld_data_msg.at("payload").contains("weldData"));
  }

  TEST_CASE("setpoint_adjustment_in_ready_state") {
    MultiFixture mfx;

    SetupAndSelectWds(mfx);
    MakeReady(mfx);

    // Adjust voltage on ws1
    nlohmann::json adj_payload = {
        {"wsId",  1   },
        {"delta", 0.5f}
    };
    auto adj_msg = web_hmi::CreateMessage("AdjustVoltage", std::nullopt, adj_payload);
    mfx.Main().WebHmiIn()->DispatchMessage(std::move(adj_msg));

    auto adj_rsp = ReceiveJsonByName(mfx.Main(), "AdjustVoltageRsp");
    CHECK_EQ(adj_rsp.at("result"), "ok");

    mfx.PlcDataUpdate();

    // Voltage on power source 1 should now be WPP_DEFAULT_WS1 voltage (25.0) + 0.5 = 25.5
    CHECK_EQ(mfx.Ctrl().Mock()->power_source_1_output.get_voltage(), 25.5f);
  }
}

// NOLINTEND(*-magic-numbers, *-optional-access)
