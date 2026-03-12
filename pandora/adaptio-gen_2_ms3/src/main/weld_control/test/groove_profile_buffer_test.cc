#include "weld_control/src/groove_profile_buffer.h"

#include <doctest/doctest.h>

#include <cstddef>

// NOLINTBEGIN(*-magic-numbers)
namespace weld_control {

TEST_SUITE("GrooveProfileBuffer") {
  TEST_CASE("JsonRoundtrip") {
    GrooveProfileData original{
        .profile = {
                    {.horizontal = -0.022, .vertical = 0.025},
                    {.horizontal = -0.015, .vertical = -0.025},
                    {.horizontal = 0.000, .vertical = -0.030},
                    {.horizontal = 0.015, .vertical = -0.025},
                    {.horizontal = 0.022, .vertical = 0.025},
                    }
    };

    auto json              = original.ToJson();
    auto restored_data_opt = GrooveProfileData::FromJson(json);

    REQUIRE(restored_data_opt.has_value());
    auto restored = restored_data_opt.value();

    REQUIRE(original.profile.size() == restored.profile.size());

    for (size_t i = 0; i < original.profile.size(); ++i) {
      REQUIRE(original.profile[i].horizontal == doctest::Approx(restored.profile[i].horizontal));
      REQUIRE(original.profile[i].vertical == doctest::Approx(restored.profile[i].vertical));
    }
  }
}

}  // namespace weld_control
// NOLINTEND(*-magic-numbers)