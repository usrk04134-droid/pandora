#include "controller/controller_data.h"
#include "helpers/helpers.h"
#include "helpers/helpers_abp_parameters.h"
#include "helpers/helpers_calibration.h"
#include "helpers/helpers_joint_geometry.h"
#include "helpers/helpers_settings.h"
#include "helpers/helpers_web_hmi.h"
#include "web_hmi/web_hmi_json_helpers.h"

// NOLINTBEGIN(*-magic-numbers, *-optional-access)

#include <doctest/doctest.h>

#include <nlohmann/json.hpp>

TEST_SUITE("MultiblockReadyState") {
  TEST_CASE("tracking_not_ready_on_weld_calibration") {
    MultiFixture mfx;

    StoreSettings(mfx.Main(), TestSettings{.use_edge_sensor = false}, true);
    StoreDefaultJointGeometryParams(mfx.Main());

    auto subscribe_msg = web_hmi::CreateMessage("SubscribeReadyState", std::nullopt, nlohmann::json{});
    mfx.Main().WebHmiIn()->DispatchMessage(std::move(subscribe_msg));
    auto ready_msg = ReceiveJsonByName(mfx.Main(), "ReadyState");
    CHECK(ready_msg != nullptr);
    CHECK_EQ(ready_msg.at("payload").at("state"), "tracking_ready");

    WeldObjectCalStart(mfx.Main(), 4.0, 25.0, 1000.0);
    mfx.PlcDataUpdate();

    ready_msg = ReceiveJsonByName(mfx.Main(), "ReadyState");
    CHECK(ready_msg != nullptr);
    CHECK_EQ(ready_msg.at("payload").at("state"), "not_ready");
  }

  TEST_CASE("abp_ready_1") {
    MultiFixture mfx;
    controller::WeldAxis_PlcToAdaptio weld_axis_data{};

    StoreSettings(mfx.Main(), TestSettings{.use_edge_sensor = false}, true);
    StoreDefaultJointGeometryParams(mfx.Main());

    auto subscribe_msg = web_hmi::CreateMessage("SubscribeReadyState", std::nullopt, nlohmann::json{});
    mfx.Main().WebHmiIn()->DispatchMessage(std::move(subscribe_msg));
    auto ready_msg = ReceiveJsonByName(mfx.Main(), "ReadyState");
    CHECK(ready_msg != nullptr);
    CHECK_EQ(ready_msg.at("payload").at("state"), "tracking_ready");

    CHECK_FALSE(OptionalReceiveJsonByName(mfx.Main(), "ReadyState"));

    StoreDefaultABPParams(mfx.Main());
    weld_axis_data.set_status_reference_valid(true);
    mfx.Ctrl().Sut()->OnWeldAxisInputUpdate(weld_axis_data);
    mfx.PlcDataUpdate();

    ready_msg = ReceiveJsonByName(mfx.Main(), "ReadyState");
    CHECK(ready_msg != nullptr);
    CHECK_EQ(ready_msg.at("payload").at("state"), "abp_ready");
  }

  TEST_CASE("abp_jt_ready_with_edge_sensor") {
    MultiFixture mfx;
    controller::WeldAxis_PlcToAdaptio weld_axis_data{};

    StoreDefaultJointGeometryParams(mfx.Main());

    StoreDefaultABPParams(mfx.Main());
    StoreSettings(mfx.Main(), TestSettings{.use_edge_sensor = true}, true);

    auto subscribe_msg = web_hmi::CreateMessage("SubscribeReadyState", std::nullopt, nlohmann::json{});
    mfx.Main().WebHmiIn()->DispatchMessage(std::move(subscribe_msg));

    weld_axis_data.set_status_reference_valid(true);
    mfx.Ctrl().Sut()->OnWeldAxisInputUpdate(weld_axis_data);
    mfx.PlcDataUpdate();

    auto ready_msg = ReceiveJsonByName(mfx.Main(), "ReadyState");
    CHECK(ready_msg != nullptr);
    CHECK_EQ(ready_msg.at("payload").at("state"), "not_ready");
  }
}
