#include <doctest/doctest.h>

#include <nlohmann/json_fwd.hpp>
#include <string>

#include "helpers/helpers.h"
#include "helpers/helpers_weld_data_set.h"
#include "helpers/helpers_weld_process_parameters.h"
#include "helpers/helpers_weld_program.h"

// NOLINTBEGIN(*-magic-numbers, *-optional-access, hicpp-signed-bitwise)

static const bool EXPECT_OK   = true;
static const bool EXPECT_FAIL = false;

TEST_SUITE("WeldProgram") {
  TEST_CASE("store_and_get") {
    TestFixture fixture;
    fixture.StartApplication();
    SeedWeldProcessParameters(fixture, 2);
    CHECK(AddWeldDataSet(fixture, "wds1", 1, 2, EXPECT_OK));

    nlohmann::json layers = nlohmann::json::array();
    layers.push_back({
        {"layerNumber",   0},
        {"weldDataSetId", 1}
    });

    nlohmann::json const payload{
        {"name",     "program1"},
        {"grooveId", 1         },
        {"layers",   layers    }
    };
    CHECK(StoreWeldProgram(fixture, payload, EXPECT_OK));

    auto expected  = payload;
    expected["id"] = 1;  // added when stored to db
    CHECK(CheckWeldProgramsEqual(fixture, nlohmann::json::array({expected})));

    /* Store with invalid payload (missing required fields) should fail */
    nlohmann::json const invalid_payload{
        {"layers", layers}
    };
    CHECK(StoreWeldProgram(fixture, invalid_payload, EXPECT_FAIL));

    /* Check that the weld-program was not changed */
    CHECK(CheckWeldProgramsEqual(fixture, nlohmann::json::array({expected})));
  }

  TEST_CASE("store_duplicate_name") {
    TestFixture fixture;
    fixture.StartApplication();
    SeedWeldProcessParameters(fixture, 2);
    CHECK(AddWeldDataSet(fixture, "wds1", 1, 2, EXPECT_OK));

    nlohmann::json layers = nlohmann::json::array();
    layers.push_back({
        {"layerNumber",   0},
        {"weldDataSetId", 1}
    });

    nlohmann::json const payload{
        {"name",     "program1"},
        {"grooveId", 1         },
        {"layers",   layers    }
    };
    CHECK(StoreWeldProgram(fixture, payload, EXPECT_OK));
    CHECK(StoreWeldProgram(fixture, payload, EXPECT_FAIL));
  }

  TEST_CASE("update_weld_program") {
    TestFixture fixture;
    fixture.StartApplication();
    SeedWeldProcessParameters(fixture, 4);
    CHECK(AddWeldDataSet(fixture, "wds1", 1, 2, EXPECT_OK));
    CHECK(AddWeldDataSet(fixture, "wds2", 3, 4, EXPECT_OK));

    nlohmann::json layers1 = nlohmann::json::array();
    layers1.push_back({
        {"layerNumber",   0},
        {"weldDataSetId", 1}
    });

    nlohmann::json const payload1{
        {"name",     "program1"},
        {"grooveId", 1         },
        {"layers",   layers1   }
    };
    CHECK(StoreWeldProgram(fixture, payload1, EXPECT_OK));

    /* Update the program to use a different layer */
    nlohmann::json layers2 = nlohmann::json::array();
    layers2.push_back({
        {"layerNumber",   0},
        {"weldDataSetId", 1}
    });
    layers2.push_back({
        {"layerNumber",   1},
        {"weldDataSetId", 2}
    });

    nlohmann::json const update_payload{
        {"name",     "program1_updated"},
        {"grooveId", 2                 },
        {"layers",   layers2           }
    };
    CHECK(UpdateWeldProgram(fixture, 1, update_payload, EXPECT_OK));

    /* Verify the update */
    auto expected  = update_payload;
    expected["id"] = 1;
    CHECK(CheckWeldProgramsEqual(fixture, nlohmann::json::array({expected})));
  }

  TEST_CASE("remove_weld_program") {
    TestFixture fixture;
    fixture.StartApplication();
    SeedWeldProcessParameters(fixture, 2);
    CHECK(AddWeldDataSet(fixture, "wds1", 1, 2, EXPECT_OK));

    nlohmann::json layers = nlohmann::json::array();
    layers.push_back({
        {"layerNumber",   0},
        {"weldDataSetId", 1}
    });

    nlohmann::json const payload{
        {"name",     "program1"},
        {"grooveId", 1         },
        {"layers",   layers    }
    };
    CHECK(StoreWeldProgram(fixture, payload, EXPECT_OK));

    /* Remove it */
    CHECK(RemoveWeldProgram(fixture, 1, EXPECT_OK));

    /* Should be empty now */
    CHECK(CheckWeldProgramsEqual(fixture, nlohmann::json::array()));
  }

  TEST_CASE("store_with_nonexistent_wds") {
    TestFixture fixture;
    fixture.StartApplication();

    nlohmann::json layers = nlohmann::json::array();
    layers.push_back({
        {"layerNumber",   0 },
        {"weldDataSetId", 99}
    });

    nlohmann::json const payload{
        {"name",     "program1"},
        {"grooveId", 1         },
        {"layers",   layers    }
    };
    CHECK(StoreWeldProgram(fixture, payload, EXPECT_FAIL));
  }

  TEST_CASE("remove_nonexistent_weld_program") {
    TestFixture fixture;
    fixture.StartApplication();

    CHECK(RemoveWeldProgram(fixture, 99, EXPECT_FAIL));
  }

  TEST_CASE("weld_program_fetch_from_database") {
    /* The database will be populated when started the first time. The second time the application is started the data
     * will be read from the database */

    nlohmann::json layers = nlohmann::json::array();
    layers.push_back({
        {"layerNumber",   0},
        {"weldDataSetId", 1}
    });

    nlohmann::json const payload{
        {"name",     "program1"},
        {"grooveId", 1         },
        {"layers",   layers    }
    };

    TestFixture fixture;
    fixture.StartApplication();
    SeedWeldProcessParameters(fixture, 2);
    CHECK(AddWeldDataSet(fixture, "wds1", 1, 2, EXPECT_OK));
    CHECK(StoreWeldProgram(fixture, payload, EXPECT_OK));

    fixture.StartApplication();
    auto expected  = payload;
    expected["id"] = 1;  // added when stored to db
    CHECK(CheckWeldProgramsEqual(fixture, nlohmann::json::array({expected})));
  }
}
// NOLINTEND(*-magic-numbers, *-optional-access, hicpp-signed-bitwise)
