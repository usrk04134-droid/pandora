#include <doctest/doctest.h>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <format>
#include <map>
#include <memory>
#include <numbers>
#include <optional>
#include <string>
#include <vector>

// #define TESTLOG_DISABLED

#include "common/messages/kinematics.h"
#include "common/messages/scanner.h"
#include "common/messages/weld_system.h"
#include "helpers/helpers.h"
#include "helpers/helpers_kinematics.h"
#include "helpers/helpers_settings.h"
#include "helpers/helpers_simulator.h"
#include "helpers/helpers_tracking.h"
#include "helpers/helpers_weld_control.h"
#include "helpers/helpers_weld_system.h"
#include "point3d.h"
#include "sim-config.h"
#include "simulator_interface.h"
#include "test_utils/testlog.h"
#include "torch-interfaces.h"
#include "tracking/tracking_manager.h"
#include "weld_system_client/weld_system_types.h"

//  NOLINTBEGIN(*-magic-numbers, *-optional-access)

namespace depsim   = deposition_simulator;
namespace help_sim = helpers_simulator;
using method       = weld_system::WeldSystemSettings::Method;

namespace {

const int NUMBER_OF_STEPS_PER_REV{200};
const double DELTA_ANGLE{2. * help_sim::PI / NUMBER_OF_STEPS_PER_REV};
const double SCANNER_MOUNT_ANGLE = 6.0 * help_sim::PI / 180.0;
const double PRE_OVERLAP_LOOK_BACK_M{0.10};
const double MAX_OVERLAP_HOR_DEVIATION_MM{2.0};
const double MAX_OVERLAP_VER_DEVIATION_MM{4.0};
const double STEADY_STATE_REGION_START{0.25};
const double STEADY_STATE_REGION_END{0.75};

struct TorchSample {
  int step;
  double lin_distance_mm;
  double horizontal_mm;
  double vertical_mm;
  std::string bead_operation;
};
auto CheckOverlapDeviation(const std::vector<TorchSample>& samples, double weld_object_diameter_m) -> void {
  double circumference_mm = help_sim::ConvertM2Mm(weld_object_diameter_m * std::numbers::pi);
  double pre_overlap_mm   = help_sim::ConvertM2Mm(PRE_OVERLAP_LOOK_BACK_M);

  int overlap_start_idx = -1;
  for (size_t i = 0; i < samples.size(); ++i) {
    if (samples[i].bead_operation == "overlapping") {
      overlap_start_idx = static_cast<int>(i);
      break;
    }
  }
  REQUIRE_MESSAGE(overlap_start_idx >= 0, "No overlap phase detected during the first bead");

  double overlap_start_distance  = samples[overlap_start_idx].lin_distance_mm;
  double analysis_start_distance = overlap_start_distance - pre_overlap_mm;

  double h_sum = 0.0, v_sum = 0.0;
  int count = 0;
  for (const auto& s : samples) {
    if (s.bead_operation == "steady" && s.lin_distance_mm > circumference_mm * STEADY_STATE_REGION_START &&
        s.lin_distance_mm < circumference_mm * STEADY_STATE_REGION_END) {
      h_sum += s.horizontal_mm;
      v_sum += s.vertical_mm;
      ++count;
    }
  }
  REQUIRE_MESSAGE(count > 0, "No steady-state samples in the middle region of the bead");
  double ref_h     = h_sum / count;
  double ref_v     = v_sum / count;
  double max_h_dev = 0.0, max_v_dev = 0.0;
  int max_h_step = -1, max_v_step = -1;
  for (const auto& s : samples) {
    if (s.lin_distance_mm < analysis_start_distance) {
      continue;
    }
    if (s.bead_operation != "steady" && s.bead_operation != "overlapping") {
      continue;
    }

    double dh = std::abs(s.horizontal_mm - ref_h);
    double dv = std::abs(s.vertical_mm - ref_v);
    if (dh > max_h_dev) {
      max_h_dev  = dh;
      max_h_step = s.step;
    }
    if (dv > max_v_dev) {
      max_v_dev  = dv;
      max_v_step = s.step;
    }
  }
  CHECK_MESSAGE(max_h_dev < MAX_OVERLAP_HOR_DEVIATION_MM,
                std::format("Horizontal torch deviation {:.2f} mm at step {} exceeds {:.1f} mm", max_h_dev, max_h_step,
                            MAX_OVERLAP_HOR_DEVIATION_MM));
  CHECK_MESSAGE(max_v_dev < MAX_OVERLAP_VER_DEVIATION_MM,
                std::format("Vertical torch deviation {:.2f} mm at step {} exceeds {:.1f} mm", max_v_dev, max_v_step,
                            MAX_OVERLAP_VER_DEVIATION_MM));
}

}  // namespace

