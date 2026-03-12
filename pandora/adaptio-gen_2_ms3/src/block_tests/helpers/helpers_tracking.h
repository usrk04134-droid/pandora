#pragma once

#include <doctest/doctest.h>

#include "helpers.h"
#include "web_hmi/web_hmi_json_helpers.h"

// NOLINTBEGIN(*-magic-numbers)

const std::string TRACKING_MODE_LEFT = "left";

inline auto TrackingStart(TestFixture& fixture, std::string const& joint_tracking_mode, float horizontal_offset,
                          float vertical_offset) -> void {
  auto const payload = nlohmann::json({
      {"joint_tracking_mode", joint_tracking_mode},
      {"horizontal_offset",   horizontal_offset  },
      {"vertical_offset",     vertical_offset    }
  });

  auto msg = web_hmi::CreateMessage("TrackingStart", std::nullopt, payload);
  fixture.WebHmiIn()->DispatchMessage(std::move(msg));
}

// NOLINTEND(*-magic-numbers)
