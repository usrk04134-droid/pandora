
// NOLINTBEGIN(*-magic-numbers, *-optional-access)

#include <doctest/doctest.h>

#include "controller/controller_data.h"
#include "helpers/helpers.h"

TEST_SUITE("Shutdown") {
  TEST_CASE("basic") {
    MultiFixture mfx;

    controller::SystemControl_PlcToAdaptio system_control_input;
    system_control_input.set_commands_shutdown_request(true);
    mfx.Ctrl().Sut()->OnSystemControlInputUpdate(system_control_input);
    mfx.PlcDataUpdate();

    CHECK(mfx.Main().Sut()->InShutdown());
  }
}

// NOLINTEND(*-magic-numbers, *-optional-access)
