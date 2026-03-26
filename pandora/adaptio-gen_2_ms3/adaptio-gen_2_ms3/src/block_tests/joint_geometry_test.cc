#include <doctest/doctest.h>

#include "helpers/helpers.h"
#include "helpers/helpers_joint_geometry.h"

// NOLINTBEGIN(*-magic-numbers, *-optional-access, hicpp-signed-bitwise)

TEST_SUITE("JointGeometry") {
  TEST_CASE("set_joint_geometry_twice") {
    TestFixture fixture;
    fixture.StartApplication();

    auto const payload1 = nlohmann::json({
        {"upperJointWidthMm",       58.0  },
        {"grooveDepthMm",           40.0  },
        {"leftJointAngleRad",       0.5199},
        {"rightJointAngleRad",      0.5199},
        {"leftMaxSurfaceAngleRad",  0.3491},
        {"rightMaxSurfaceAngleRad", 0.3491},
        {"type",                    "cw"  },
    });
    StoreJointGeometryParams(fixture, payload1, true);

    auto const payload2 = nlohmann::json({
        {"upperJointWidthMm",       60.0  },
        {"grooveDepthMm",           35.0  },
        {"leftJointAngleRad",       0.6000},
        {"rightJointAngleRad",      0.6000},
        {"leftMaxSurfaceAngleRad",  0.4000},
        {"rightMaxSurfaceAngleRad", 0.4000},
        {"type",                    "cw"  },
    });
    StoreJointGeometryParams(fixture, payload2, true);

    CheckJointGeometryParamsEqual(fixture, payload2);
  }
}
// NOLINTEND(*-magic-numbers, *-optional-access, hicpp-signed-bitwise)
