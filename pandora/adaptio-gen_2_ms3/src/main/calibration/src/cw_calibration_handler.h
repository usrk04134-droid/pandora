#pragma once

#include "calibration_grid_generator.h"
#include "calibration_handler.h"
#include "calibration_sequence_runner.h"
#include "calibration_solver.h"
#include "common/logging/component_logger.h"
#include "common/storage/sql_single_storage.h"
#include "joint_geometry/joint_geometry.h"
#include "slice_translator/rotary_model_config.h"
#include "stored_calibration_result.h"
#include "stored_laser_torch_configuration.h"

namespace slice_translator {
class ModelConfig;
}

namespace calibration {

class CWCalibrationHandler : public CalibrationHandler {
 public:
  CWCalibrationHandler(SQLite::Database* db, DependencyContext* dep_ctx, CalibrationSolver* calibration_solver,
                       slice_translator::RotaryModelConfig* cw_model_config, zevs::Timer* timer,
                       const GridConfiguration& grid_config, const RunnerConfiguration& runner_config,
                       std::function<void()> calibration_status_subscriber);

  // CalibrationHandler
  auto CanHandle(coordination::ActivityStatusE status) const -> bool override;
  auto IsBusy() const -> bool override;
  void OnScannerDataUpdate(const lpcs::Slice& data, const common::Point& axis_position) override;
  void OnGeometryApplied(bool success) override;
  void Cleanup() override;

  // WebHMI message handlers
  void OnLaserTorchCalGet();
  void OnLaserTorchCalSet(const nlohmann::json& payload);
  void OnWeldObjectCalGet();
  void OnWeldObjectCalSet(const nlohmann::json& payload);
  void OnWeldObjectCalStart(const nlohmann::json& payload);
  void OnWeldObjectCalStop();
  void OnWeldObjectCalTopPos();
  void OnWeldObjectCalLeftPos();
  void OnWeldObjectCalRightPos();

  void SubscribeWebHmi() override;
  void ApplyCalibration() override;
  auto HasValidCalibration() const -> bool override;

 private:
  struct CalibrationContext {
    common::Point top_center;
    StoredLaserTorchConfiguration laser_torch_config;
    double wire_diameter{};
    double stickout{};
    double weld_object_radius{};
    ::joint_geometry::JointGeometry joint_geometry;
    std::vector<Observation> observations;

    Observation top;
    Observation left;
    Observation right;

    auto TouchDepth() const -> double;
  } cal_ctx_;

  void SendCalibrationStartFailure(const std::string& reason);
  void LogCalibrationFailure(const std::string& reason);
  void HandleTopPosData(const common::Point& axis_position);
  void HandleLeftPosData(const lpcs::Slice& data, const common::Point& axis_position);
  void HandleRightPosData(const lpcs::Slice& data, const common::Point& axis_position);
  void OnTopPosProcedureComplete(const common::Point& axis_position);
  void HandleTopTouchFailure(const std::string& reason);
  void OnLeftPosProcedureComplete(const std::optional<Observation>& observation);
  void HandleLeftTouchFailure(const std::string& reason);
  void OnRightPosProcedureComplete(const std::optional<Observation>& observation);
  void HandleRightTouchFailure(const std::string& reason);
  auto CalculateTopCenter() -> std::optional<common::Point>;
  auto GenerateGridPoints() -> std::vector<GridPoint>;
  void StartCalibrationSequence(std::vector<GridPoint> grid_points);
  void OnCalibrationSequenceComplete(const std::vector<Observation>& observations);
  auto TryComputeCalibrationResult(const TorchPlaneInfo& torch_plane_info,
                                   const GeometricConstants& geometric_constants,
                                   const std::vector<Observation>& observations) -> std::optional<CalibrationResult>;
  void ReportCalibrationResult(const std::optional<CalibrationResult>& result, const TorchPlaneInfo& torch_plane_info,
                               const GeometricConstants& geometric_constants,
                               const std::vector<Observation>& observations);
  void LogCalibrationRun(const TorchPlaneInfo& tp, const GeometricConstants& gc, const std::vector<Observation>& obs,
                         const std::optional<CalibrationResult>& result);
  auto CheckProcedureExpired() -> bool;
  void SetProcedureStartTime();

  DependencyContext* dep_ctx_;
  CalibrationSolver* calibration_solver_;
  slice_translator::RotaryModelConfig* model_config_;
  storage::SqlSingleStorage<StoredCalibrationResult> storage_;
  storage::SqlSingleStorage<StoredLaserTorchConfiguration> ltc_storage_;
  zevs::Timer* timer_;
  GridConfiguration grid_config_;
  RunnerConfiguration runner_config_;
  common::logging::ComponentLogger calibration_logger_;
  std::function<void()> calibration_status_subscriber_;

  using StartProcedure = std::optional<std::function<void(bool)>>;
  StartProcedure calibration_start_procedure_;
  using PositionProcedure = std::optional<std::function<void(const common::Point&)>>;
  PositionProcedure calibration_top_pos_procedure_;
  using ObservationProcedure = std::optional<std::function<void(const std::optional<Observation>&)>>;
  ObservationProcedure calibration_left_pos_procedure_;
  ObservationProcedure calibration_right_pos_procedure_;
  std::unique_ptr<CalibrationSequenceRunner> sequence_runner_;

  std::chrono::time_point<std::chrono::steady_clock> procedure_start_time_;
};

}  // namespace calibration
