#pragma once

#include "calibration_handler.h"
#include "calibration_solver.h"
#include "common/storage/sql_single_storage.h"
#include "common/types/vector_3d.h"
#include "joint_geometry/joint_geometry.h"
#include "slice_translator/linear_model_config.h"
#include "stored_lw_cal_result.h"
#include "weld_motion_prediction/configurable_transform.h"
#include "weld_motion_prediction/transformer.h"

namespace slice_translator {
class ModelConfig;
}

namespace calibration {

class LWCalibrationHandler : public CalibrationHandler {
 public:
  LWCalibrationHandler(SQLite::Database* db, DependencyContext* dep_ctx,
                       slice_translator::LinearModelConfig* lw_model_config,
                       std::function<void()> calibration_status_subscriber,
                       weld_motion_prediction::ConfigurableTransform* transformer);

  // CalibrationHandler
  auto CanHandle(coordination::ActivityStatusE status) const -> bool override;
  auto IsBusy() const -> bool override;
  void OnScannerDataUpdate(const lpcs::Slice& data, const common::Point& axis_position) override;
  void OnGeometryApplied(bool success) override;
  void Cleanup() override;

  // WebHMI message handlers
  void OnLWCalGet();
  void OnLWCalSet(const nlohmann::json& payload);
  void OnLWCalStart(const nlohmann::json& payload);
  void OnLWCalStop();
  void OnLWCalTopPos();
  void OnLWCalLeftPos();
  void OnLWCalRightPos();

  void SubscribeWebHmi() override;
  void ApplyCalibration() override;
  auto HasValidCalibration() const -> bool override;

 private:
  struct LWCalibrationContext {
    double distance_laser_torch{};
    double stickout{};
    double wire_diameter{};
    double scanner_mount_angle{};
    joint_geometry::JointGeometry joint_geometry;
    std::optional<Observation> single_observation;
    Observation top;
    common::Point left;
    common::Point right;
  } cal_ctx_;

  void SendLWCalStartFailure(const std::string& reason);
  void LogCalibrationFailure(const std::string& reason);
  void HandleInitialObservationData(const lpcs::Slice& data, const common::Point& axis_position);
  void HandleTopPosData(const common::Point& axis_position);
  void HandleLeftPosData(const common::Point& axis_position);
  void HandleRightPosData(const common::Point& axis_position);
  void HandleLWLeftTouchFailure(const std::string& reason);
  void HandleLWRightTouchFailure(const std::string& reason);
  auto CheckProcedureExpired() -> bool;
  void SetProcedureStartTime();
  auto CalculateTopCenterMacs() -> std::optional<common::Point>;
  auto CalculateTopCenterLpcs() -> std::optional<lpcs::Point>;
  auto TryComputeCalibrationResult() -> std::optional<LWCalibrationResult>;
  void ReportCalibrationResult(const std::optional<LWCalibrationResult>& result, const Observation& single_obs,
                               const Observation& top, const Observation& left, const Observation& right);
  void LogCalibrationRun(const std::optional<LWCalibrationResult>& result, const Observation& single_obs,
                         const Observation& top, const Observation& left, const Observation& right);

  DependencyContext* dep_ctx_;
  [[maybe_unused]] slice_translator::LinearModelConfig* model_config_;
  weld_motion_prediction::ConfigurableTransform* transformer_;
  storage::SqlSingleStorage<StoredLWCalResult> storage_;
  std::function<void()> calibration_status_subscriber_;

  using PositionProcedure = std::optional<std::function<void(const common::Point&)>>;
  PositionProcedure calibration_top_pos_procedure_;
  PositionProcedure calibration_left_pos_procedure_;
  PositionProcedure calibration_right_pos_procedure_;
  using InitialObservationProcedure = std::optional<std::function<void(const Observation&)>>;
  InitialObservationProcedure calibration_initial_observation_procedure_;
  using StartProcedure = std::optional<std::function<void(bool)>>;
  StartProcedure calibration_start_procedure_;

  std::chrono::time_point<std::chrono::steady_clock> procedure_start_time_;
};

}  // namespace calibration
