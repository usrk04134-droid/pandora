#include "helpers/helpers.h"
#include "helpers/helpers_joint_geometry.h"
#include "helpers/helpers_kinematics.h"
#include "helpers/helpers_mfx.h"
#include "helpers/helpers_settings.h"
#include "helpers/helpers_weld_control.h"
#include "helpers/helpers_weld_system.h"

// NOLINTBEGIN(*-magic-numbers)

#include <doctest/doctest.h>

#include <filesystem>

TEST_SUITE("ManualWeldingLog") {
  TEST_CASE("idle_arcing_with_scanner_data_produces_weldcontrol_log") {
    MultiFixture mfx;
    mfx.SetupScanner("40297730");

    StoreSettings(mfx.Main(), TestSettings{.use_edge_sensor = false}, true);
    StoreDefaultJointGeometryParams(mfx.Main());

    REQUIRE(mfx.Scan().Scanner() != nullptr);

    mfx.Scan().SetJointGeometry(joint_geometry::JointGeometry{
        .upper_joint_width_mm        = 57.58,
        .groove_depth_mm             = 19.6,
        .left_joint_angle_rad        = 0.5236,
        .right_joint_angle_rad       = 0.5236,
        .left_max_surface_angle_rad  = 0.3491,
        .right_max_surface_angle_rad = 0.3491,
    });

    controller::WeldAxis_PlcToAdaptio axis_data;
    axis_data.set_status_reference_valid(true);
    mfx.Ctrl().Sut()->OnWeldAxisInputUpdate(axis_data);

    mfx.PlcDataUpdate();

    // Set weld system 1 to ARCING while staying in IDLE mode (manual welding)
    DispatchWeldSystemStateChange(mfx.Main(), weld_system::WeldSystemId::ID1,
                                  common::msg::weld_system::OnWeldSystemStateChange::State::ARCING);

    // Verify we are in IDLE mode
    CheckWeldControlStatus(mfx.Main(), WeldControlStatus{.weld_control_mode = "idle"});

    // Step system clock past LOG_RATE_LIMIT so the first LogData() call fires
    mfx.Main().GetClockNowFuncWrapper()->StepSystemClock(std::chrono::milliseconds(2000));

    // Snapshot weldcontrol log directory before feeding scanner data
    std::filesystem::path const log_dir = "/var/log/adaptio/weldcontrol";
    int files_before                    = 0;
    std::uintmax_t size_before          = 0;
    if (std::filesystem::exists(log_dir)) {
      for (auto const& entry : std::filesystem::directory_iterator(log_dir)) {
        ++files_before;
        size_before += entry.file_size();
      }
    }

    // Flat line image — scanner won't find groove, but should still send raw profile
    mfx.Scan().RepeatToFillMedianBuffer("line.tiff");
    mfx.Scan().TriggerScannerData();

    // Advance the system clock past the log rate limit and trigger again
    mfx.Main().GetClockNowFuncWrapper()->StepSystemClock(std::chrono::milliseconds(1000));
    mfx.Scan().TriggerScannerData();

    // Check weldcontrol log directory for new or grown files
    int files_after           = 0;
    std::uintmax_t size_after = 0;
    if (std::filesystem::exists(log_dir)) {
      for (auto const& entry : std::filesystem::directory_iterator(log_dir)) {
        ++files_after;
        size_after += entry.file_size();
      }
    }

    bool const log_grew = (size_after > size_before) || (files_after > files_before);
    CHECK_MESSAGE(log_grew, "Expected weldcontrol log to contain new entries after IDLE+arcing with scanner data");
  }
}

// NOLINTEND(*-magic-numbers)
