#pragma once

#include <doctest/doctest.h>

#include <nlohmann/json.hpp>

#include "controller/controller_data.h"
#include "coordination/activity_status.h"
#include "helpers.h"
#include "helpers_simulator.h"
#include "helpers_web_hmi.h"
#include "simulator_interface.h"
#include "test_utils/testlog.h"
#include "web_hmi/web_hmi_json_helpers.h"

// NOLINTBEGIN(*-magic-numbers, readability-function-cognitive-complexity)

[[maybe_unused]] inline auto ToString(const deposition_simulator::Point3d& point) -> std::string {
  return fmt::format("x: {:.5f} y: {:.5f} z: {:.5f}", point.GetX(), point.GetY(), point.GetZ());
}

inline auto NowTimeStamp(TestFixture& fixture) -> uint64_t {
  return fixture.GetClockNowFuncWrapper()->GetSystemClock().time_since_epoch().count();
}
inline void ProvideScannerAndKinematicsData(MultiFixture& mfx, deposition_simulator::ISimulator& simulator,
                                            const deposition_simulator::Point3d& point) {
  auto abws_lpcs  = helpers_simulator::ConvertFromOptionalAbwVector(simulator.GetAbwPoints(deposition_simulator::LPCS));
  auto slice_data = helpers_simulator::GetSliceData(abws_lpcs, simulator, NowTimeStamp(mfx.Main()));

  // update slide position from simulator
  controller::WeldHeadManipulator_PlcToAdaptio weld_head_manipulator_data{};
  weld_head_manipulator_data.set_x_position(static_cast<float>(helpers_simulator::ConvertM2Mm(point.GetX())));
  weld_head_manipulator_data.set_y_position(static_cast<float>(helpers_simulator::ConvertM2Mm(point.GetZ())));
  mfx.Ctrl().Sut()->OnWeldHeadManipulatorInputUpdate(weld_head_manipulator_data);

  mfx.PlcDataUpdate();

  mfx.Main().Scanner()->Dispatch(slice_data);
}

inline auto TrackingPreconditions(MultiFixture& mfx) {
  controller::WeldAxis_PlcToAdaptio weld_axis_data;
  weld_axis_data.set_status_reference_valid(true);
  weld_axis_data.set_state(0);  // Ready state
  weld_axis_data.set_radius(1000.0);
  mfx.Ctrl().Sut()->OnWeldAxisInputUpdate(weld_axis_data);

  mfx.PlcDataUpdate();

  auto subscribe_msg = web_hmi::CreateMessage("SubscribeReadyState", std::nullopt, nlohmann::json{});
  mfx.Main().WebHmiIn()->DispatchMessage(std::move(subscribe_msg));
  auto ready_msg = ReceiveJsonByName(mfx.Main(), "ReadyState");
  CHECK(ready_msg != nullptr);
  CHECK_EQ(ready_msg.at("payload").at("state"), "tracking_ready");
}

inline auto TrackingStart(MultiFixture& mfx) {
  auto const payload = nlohmann::json({
      {"joint_tracking_mode", "left"},
      {"horizontal_offset",   10.0  },
      {"vertical_offset",     20.0  }
  });

  auto msg = web_hmi::CreateMessage("TrackingStart", std::nullopt, payload);
  mfx.Main().WebHmiIn()->DispatchMessage(std::move(msg));

  auto get_activity_status = web_hmi::CreateMessage("GetActivityStatus", std::nullopt, {});
  mfx.Main().WebHmiIn()->DispatchMessage(std::move(get_activity_status));
  auto status_payload = ReceiveJsonByName(mfx.Main(), "GetActivityStatusRsp");
  CHECK(status_payload != nullptr);
  auto const activity_status_tracking = static_cast<uint32_t>(coordination::ActivityStatusE::TRACKING);
  CHECK_EQ(status_payload.at("payload").at("value"), activity_status_tracking);
}

// NOLINTEND(*-magic-numbers, readability-function-cognitive-complexity)
