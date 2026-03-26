#include "../axis_output_plc_adapter.h"

#include <doctest/doctest.h>

#include <functional>
#include <optional>

#include "controller/controller_data.h"

using controller::AxisOutputPlcAdapter;
using controller::WeldHeadManipulator_AdaptioToPlc;

// NOLINTBEGIN(*-magic-numbers, *-optional-access)

TEST_SUITE("AxisOutputPlcAdapter_tests") {
  TEST_CASE("new_output") {
    // Setup testcase
    std::optional<WeldHeadManipulator_AdaptioToPlc> current_output;
    auto callback = [&current_output](WeldHeadManipulator_AdaptioToPlc data) { current_output = data; };
    auto sut      = AxisOutputPlcAdapter{callback};

    // A cycle timeout with no data, there should be no callback
    sut.OnPlcCycleWrite();
    CHECK_FALSE(current_output);

    // Data is passed and a cycle timeout
    WeldHeadManipulator_AdaptioToPlc data{};
    data.set_commands_enable_motion(true);
    sut.OnWeldHeadManipulatorOutput(data);
    sut.OnPlcCycleWrite();
    CHECK_EQ(current_output.value().get_commands_enable_motion(), true);

    // Release and set new data
    // the release should take effect the next cycle
    // and the new data in the cycle after the next
    sut.Release();
    data = {};
    data.set_commands_enable_motion(true);
    sut.OnWeldHeadManipulatorOutput(data);
    sut.OnPlcCycleWrite();
    CHECK_EQ(current_output.value().get_commands_enable_motion(), false);
    sut.OnPlcCycleWrite();
    CHECK_EQ(current_output.value().get_commands_enable_motion(), true);

    // Reset the output, there should be no update with no new data
    current_output = {};
    sut.OnPlcCycleWrite();
    CHECK_FALSE(current_output);

    // Set nonzero positions then run a cycle.
    // Then release and check that positions are the same
    // when writing stop
    WeldHeadManipulator_AdaptioToPlc test_data{};
    test_data.set_commands_enable_motion(true);
    test_data.set_x_position(100.0);
    test_data.set_y_position(200.0);
    sut.OnWeldHeadManipulatorOutput(test_data);

    sut.OnPlcCycleWrite();
    CHECK_EQ(current_output.value().get_x_position(), 100.0);
    CHECK_EQ(current_output.value().get_y_position(), 200.0);

    sut.Release();
    sut.OnPlcCycleWrite();

    CHECK_EQ(current_output.value().get_commands_enable_motion(), false);
    CHECK_EQ(current_output.value().get_x_position(), 100.0);
    CHECK_EQ(current_output.value().get_y_position(), 200.0);
  }
}
// NOLINTEND(*-magic-numbers, *-optional-access)
