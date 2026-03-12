#include "abw_simulation_impl.h"

#include <cmath>
#include <nlohmann/json.hpp>
#include <optional>
#include <string>
#include <tuple>
#include <utility>
#include <vector>

#include "abw_simulation_json_helpers.h"
#include "common/deposition_simulator/point3d.h"
#include "common/deposition_simulator/simulator_interface.h"
#include "common/logging/application_log.h"
#include "common/math/lin_interp.h"
#include "common/zevs/zevs_socket.h"
#include "lpcs/lpcs_point.h"
#include "lpcs/lpcs_slice.h"
#include "web_hmi/web_hmi.h"

namespace abw_simulation {
namespace {
const auto SUCCESS_PAYLOAD = nlohmann::json{
    {"result", "ok"}
};
const auto FAILURE_PAYLOAD = nlohmann::json{
    {"result", "fail"}
};

const double DEFAULT_WIRE_DIAMETER       = 4e-3;
const double DEFAULT_WIRE_FEED_SPEED     = 5.0 / 60.0;
const double DEFAULT_SLIDE_VELOCITY      = 3.667;
const double SCALE_MM_PER_M              = 1000.0;
const double INTERPOLATION_MARGIN_METERS = 20.0e-3;
const double DUPLICATE_EPSILON           = 1e-9;
const std::size_t BOTTOM_SIDE_POINTS     = 4;

// NOLINTNEXTLINE(bugprone-easily-swappable-parameters)
auto BuildInterpolatedProfile(const std::vector<deposition_simulator::Point3d>& full_profile_lpcs,
                              const std::vector<deposition_simulator::Point3d>& abw_points_lpcs,
                              std::size_t profile_array_size) -> std::vector<lpcs::Point> {
  std::vector<std::tuple<double, double>> segments;
  segments.reserve(full_profile_lpcs.size());

  std::optional<double> prev_x;
  for (std::size_t i = 0; i < full_profile_lpcs.size() - BOTTOM_SIDE_POINTS; ++i) {
    const auto& point    = full_profile_lpcs[i];
    const double x_coord = point.GetX();
    const double y_coord = point.GetY();

    if (!std::isfinite(x_coord) || !std::isfinite(y_coord) ||
        (prev_x && std::abs(x_coord - *prev_x) < DUPLICATE_EPSILON)) {
      continue;
    }

    segments.emplace_back(x_coord, y_coord);
    prev_x = x_coord;
  }

  const double start = abw_points_lpcs.front().GetX() - INTERPOLATION_MARGIN_METERS;
  const double stop  = abw_points_lpcs.back().GetX() + INTERPOLATION_MARGIN_METERS;

  auto xs = common::math::lin_interp::linspace(start, stop, profile_array_size);
  auto ys = common::math::lin_interp::lin_interp_2d(xs, segments);
  std::vector<lpcs::Point> profile;
  profile.reserve(profile_array_size);

  for (std::size_t i = 0; i < xs.size(); ++i) {
    profile.push_back({xs[i] * SCALE_MM_PER_M, ys[i] * SCALE_MM_PER_M});
  }

  return profile;
}
}  // namespace
AbwSimulation::AbwSimulation(zevs::Timer* timer, web_hmi::WebHmi* web_hmi,
                             kinematics::KinematicsClient* kinematics_client,
                             std::function<void(lpcs::Slice)> on_slice_data, std::size_t profile_array_size,
                             std::size_t groove_array_size)
    : timer_(timer),
      web_hmi_(web_hmi),
      kinematics_client_(kinematics_client),
      on_slice_data_(std::move(on_slice_data)),
      profile_array_size_(profile_array_size),
      groove_array_size_(groove_array_size) {
  simulator_ = deposition_simulator::CreateSimulator();
  SubscribeWebHmi();
  LOG_INFO("AbwSimulation subscribed");
}

void AbwSimulation::SubscribeWebHmi() {
  web_hmi_->Subscribe("AbwSimConfigSet", [this](std::string const&, const nlohmann::json& payload) -> void {
    this->OnAbwSimConfigSet(payload);
  });
  web_hmi_->Subscribe("AbwSimConfigGet", [this](std::string const&, const nlohmann::json& payload) -> void {
    this->OnAbwSimConfigGet(payload);
  });
  web_hmi_->Subscribe("AbwSimStart", [this](std::string const&, const nlohmann::json& payload) -> void {
    this->OnAbwSimStart(payload);
  });
  web_hmi_->Subscribe(
      "AbwSimStop", [this](std::string const&, const nlohmann::json& payload) -> void { this->OnAbwSimStop(payload); });
  web_hmi_->Subscribe("AbwSimTorchPosGet", [this](std::string const&, const nlohmann::json& payload) -> void {
    this->OnAbwSimTorchPosGet(payload);
  });
  web_hmi_->Subscribe("AbwSimTorchPosInit", [this](std::string const&, const nlohmann::json& payload) -> void {
    this->OnAbwSimTorchPosInit(payload);
  });
  web_hmi_->Subscribe("AbwSimTorchPosSet", [this](std::string const&, const nlohmann::json& payload) -> void {
    this->OnAbwSimTorchPosSet(payload);
  });

  LOG_INFO("AbwSimulation WebHMI handlers registered");
}

void AbwSimulation::OnAbwSimConfigSet(const nlohmann::json& payload) {
  auto config = AbwSimConfigFromJson(payload);
  if (!config.has_value()) {
    LOG_ERROR("AbwSimConfigSet: Failed to parse configuration from payload");
    web_hmi_->Send("AbwSimConfigSetRsp", FAILURE_PAYLOAD, "Invalid configuration", std::nullopt);
    return;
  }

  try {
    simulator_->Initialize(config.value());
  } catch (const std::exception& ex) {
    LOG_ERROR("AbwSimConfigSet: Initialize failed - {}", ex.what());
    web_hmi_->Send("AbwSimConfigSetRsp", FAILURE_PAYLOAD, std::make_optional(ex.what()), std::nullopt);
    return;
  }

  if (!torch_added_) {
    simulator_->AddSingleWireTorch(DEFAULT_WIRE_DIAMETER, DEFAULT_WIRE_FEED_SPEED);
    torch_added_ = true;
  }

  sim_config_ = std::move(config);

  LOG_INFO("AbwSimConfigSet: Configuration applied - nbrAbwPoints={}, targetStickout={}, travelSpeed={}",
           sim_config_->nbr_abw_points, sim_config_->target_stickout, sim_config_->travel_speed);

  web_hmi_->Send("AbwSimConfigSetRsp", SUCCESS_PAYLOAD, std::nullopt);
}

void AbwSimulation::OnAbwSimConfigGet(const nlohmann::json& /*payload*/) {
  LOG_DEBUG("AbwSimConfigGet received");

  if (!sim_config_.has_value()) {
    LOG_DEBUG("AbwSimConfigGet: No configuration available");
    web_hmi_->Send("AbwSimConfigGetRsp", FAILURE_PAYLOAD, "No configuration available", std::nullopt);
    return;
  }

  auto config_json = AbwSimConfigToJson(sim_config_.value());
  web_hmi_->Send("AbwSimConfigGetRsp", SUCCESS_PAYLOAD, config_json);
}

void AbwSimulation::OnAbwSimStart(const nlohmann::json& payload) {
  if (!sim_config_.has_value()) {
    web_hmi_->Send("AbwSimStartRsp", FAILURE_PAYLOAD, "Sim config not set", std::nullopt);
    return;
  }

  if (timer_task_id_.has_value()) {
    LOG_ERROR("AbwSimStart: Simulation already running");
    web_hmi_->Send("AbwSimStartRsp", FAILURE_PAYLOAD, "Simulation already running", std::nullopt);
    return;
  }
  auto timeout_ms = AbwSimStartFromJson(payload);
  if (!timeout_ms.has_value()) {
    LOG_ERROR("AbwSimStart: Failed to parse timeout from payload");
    web_hmi_->Send("AbwSimStartRsp", FAILURE_PAYLOAD, "Invalid timeout", std::nullopt);
    return;
  }

  timer_task_id_ = timer_->RequestPeriodic(&AbwSimulation::OnTimeout, this, timeout_ms.value(), "AbwSimTimeout");

  LOG_INFO("AbwSimStart: Started periodic timer with {}ms interval", timeout_ms.value());
  web_hmi_->Send("AbwSimStartRsp", SUCCESS_PAYLOAD, std::nullopt);
}

void AbwSimulation::OnAbwSimStop(const nlohmann::json& /*payload*/) {
  LOG_INFO("AbwSimStop received");

  if (timer_task_id_.has_value()) {
    timer_->Cancel(timer_task_id_.value());
    timer_task_id_.reset();
  }

  web_hmi_->Send("AbwSimStopRsp", SUCCESS_PAYLOAD, std::nullopt);
}

void AbwSimulation::OnAbwSimTorchPosInit(const nlohmann::json& /*payload*/) {
  std::vector<std::optional<deposition_simulator::Point3d>> abw_in_torch_plane;
  try {
    abw_in_torch_plane = simulator_->GetSliceInTorchPlane(deposition_simulator::MACS);
  } catch (const std::exception& ex) {
    LOG_ERROR("AbwSimTorchPosInit: Failed to get torch plane - {}", ex.what());
    web_hmi_->Send("AbwSimTorchPosInitRsp", FAILURE_PAYLOAD, std::make_optional(ex.what()), std::nullopt);
    return;
  }

  const auto& abw_front = abw_in_torch_plane.front().value();
  const auto& abw_back  = abw_in_torch_plane.back().value();
  const double torch_x  = (abw_front.GetX() + abw_back.GetX()) / 2.0;
  const double torch_z  = abw_front.GetZ();

  auto torch_pos_macs = deposition_simulator::Point3d(torch_x, 0.0, torch_z, deposition_simulator::MACS);
  try {
    simulator_->UpdateTorchPosition(torch_pos_macs);
  } catch (const std::exception& ex) {
    LOG_ERROR("AbwSimTorchPosInit: Failed to set torch position - {}", ex.what());
    web_hmi_->Send("AbwSimTorchPosInitRsp", FAILURE_PAYLOAD, std::make_optional(ex.what()), std::nullopt);
    return;
  }

  kinematics_client_->SetSlidesPosition(torch_pos_macs.GetX() * SCALE_MM_PER_M, torch_pos_macs.GetZ() * SCALE_MM_PER_M,
                                        DEFAULT_SLIDE_VELOCITY, DEFAULT_SLIDE_VELOCITY);

  LOG_INFO("AbwSimTorchPosInit: Position set to ({}, {}, {})", torch_pos_macs.GetX(), torch_pos_macs.GetY(),
           torch_pos_macs.GetZ());

  web_hmi_->Send("AbwSimTorchPosInitRsp", SUCCESS_PAYLOAD, std::nullopt);
}

void AbwSimulation::OnAbwSimTorchPosGet(const nlohmann::json& /*payload*/) {
  LOG_DEBUG("AbwSimTorchPosGet received");

  auto torch_pos = simulator_->GetTorchPosition(deposition_simulator::CoordinateSystem::MACS);
  auto pos_json  = AbwSimTorchPosToJson(torch_pos.GetX(), torch_pos.GetY(), torch_pos.GetZ());

  web_hmi_->Send("AbwSimTorchPosGetRsp", SUCCESS_PAYLOAD, pos_json);
}

void AbwSimulation::OnAbwSimTorchPosSet(const nlohmann::json& payload) {
  auto pos = AbwSimTorchPosFromJson(payload);
  if (!pos.has_value()) {
    LOG_ERROR("AbwSimTorchPosSet: Failed to parse position from payload");
    web_hmi_->Send("AbwSimTorchPosSetRsp", FAILURE_PAYLOAD, "Invalid position", std::nullopt);
    return;
  }

  auto [x_coord, y_coord, z_coord] = pos.value();
  auto torch_pos_mcs =
      deposition_simulator::Point3d(x_coord, y_coord, z_coord, deposition_simulator::CoordinateSystem::MACS);
  simulator_->UpdateTorchPosition(torch_pos_mcs);
  kinematics_client_->SetSlidesPosition(torch_pos_mcs.GetX() * SCALE_MM_PER_M, torch_pos_mcs.GetZ() * SCALE_MM_PER_M,
                                        DEFAULT_SLIDE_VELOCITY, DEFAULT_SLIDE_VELOCITY);

  LOG_DEBUG("AbwSimTorchPosSet: Position set to ({}, {}, {})", x_coord, y_coord, z_coord);
  web_hmi_->Send("AbwSimTorchPosSetRsp", SUCCESS_PAYLOAD, std::nullopt);
}

void AbwSimulation::OnTimeout() {
  // NOLINTNEXTLINE(bugprone-easily-swappable-parameters)
  kinematics_client_->GetSlidesPosition([this](std::uint64_t time_stamp, double horizontal, double vertical) -> void {
    const double horizontal_m = horizontal / SCALE_MM_PER_M;
    const double vertical_m   = vertical / SCALE_MM_PER_M;
    auto torch_pos_macs = deposition_simulator::Point3d(horizontal_m, 0.0, vertical_m, deposition_simulator::MACS);
    try {
      simulator_->UpdateTorchPosition(torch_pos_macs);
    } catch (const std::exception& ex) {
      LOG_ERROR("AbwSimulation: Failed to update torch position - {}", ex.what());
      return;
    }

    std::vector<std::optional<deposition_simulator::Point3d>> abw_points;
    std::vector<deposition_simulator::Point3d> observed_slice;
    try {
      abw_points     = simulator_->GetAbwPoints(deposition_simulator::CoordinateSystem::LPCS);
      observed_slice = simulator_->GetLatestObservedSlice(deposition_simulator::CoordinateSystem::LPCS);
    } catch (const std::exception& ex) {
      LOG_ERROR("AbwSimulation: Failed to fetch simulator data - {}", ex.what());
      return;
    }

    lpcs::Slice slice;
    slice.time_stamp = time_stamp;

    std::vector<deposition_simulator::Point3d> abw_points_lpcs;
    std::vector<lpcs::Point> groove_points;
    abw_points_lpcs.reserve(abw_points.size());
    groove_points.reserve(abw_points.size());

    for (const auto& point : abw_points) {
      if (point.has_value()) {
        abw_points_lpcs.push_back(point.value());
        groove_points.push_back(lpcs::Point{.x = point->GetX() * SCALE_MM_PER_M, .y = point->GetY() * SCALE_MM_PER_M});
      }
    }

    if (abw_points_lpcs.size() == groove_array_size_) {
      slice.groove     = groove_points;
      slice.profile    = BuildInterpolatedProfile(observed_slice, abw_points_lpcs, profile_array_size_);
      slice.confidence = lpcs::SliceConfidence::HIGH;
      LOG_DEBUG("AbwSimulation: Generated {} ABW points and {} profile points", groove_points.size(),
                slice.profile.size());
    } else {
      slice.confidence = lpcs::SliceConfidence::NO;
      LOG_DEBUG("AbwSimulation: Missing ABW points ({} of {})", abw_points_lpcs.size(), groove_array_size_);
    }

    on_slice_data_(std::move(slice));
  });
}

}  // namespace abw_simulation