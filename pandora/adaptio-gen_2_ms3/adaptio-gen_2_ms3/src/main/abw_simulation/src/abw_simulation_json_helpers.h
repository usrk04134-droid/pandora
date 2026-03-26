#pragma once

#include <nlohmann/json.hpp>
#include <optional>
#include <tuple>

#include "common/deposition_simulator/sim-config.h"

namespace abw_simulation {

auto AbwSimConfigToJson(const deposition_simulator::SimConfig& config) -> nlohmann::json;
auto AbwSimConfigFromJson(const nlohmann::json& payload) -> std::optional<deposition_simulator::SimConfig>;

auto AbwSimStartFromJson(const nlohmann::json& payload) -> std::optional<uint32_t>;

auto AbwSimTorchPosToJson(double torch_x, double torch_y, double torch_z) -> nlohmann::json;
auto AbwSimTorchPosFromJson(const nlohmann::json& payload) -> std::optional<std::tuple<double, double, double>>;

}  // namespace abw_simulation
