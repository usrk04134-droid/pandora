
// NOLINTBEGIN(*-magic-numbers, *-optional-access)

#include <doctest/doctest.h>

#include "controller/controller_data.h"
#include "helpers/helpers.h"
#include "helpers/helpers_web_hmi.h"
#include "web_hmi/web_hmi_json_helpers.h"

TEST_SUITE("Version") {
  TEST_CASE("GetPlcSwVersion") {
    MultiFixture mfx;

    // Set PLC version data
    controller::SystemVersions_PlcToAdaptio system_versions;
    system_versions.set_aws_major(1);
    system_versions.set_aws_minor(2);
    system_versions.set_aws_patch(3);
    mfx.Ctrl().Sut()->OnSystemVersionsInputUpdate(system_versions);
    mfx.PlcDataUpdate();

    // Request version via WebHMI
    auto get_version_msg = web_hmi::CreateMessage("GetPlcSwVersion", std::nullopt, nlohmann::json{});
    mfx.Main().WebHmiIn()->DispatchMessage(std::move(get_version_msg));

    // Receive response
    auto response = ReceiveJsonByName(mfx.Main(), "GetPlcSwVersionRsp");
    CHECK(response != nullptr);
    CHECK_EQ(response.at("result"), "ok");
    CHECK_EQ(response.at("payload").at("major"), 1);
    CHECK_EQ(response.at("payload").at("minor"), 2);
    CHECK_EQ(response.at("payload").at("patch"), 3);
  }
}

// NOLINTEND(*-magic-numbers, *-optional-access)
