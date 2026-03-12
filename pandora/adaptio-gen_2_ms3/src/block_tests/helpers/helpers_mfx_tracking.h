#pragma once

#include <doctest/doctest.h>
#include <fmt/core.h>

#include <nlohmann/json.hpp>

#include "block_tests/helpers/helpers_mfx.h"
#include "controller/controller_data.h"
#include "helpers.h"
#include "helpers_simulator.h"
#include "simulator_interface.h"
#include "test_utils/testlog.h"
#include "web_hmi/web_hmi_json_helpers.h"

// NOLINTBEGIN(*-magic-numbers, *-optional-access)

namespace depsim = deposition_simulator;

inline void JointTracking(MultiFixture& mfx, deposition_simulator::ISimulator& simulator, double horizontal_offset,
                          double vertical_offset) {
  auto torch_pos = simulator.GetTorchPosition(depsim::MACS);
  TESTLOG(">>>>> Starting Tracking, with torch position: {}", ToString(torch_pos));

  controller::WeldAxis_PlcToAdaptio weld_axis_data;
  weld_axis_data.set_position(1.23);
  weld_axis_data.set_velocity(2.55);
  weld_axis_data.set_radius(3500.0);
  weld_axis_data.set_linear_object_distance(0.0);
  weld_axis_data.set_status_reference_valid(true);
  mfx.Ctrl().Sut()->OnWeldAxisInputUpdate(weld_axis_data);

  auto const payload = nlohmann::json({
      {"joint_tracking_mode", "center"         },
      {"horizontal_offset",   horizontal_offset},
      {"vertical_offset",     vertical_offset  }
  });
  auto msg           = web_hmi::CreateMessage("TrackingStart", std::nullopt, payload);
  mfx.Main().WebHmiIn()->DispatchMessage(std::move(msg));

  mfx.PlcDataUpdate();

  ProvideScannerAndKinematicsData(mfx, simulator, torch_pos);

  auto horizontal_pos_m = helpers_simulator::ConvertMm2M(
      static_cast<double>(mfx.Ctrl().Mock()->weld_head_manipulator_output.get_x_position()));
  auto vertical_pos_m = helpers_simulator::ConvertMm2M(
      static_cast<double>(mfx.Ctrl().Mock()->weld_head_manipulator_output.get_y_position()));

  // Update the torch position
  depsim::Point3d torch_pos_macs(horizontal_pos_m, 0, vertical_pos_m, depsim::MACS);
  simulator.UpdateTorchPosition(torch_pos_macs);

  TESTLOG(">>>>> Tracking, moved to torch position: {}", ToString(torch_pos_macs));
}

inline void ValidateCenterTracking(deposition_simulator::ISimulator& simulator, double vertical_offset) {
  auto abw_in_torch_plane =
      helpers_simulator::ConvertFromOptionalAbwVector(simulator.GetSliceInTorchPlane(depsim::MACS));
  auto expected_x = std::midpoint(abw_in_torch_plane.front().GetX(), abw_in_torch_plane.back().GetX());
  auto expected_z = abw_in_torch_plane[3].GetZ() + vertical_offset;

  auto final_torch_pos     = simulator.GetTorchPosition(depsim::MACS);
  const double tolerance_m = 0.001;
  CHECK(std::abs((final_torch_pos.GetX() - expected_x)) < tolerance_m);
  CHECK(std::abs((final_torch_pos.GetZ() - expected_z)) < tolerance_m);
}

// NOLINTEND(*-magic-numbers, *-optional-access)
