#pragma once

#include <SQLiteCpp/Database.h>

#include <functional>
#include <nlohmann/json.hpp>
#include <optional>
#include <string>

#include "calibration_solver.h"
#include "common/types/vector_3d.h"

namespace calibration {

class StoredLWCalResult {
 public:
  auto TorchToLpcsTranslation() const -> common::Vector3D;
  auto DistanceLaserTorch() const -> double;
  auto Stickout() const -> double;
  auto ScannerMountAngle() const -> double;
  auto WireDiameter() const -> double;

  void SetTorchToLpcsTranslation(const common::Vector3D& value);
  void SetDistanceLaserTorch(double value);
  void SetStickout(double value);
  void SetScannerMountAngle(double value);
  void SetWireDiameter(double value);

  auto ToString() const -> std::string;
  auto ToJson() const -> nlohmann::json;
  static auto FromJson(const nlohmann::json& json_obj) -> std::optional<StoredLWCalResult>;
  static auto FromLWCalibrationResult(const LWCalibrationResult& data, double distance_laser_torch, double stickout,
                                      double scanner_mount_angle, double wire_diameter) -> StoredLWCalResult;

  static void CreateTable(SQLite::Database* db);
  static auto StoreFn() -> std::function<bool(SQLite::Database*, const StoredLWCalResult&)>;
  static auto GetFn() -> std::function<std::optional<StoredLWCalResult>(SQLite::Database*)>;
  static auto ClearFn() -> std::function<bool(SQLite::Database*)>;

  auto IsValid() const -> bool;

 private:
  common::Vector3D torch_to_lpcs_translation_{};
  double distance_laser_torch_{};
  double stickout_{};
  double scanner_mount_angle_{};
  double wire_diameter_{};
};

}  // namespace calibration