TEST_SUITE("ABPTests") {
  TEST_CASE("track_steady_during_overlap") {
    help_sim::TestParameters test_parameters{
        .abp_parameters{.wall_offset_mm = 6.,
                        .bead_overlap   = 10.,
                        .step_up_value  = 0.5,
                        .k_gain         = 2.,
                        .heat_input{.min = 2.4, .max = 3.3},
                        .weld_system_2_current{.min = 650., .max = 850.},
                        .weld_speed{.min = 80., .max = 100.},
                        .bead_switch_angle = 15.,
                        .cap_corner_offset = 8.0,
                        .cap_beads         = 5,
                        .cap_init_depth    = 6.0},
        .welding_parameters{
                        .weld_object_diameter_m       = 2.,
                        .weld_object_speed_cm_per_min = 100.,
                        .stickout_m                   = 25e-3,
                        .weld_system_1{.voltage                      = 29.0,
                           .current                      = 700.0,
                           .wire_lin_velocity_mm_per_sec = help_sim::CalculateWireSpeedMmPerSec(method::DC, 4, 700),
                           .deposition_rate              = 10.4,
                           .heat_input                   = 1.2,
                           .twin_wire                    = false,
                           .wire_diameter_mm             = 4.0},
                        .weld_system_2{.voltage                      = 31.0,
                           .current                      = 700.0,
                           .wire_lin_velocity_mm_per_sec = help_sim::CalculateWireSpeedMmPerSec(method::AC, 4, 700),
                           .deposition_rate              = 10.6,
                           .heat_input                   = 1.2,
                           .twin_wire                    = false,
                           .wire_diameter_mm             = 4.0},
                        .use_edge_sensor = true},
        .test_joint_geometry{help_sim::TEST_JOINT_GEOMETRY_SHALLOW}
    };

    const std::chrono::milliseconds time_per_step_ms{static_cast<int>(help_sim::CalculateStepTimeMs(
        test_parameters.welding_parameters.weld_object_diameter_m,
        test_parameters.welding_parameters.weld_object_speed_cm_per_min, NUMBER_OF_STEPS_PER_REV))};

    common::msg::weld_system::GetWeldSystemDataRsp ws1_rsp{
        .voltage = static_cast<float>(test_parameters.welding_parameters.weld_system_1.voltage),
        .current = static_cast<float>(test_parameters.welding_parameters.weld_system_1.current),
        .wire_lin_velocity =
            static_cast<float>(test_parameters.welding_parameters.weld_system_1.wire_lin_velocity_mm_per_sec),
        .deposition_rate = static_cast<float>(test_parameters.welding_parameters.weld_system_1.deposition_rate),
        .heat_input      = static_cast<float>(test_parameters.welding_parameters.weld_system_1.heat_input),
        .twin_wire       = test_parameters.welding_parameters.weld_system_1.twin_wire,
        .wire_diameter   = static_cast<float>(test_parameters.welding_parameters.weld_system_1.wire_diameter_mm),
    };
    common::msg::weld_system::GetWeldSystemDataRsp ws2_rsp{
        .voltage = static_cast<float>(test_parameters.welding_parameters.weld_system_2.voltage),
        .current = static_cast<float>(test_parameters.welding_parameters.weld_system_2.current),
        .wire_lin_velocity =
            static_cast<float>(test_parameters.welding_parameters.weld_system_2.wire_lin_velocity_mm_per_sec),
        .deposition_rate = static_cast<float>(test_parameters.welding_parameters.weld_system_2.deposition_rate),
        .heat_input      = static_cast<float>(test_parameters.welding_parameters.weld_system_2.heat_input),
        .twin_wire       = test_parameters.welding_parameters.weld_system_2.twin_wire,
        .wire_diameter   = static_cast<float>(test_parameters.welding_parameters.weld_system_2.wire_diameter_mm),
    };

    TestFixture fixture;
    help_sim::ConfigureBlockTestWeldControl(fixture, test_parameters.welding_parameters.weld_object_diameter_m,
                                            NUMBER_OF_STEPS_PER_REV);
    fixture.StartApplication();
    StoreSettings(fixture, TestSettings{.use_edge_sensor = test_parameters.welding_parameters.use_edge_sensor}, true);
    fixture.SetupTimerWrapper();

    auto ws1_wfs = help_sim::CalculateWireSpeedMmPerSec(method::DC, 4., ws1_rsp.current);
    auto ws2_wfs = help_sim::CalculateWireSpeedMmPerSec(method::AC, 4., ws2_rsp.current);

    auto simulator  = depsim::CreateSimulator();
    auto sim_config = simulator->CreateSimConfig();
    help_sim::SetSimulatorDefault(sim_config, NUMBER_OF_STEPS_PER_REV);
    help_sim::SetJointGeometry(fixture, sim_config, test_parameters.test_joint_geometry);
    sim_config.travel_speed =
        help_sim::ConvertCMPerMin2MPerS(test_parameters.welding_parameters.weld_object_speed_cm_per_min);
    sim_config.target_stickout = test_parameters.welding_parameters.stickout_m;

    auto ws1_torch = simulator->AddSingleWireTorch(help_sim::ConvertMm2M(4.), help_sim::ConvertMmPerS2MPerS(ws1_wfs));
    auto ws2_torch = simulator->AddSingleWireTorch(help_sim::ConvertMm2M(4.), help_sim::ConvertMmPerS2MPerS(ws2_wfs));

    help_sim::ConfigOPCS(sim_config, test_parameters.welding_parameters.weld_object_diameter_m,
                         test_parameters.welding_parameters.stickout_m);
    help_sim::ConfigLPCS(sim_config, test_parameters.welding_parameters.stickout_m, SCANNER_MOUNT_ANGLE);
    simulator->Initialize(sim_config);

    DispatchKinematicsStateChange(fixture, common::msg::kinematics::StateChange::State::HOMED);
    DispatchKinematicsEdgeStateChange(fixture, common::msg::kinematics::EdgeStateChange::State::AVAILABLE);
    auto sub_msg = web_hmi::CreateMessage("SubscribeReadyState", std::nullopt, nlohmann::json{});
    fixture.WebHmiIn()->DispatchMessage(std::move(sub_msg));
    auto ready_msg = ReceiveJsonByName(fixture, "ReadyState");
    CHECK_EQ(ready_msg.at("payload").at("state"), "tracking_ready");

    depsim::Point3d torch_pos(-30e-3, 0, -19e-3 + test_parameters.welding_parameters.stickout_m, depsim::MACS);
    simulator->UpdateTorchPosition(torch_pos);

    auto abws = helpers_simulator::ConvertFromOptionalAbwVector(simulator->GetAbwPoints(depsim::MACS));
    simulator->UpdateTorchPosition(torch_pos);

    help_sim::SetABPParameters(fixture, test_parameters);
    CheckAndDispatchGetWeldAxis(fixture, 0.0, 0.0, 0.0,
                                help_sim::ConvertM2Mm(sim_config.joint_def_left.outer_diameter) * std::numbers::pi);

    // Start JT then ABP
    TrackingStart(fixture, TRACKING_MODE_LEFT, 10.0F,
                  static_cast<float>(help_sim::ConvertM2Mm(test_parameters.welding_parameters.stickout_m)));
    REQUIRE_MESSAGE(fixture.Scanner()->Receive<common::msg::scanner::SetJointGeometry>(), "No SetJointGeometry msg");
    CheckWeldControlStatus(fixture, WeldControlStatus{.weld_control_mode = "jt"});

    StartABP(fixture);
    CheckWeldControlStatus(fixture, WeldControlStatus{.weld_control_mode = "abp"});
    DispatchWeldSystemStateChange(fixture, weld_system::WeldSystemId::ID1,
                                  common::msg::weld_system::OnWeldSystemStateChange::State::ARCING);
    DispatchWeldSystemStateChange(fixture, weld_system::WeldSystemId::ID2,
                                  common::msg::weld_system::OnWeldSystemStateChange::State::ARCING);

    // ----- Run first bead, record torch positions -----
    std::vector<TorchSample> samples;
    auto weld_speed = sim_config.travel_speed;
    double angle{.001};
    double lin_dist{.0};
    bool done   = false;
    int step_no = 0;

    while (!done) {
      abws = helpers_simulator::ConvertFromOptionalAbwVector(simulator->GetAbwPoints(depsim::MACS));
      helpers_simulator::DumpAbw(abws);

      for (int step = 0; step < NUMBER_OF_STEPS_PER_REV && !done; step++, step_no++) {
        abws = helpers_simulator::ConvertFromOptionalAbwVector(simulator->GetAbwPoints(depsim::LPCS));

        auto slice = help_sim::GetSliceData(
            abws, *simulator,
            static_cast<std::uint64_t>(fixture.GetClockNowFuncWrapper()->GetSystemClock().time_since_epoch().count()));
        fixture.Scanner()->Dispatch(slice);

        auto gsp = fixture.Kinematics()->Receive<common::msg::kinematics::GetSlidesPosition>();
        fixture.Kinematics()->Dispatch(
            common::msg::kinematics::GetSlidesPositionRsp{.client_id  = gsp->client_id,
                                                          .time_stamp = gsp->time_stamp,
                                                          .horizontal = help_sim::ConvertM2Mm(torch_pos.GetX()),
                                                          .vertical   = help_sim::ConvertM2Mm(torch_pos.GetZ())});

        auto gep = fixture.Kinematics()->Receive<common::msg::kinematics::GetEdgePosition>();
        fixture.Kinematics()->Dispatch(
            common::msg::kinematics::GetEdgePositionRsp{.client_id = gep->client_id, .position = 0.0});

        CheckAndDispatchGetWeldAxis(
            fixture, angle, lin_dist,
            help_sim::ConvertMPerS2RadPerS(weld_speed, sim_config.joint_def_left.outer_diameter / 2.),
            help_sim::ConvertM2Mm(sim_config.joint_def_left.outer_diameter) * std::numbers::pi);

        ws1_rsp.heat_input =
            static_cast<float>(help_sim::CalculateHeatInputValue(ws1_rsp.voltage, ws1_rsp.current, weld_speed));
        ws2_rsp.heat_input =
            static_cast<float>(help_sim::CalculateHeatInputValue(ws2_rsp.voltage, ws2_rsp.current, weld_speed));
        CheckAndDispatchWeldSystemDataRsp(fixture, weld_system::WeldSystemId::ID1, ws1_rsp);
        CheckAndDispatchWeldSystemDataRsp(fixture, weld_system::WeldSystemId::ID2, ws2_rsp);

        if (auto swa = fixture.Kinematics()->Receive<common::msg::kinematics::SetWeldAxisData>()) {
          weld_speed = help_sim::ConvertRadPerS2MPerS(swa->velocity, sim_config.joint_def_left.outer_diameter / 2.);
          simulator->UpdateTravelSpeed(weld_speed);
        }
        if (auto sws = fixture.WeldSystem()->Receive<common::msg::weld_system::SetWeldSystemSettings>()) {
          ws1_wfs = help_sim::CalculateWireSpeedMmPerSec(method::DC, 4., ws1_rsp.current);
          ws2_wfs = help_sim::CalculateWireSpeedMmPerSec(method::AC, 4., sws->current);
          ws1_torch->SetWireFeedSpeed(help_sim::ConvertMmPerS2MPerS(ws1_wfs));
          ws2_torch->SetWireFeedSpeed(help_sim::ConvertMmPerS2MPerS(ws2_wfs));
          ws1_rsp.wire_lin_velocity = static_cast<float>(ws1_wfs);
          ws2_rsp.wire_lin_velocity = static_cast<float>(ws2_wfs);
          ws2_rsp.current           = sws->current;
        }

        fixture.GetTimerWrapper()->DispatchAllExpired();

        if (OptionalReceiveJsonByName(fixture, "GracefulStop").has_value()) {
          done = true;
          break;
        }

        auto ssp = fixture.Kinematics()->Receive<common::msg::kinematics::SetSlidesPosition>();
        REQUIRE_MESSAGE(ssp, "No SetSlidesPosition received");
        torch_pos = depsim::Point3d(help_sim::ConvertMm2M(ssp->horizontal), 0, help_sim::ConvertMm2M(ssp->vertical),
                                    depsim::MACS);
        simulator->UpdateTorchPosition(torch_pos);

        auto wcs = GetWeldControlStatus(fixture);
        samples.push_back({.step            = step_no,
                           .lin_distance_mm = lin_dist,
                           .horizontal_mm   = help_sim::ConvertM2Mm(torch_pos.GetX()),
                           .vertical_mm     = help_sim::ConvertM2Mm(torch_pos.GetZ()),
                           .bead_operation  = wcs.bead_operation.value_or("unknown")});

        // Stop once bead 1 is done (moved to bead 2 or repositioning after one full revolution)
        if (wcs.bead_number.value_or(0) >= 2 ||
            (wcs.bead_operation.value_or("") == "repositioning" && step_no > NUMBER_OF_STEPS_PER_REV)) {
          done = true;
          break;
        }

        angle     = std::fmod(angle + DELTA_ANGLE, 2. * std::numbers::pi);
        lin_dist += help_sim::ConvertM2Mm(sim_config.joint_def_left.outer_diameter / 2.) * DELTA_ANGLE;
        simulator->RunWithRotation(DELTA_ANGLE,
                                   test_parameters.test_joint_geometry.simulator_joint_geometry.bead_radians_m);
        fixture.GetClockNowFuncWrapper()->StepSystemClock(time_per_step_ms);
        fixture.GetClockNowFuncWrapper()->StepSteadyClock(time_per_step_ms);
      }
    }

    TESTLOG("Collected {} samples over {} steps", samples.size(), step_no);
    CheckOverlapDeviation(samples, test_parameters.welding_parameters.weld_object_diameter_m);
  }
}

// NOLINTEND(*-magic-numbers, *-optional-access)
