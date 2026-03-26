#pragma once

#include <doctest/doctest.h>

#include <cstddef>

#include "helpers.h"
#include "helpers_json_compare.h"
#include "helpers_web_hmi.h"
#include "web_hmi/web_hmi_json_helpers.h"

// NOLINTBEGIN(*-magic-numbers, *-optional-access, hicpp-signed-bitwise)

inline const std::string WPP_ADD        = "AddWeldProcessParameters";
inline const std::string WPP_ADD_RSP    = "AddWeldProcessParametersRsp";
inline const std::string WPP_UPDATE     = "UpdateWeldProcessParameters";
inline const std::string WPP_UPDATE_RSP = "UpdateWeldProcessParametersRsp";
inline const std::string WPP_REMOVE     = "RemoveWeldProcessParameters";
inline const std::string WPP_REMOVE_RSP = "RemoveWeldProcessParametersRsp";
inline const std::string WPP_GET        = "GetWeldProcessParameters";
inline const std::string WPP_GET_RSP    = "GetWeldProcessParametersRsp";

inline auto AddWeldProcessParameters(TestFixture& fixture, nlohmann::json const& payload, bool expect_ok) {
  auto msg = web_hmi::CreateMessage(WPP_ADD, std::nullopt, payload);
  fixture.WebHmiIn()->DispatchMessage(std::move(msg));

  auto const response_payload = ReceiveJsonByName(fixture, WPP_ADD_RSP);
  CHECK(response_payload != nullptr);

  auto const expected = expect_ok
    ? nlohmann::json { { "result", "ok"} }
    : nlohmann::json { { "result", "fail"} };

  CHECK_EQ(response_payload.at("result"), expected.at("result"));
}

inline auto CheckWeldProcessParametersEqual(TestFixture& fixture, nlohmann::json const& expected) -> bool {
  auto msg = web_hmi::CreateMessage(WPP_GET, std::nullopt, {});
  fixture.WebHmiIn()->DispatchMessage(std::move(msg));

  auto const response_payload = ReceiveJsonByName(fixture, WPP_GET_RSP);
  CHECK(response_payload != nullptr);
  const auto& payload = response_payload.at("payload");

  return payload != nullptr && JsonEqualWithTolerance(payload, expected);
}

[[nodiscard]] inline auto UpdateWeldProcessParameters(TestFixture& fixture, int id, nlohmann::json const& payload,
                                                      bool expect_ok) -> bool {
  auto msg_payload  = payload;
  msg_payload["id"] = id;
  auto msg          = web_hmi::CreateMessage(WPP_UPDATE, std::nullopt, msg_payload);
  fixture.WebHmiIn()->DispatchMessage(std::move(msg));

  auto const response_payload = ReceiveJsonByName(fixture, WPP_UPDATE_RSP);
  CHECK(response_payload != nullptr);

  auto const expected = expect_ok
    ? nlohmann::json { { "result", "ok"} }
    : nlohmann::json { { "result", "fail"} };

  return response_payload.at("result") == expected.at("result");
}

[[nodiscard]] inline auto RemoveWeldProcessParameters(TestFixture& fixture, int id, bool expect_ok) -> bool {
  nlohmann::json const payload({
      {"id", id}
  });

  auto msg = web_hmi::CreateMessage(WPP_REMOVE, std::nullopt, payload);
  fixture.WebHmiIn()->DispatchMessage(std::move(msg));

  auto const response_payload = ReceiveJsonByName(fixture, WPP_REMOVE_RSP);
  CHECK(response_payload != nullptr);

  nlohmann::json const expected({
      {"result", expect_ok ? "ok" : "fail"}
  });

  return response_payload.at("result") == expected.at("result");
}

inline void SeedWeldProcessParameters(TestFixture& fixture, int count) {
  for (int i = 0; i < count; ++i) {
    nlohmann::json const wpp = {
        {"name",           "seed_wpp_" + std::to_string(i + 1)},
        {"method",         "dc"                               },
        {"regulationType", "cc"                               },
        {"startAdjust",    10                                 },
        {"startType",      "scratch"                          },
        {"voltage",        24.5                               },
        {"current",        150.0                              },
        {"wireSpeed",      12.5                               },
        {"iceWireSpeed",   0.0                                },
        {"acFrequency",    60.0                               },
        {"acOffset",       1.2                                },
        {"acPhaseShift",   0.5                                },
        {"craterFillTime", 2.0                                },
        {"burnBackTime",   1.0                                }
    };
    AddWeldProcessParameters(fixture, wpp, true);
  }
}

// NOLINTEND(*-magic-numbers, *-optional-access, hicpp-signed-bitwise)
