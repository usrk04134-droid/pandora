#pragma once

#include <prometheus/registry.h>
#include <SQLiteCpp/Database.h>

#include "calibration/calibration_configuration.h"
#include "calibration_handler.h"
#include "calibration_solver.h"
#include "common/clock_functions.h"
#include "common/zevs/zevs_socket.h"
#include "coordination/activity_status.h"
#include "coordination/calibration_status.h"
#include "joint_geometry/joint_geometry_provider.h"
#include "kinematics/kinematics_client.h"
#include "scanner_client/scanner_client.h"
#include "slice_translator/linear_model_config.h"
#include "slice_translator/rotary_model_config.h"
#include "web_hmi/web_hmi.h"
#include "weld_motion_prediction/configurable_transform.h"

namespace calibration {

class CalibrationManagerImpl : public coordination::CalibrationStatus {
 public:
  CalibrationManagerImpl(SQLite::Database* db, zevs::Timer* timer, scanner_client::ScannerClient* scanner_client,
                         CalibrationSolver* calibration_solver, slice_translator::RotaryModelConfig* cw_model_config,
                         slice_translator::LinearModelConfig* lw_model_config,
                         coordination::ActivityStatus* activity_status, web_hmi::WebHmi* web_hmi,
                         joint_geometry::JointGeometryProvider* joint_geometry_provider,
                         clock_functions::SystemClockNowFunc system_clock_now_func,
                         clock_functions::SteadyClockNowFunc steady_clock_now_func,
                         kinematics::KinematicsClient* kinematics_client, prometheus::Registry* registry,
                         const std::filesystem::path& path_logs, const GridConfiguration& grid_config,
                         const RunnerConfiguration& runner_config,
                         weld_motion_prediction::ConfigurableTransform* transformer);

  auto CalibrationValid() const -> bool override;
  void Subscribe(std::function<void()> subscriber) override;

 private:
  void OnGeometryApplied(bool success);
  void OnScannerDataUpdate(const lpcs::Slice& data, const common::Point& axis_position);
  auto GetActiveHandler() -> CalibrationHandler*;

  DependencyContext handler_context_;
  common::logging::ComponentLogger calibration_logger_;
  std::unique_ptr<CalibrationHandler> cw_handler_;
  std::unique_ptr<CalibrationHandler> lw_handler_;
  std::function<void()> calibration_status_subscriber_;
};

}  // namespace calibration
