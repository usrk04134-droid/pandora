#include "stored_lw_cal_result.h"

#include <common/types/vector_3d_helpers.h>
#include <fmt/core.h>
#include <SQLiteCpp/Statement.h>
#include <SQLiteCpp/VariadicBind.h>

#include <cmath>
#include <exception>
#include <functional>
#include <nlohmann/json.hpp>
#include <optional>
#include <string>

#include "calibration_solver.h"
#include "common/logging/application_log.h"
#include "common/types/vector_3d.h"

namespace calibration {

const std::string LW_CAL_RESULT_TABLE_NAME = "lw_cal_result";

auto StoredLWCalResult::TorchToLpcsTranslation() const -> common::Vector3D { return torch_to_lpcs_translation_; }
auto StoredLWCalResult::DistanceLaserTorch() const -> double { return distance_laser_torch_; }
auto StoredLWCalResult::Stickout() const -> double { return stickout_; }
auto StoredLWCalResult::ScannerMountAngle() const -> double { return scanner_mount_angle_; }
auto StoredLWCalResult::WireDiameter() const -> double { return wire_diameter_; }

void StoredLWCalResult::SetTorchToLpcsTranslation(const common::Vector3D& value) { torch_to_lpcs_translation_ = value; }
void StoredLWCalResult::SetDistanceLaserTorch(double value) { distance_laser_torch_ = value; }
void StoredLWCalResult::SetStickout(double value) { stickout_ = value; }
void StoredLWCalResult::SetScannerMountAngle(double value) { scanner_mount_angle_ = value; }
void StoredLWCalResult::SetWireDiameter(double value) { wire_diameter_ = value; }

auto StoredLWCalResult::ToString() const -> std::string {
  return fmt::format(
      "torch_to_lpcs_translation: ({:.2f}, {:.2f}, {:.2f}), distance_laser_torch: {:.2f}, stickout: {:.2f}, "
      "scanner_mount_angle: {:.2f}, wire_diameter: {:.2f}",
      torch_to_lpcs_translation_.c1, torch_to_lpcs_translation_.c2, torch_to_lpcs_translation_.c3,
      distance_laser_torch_, stickout_, scanner_mount_angle_, wire_diameter_);
}

auto StoredLWCalResult::ToJson() const -> nlohmann::json {
  return {
      {"torchToLpcsTranslation",
       {{"c1", torch_to_lpcs_translation_.c1},
        {"c2", torch_to_lpcs_translation_.c2},
        {"c3", torch_to_lpcs_translation_.c3}}        },
      {"distanceLaserTorch",     distance_laser_torch_},
      {"stickout",               stickout_            },
      {"scannerMountAngle",      scanner_mount_angle_ },
      {"wireDiameter",           wire_diameter_       },
  };
}

auto StoredLWCalResult::FromLWCalibrationResult(const LWCalibrationResult& data, double distance_laser_torch,
                                                double stickout, double scanner_mount_angle, double wire_diameter)
    -> StoredLWCalResult {
  StoredLWCalResult result;
  result.SetTorchToLpcsTranslation(data.torch_to_lpcs_translation);
  result.SetDistanceLaserTorch(distance_laser_torch);
  result.SetStickout(stickout);
  result.SetScannerMountAngle(scanner_mount_angle);
  result.SetWireDiameter(wire_diameter);
  return result;
}

auto StoredLWCalResult::FromJson(const nlohmann::json& json_obj) -> std::optional<StoredLWCalResult> {
  StoredLWCalResult result;

  try {
    auto torch_to_lpcs                   = json_obj.at("torchToLpcsTranslation");
    result.torch_to_lpcs_translation_.c1 = torch_to_lpcs.at("c1").get<double>();
    result.torch_to_lpcs_translation_.c2 = torch_to_lpcs.at("c2").get<double>();
    result.torch_to_lpcs_translation_.c3 = torch_to_lpcs.at("c3").get<double>();

    json_obj.at("distanceLaserTorch").get_to(result.distance_laser_torch_);
    json_obj.at("stickout").get_to(result.stickout_);
    json_obj.at("scannerMountAngle").get_to(result.scanner_mount_angle_);
    json_obj.at("wireDiameter").get_to(result.wire_diameter_);
  } catch (const nlohmann::json::exception& e) {
    LOG_ERROR("Failed to parse StoredLWCalResult from JSON - exception: {}", e.what());
    return std::nullopt;
  }

  return result;
}

auto StoredLWCalResult::IsValid() const -> bool {
  auto is_finite = [](const common::Vector3D& vec) {
    return std::isfinite(vec.c1) && std::isfinite(vec.c2) && std::isfinite(vec.c3);
  };

  auto ok  = true;
  ok      &= is_finite(torch_to_lpcs_translation_);
  ok      &= distance_laser_torch_ > 0.0;
  ok      &= stickout_ > 0.0;
  ok      &= scanner_mount_angle_ >= 0.0;
  ok      &= wire_diameter_ > 0.0;

  return ok;
}

void StoredLWCalResult::CreateTable(SQLite::Database* db) {
  if (db->tableExists(LW_CAL_RESULT_TABLE_NAME)) {
    return;
  }

  std::string cmd = fmt::format(
      "CREATE TABLE {} ("
      "id INTEGER PRIMARY KEY, "
      "data TEXT)",
      LW_CAL_RESULT_TABLE_NAME);

  db->exec(cmd);
}

auto StoredLWCalResult::StoreFn() -> std::function<bool(SQLite::Database*, const StoredLWCalResult&)> {
  return [](SQLite::Database* db, const StoredLWCalResult& result) -> bool {
    LOG_TRACE("Store StoredLWCalResult {}", result.ToString());

    try {
      std::string cmd = fmt::format("INSERT OR REPLACE INTO {} VALUES (1, ?)", LW_CAL_RESULT_TABLE_NAME);

      SQLite::Statement query(*db, cmd);
      SQLite::bind(query, result.ToJson().dump());

      return query.exec() == 1;
    } catch (const std::exception& e) {
      LOG_ERROR("Failed to store StoredLWCalResult - exception: {}", e.what());
      return false;
    }
  };
}

auto StoredLWCalResult::GetFn() -> std::function<std::optional<StoredLWCalResult>(SQLite::Database*)> {
  return [](SQLite::Database* db) -> std::optional<StoredLWCalResult> {
    std::string cmd = fmt::format("SELECT data FROM {}", LW_CAL_RESULT_TABLE_NAME);
    SQLite::Statement query(*db, cmd);

    if (!query.executeStep()) {
      return std::nullopt;
    }

    try {
      auto json_str = query.getColumn(0).getString();
      auto json_obj = nlohmann::json::parse(json_str);
      return FromJson(json_obj);
    } catch (const nlohmann::json::exception& e) {
      LOG_ERROR("Failed to parse StoredLWCalResult from database JSON - exception: {}", e.what());
      return std::nullopt;
    } catch (const std::exception& e) {
      LOG_ERROR("Failed to read StoredLWCalResult from database - exception: {}", e.what());
      return std::nullopt;
    }
  };
}

auto StoredLWCalResult::ClearFn() -> std::function<bool(SQLite::Database*)> {
  return [](SQLite::Database* db) -> bool {
    try {
      std::string cmd = fmt::format("DELETE FROM {}", LW_CAL_RESULT_TABLE_NAME);
      auto result     = db->exec(cmd) >= 0;
      return result;
    } catch (const std::exception& e) {
      LOG_ERROR("Failed to clear StoredLWCalResult - exception: {}", e.what());
      return false;
    }
  };
}

}  // namespace calibration
