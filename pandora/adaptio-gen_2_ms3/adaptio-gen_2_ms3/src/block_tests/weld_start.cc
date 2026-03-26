// NOLINTBEGIN(*-magic-numbers, *-optional-access)

#include <doctest/doctest.h>

#include "common/messages/weld_system.h"
#include "controller/controller_data.h"
#include "helpers/helpers.h"
#include "helpers/helpers_weld_data_set.h"
#include "helpers/helpers_weld_parameters.h"
#include "helpers/helpers_weld_process_parameters.h"
#include "helpers/helpers_weld_system.h"
#include "weld_system_client/weld_system_types.h"

TEST_SUITE("WeldStart") {
  TEST_CASE("manual_weld_start") {
    MultiFixture mfx;

    using weld_parameters_test_data::WPP_DEFAULT_WS1;
    using weld_parameters_test_data::WPP_DEFAULT_WS2;

    AddWeldProcessParameters(mfx.Main(), WPP_DEFAULT_WS1, true);
    AddWeldProcessParameters(mfx.Main(), WPP_DEFAULT_WS2, true);

    CHECK(AddWeldDataSet(mfx.Main(), "ManualWeld", 1, 2, true));

    CHECK(SelectWeldDataSet(mfx.Main(), 1, true));

    // Bring both power sources to READY_TO_START so ManualWeld enters READY state
    DispatchWeldSystemStateChange(mfx.Main(), weld_system::WeldSystemId::ID1,
                                  common::msg::weld_system::OnWeldSystemStateChange::State::READY_TO_START);
    DispatchWeldSystemStateChange(mfx.Main(), weld_system::WeldSystemId::ID2,
                                  common::msg::weld_system::OnWeldSystemStateChange::State::READY_TO_START);
    mfx.PlcDataUpdate();

    // Start button pressed
    controller::SystemControl_PlcToAdaptio system_control_input;
    system_control_input.set_commands_start_request(true);
    mfx.Ctrl().Sut()->OnSystemControlInputUpdate(system_control_input);
    mfx.PlcDataUpdate();

    // Verify voltage and current on PLC interface
    // Weld system 1
    CHECK_EQ(mfx.Ctrl().Mock()->power_source_1_output.get_voltage(), 25.0f);
    CHECK_EQ(mfx.Ctrl().Mock()->power_source_1_output.get_current(), 200u);

    // Weld system 2
    CHECK_EQ(mfx.Ctrl().Mock()->power_source_2_output.get_voltage(), 28.0f);
    CHECK_EQ(mfx.Ctrl().Mock()->power_source_2_output.get_current(), 180u);

    // Start to PLC
    CHECK(mfx.Ctrl().Mock()->weld_control_output.get_commands_start());
  }
}

// NOLINTEND(*-magic-numbers, *-optional-access)
