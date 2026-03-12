#include "calibration_manager_impl.h"

#include <prometheus/registry.h>
#include <SQLiteCpp/Database.h>

#include <functional>
#include <memory>
#include <nlohmann/json.hpp>

#include "calibration/calibration_configuration.h"
#include "common/logging/component_logger.h"
#include "cw_calibration_handler.h"
#include "lw_calibration_handler.h"
#include "scanner_client/scanner_client.h"
#include "slice_translator/linear_model_config.h"
#include "web_hmi/web_hmi.h"
#include "weld_motion_prediction/configurable_transform.h"

using calibration::CalibrationManagerImpl;

CalibrationManagerImpl::CalibrationManagerImpl(
    SQLite::Database* db, zevs::Timer* timer, scanner_client::ScannerClient* scanner_client,
    CalibrationSolver* calibration_solver, slice_translator::RotaryModelConfig* cw_model_config,
    slice_translator::LinearModelConfig* lw_model_config, coordination::ActivityStatus* activity_status,
    web_hmi::WebHmi* web_hmi, joint_geometry::JointGeometryProvider* joint_geometry_provider,
    clock_functions::SystemClockNowFunc system_clock_now_func,
    clock_functions::SteadyClockNowFunc steady_clock_now_func, kinematics::KinematicsClient* kinematics_client,
    prometheus::Registry* /*registry*/, const std::filesystem::path& path_logs, const GridConfiguration& grid_config,
    const RunnerConfiguration& runner_config, weld_motion_prediction::ConfigurableTransform* transformer)
    : handler_context_{.scanner_client          = scanner_client,
                       .activity_status         = activity_status,
                       .web_hmi                 = web_hmi,
                       .joint_geometry_provider = joint_geometry_provider,
                       .kinematics_client       = kinematics_client,
                       .system_clock_now_func   = system_clock_now_func,
                       .steady_clock_now_func   = steady_clock_now_func,
                       .calibration_logger      = nullptr},
      calibration_logger_(common::logging::ComponentLoggerConfig{
          .component      = "calibration",
          .path_directory = path_logs / "calibration",
          .file_name      = "%Y%m%d_%H%M%S.log",
          .max_file_size  = 1 * 1000 * 1000, /* 1 MB */
          .max_nb_files   = 100,
      }),
      cw_handler_(std::make_unique<CWCalibrationHandler>(db, &handler_context_, calibration_solver, cw_model_config,
                                                         timer, grid_config, runner_config,
                                                         [this]() {
                                                           if (calibration_status_subscriber_) {
                                                             calibration_status_subscriber_();
                                                           }
                                                         })),
      lw_handler_(std::make_unique<LWCalibrationHandler>(
          db, &handler_context_, lw_model_config,
          [this]() {
            if (calibration_status_subscriber_) {
              calibration_status_subscriber_();
            }
          },
          transformer)) {
  handler_context_.calibration_logger = &calibration_logger_;
  scanner_client->SubscribeScanner([this](bool success) { OnGeometryApplied(success); },
                                   [this](const lpcs::Slice& data, const common::Point& axis_position) {
                                     OnScannerDataUpdate(data, axis_position);
                                   });

  cw_handler_->SubscribeWebHmi();
  lw_handler_->SubscribeWebHmi();

  // Apply stored calibration data at startup based on current joint geometry type.
  // No call to calibration_status_subscriber_() in the ctor since ManagementServer
  // is created after CalibrationManager.
  if (auto joint_geometry = handler_context_.joint_geometry_provider->GetJointGeometry()) {
    switch (joint_geometry->type) {
      case joint_geometry::Type::CW:
        if (cw_handler_->HasValidCalibration()) {
          cw_handler_->ApplyCalibration();
        } else {
          LOG_INFO("CalibrationManager: CW joint geometry but no valid CW calibration to apply.");
        }
        break;
      case joint_geometry::Type::LW:
        if (lw_handler_->HasValidCalibration()) {
          lw_handler_->ApplyCalibration();
        } else {
          LOG_INFO("CalibrationManager: LW joint geometry but no valid LW calibration to apply.");
        }
        break;
      case joint_geometry::Type::INVALID:
      default:
        LOG_INFO("CalibrationManager: joint geometry type is INVALID, skipping calibration apply.");
        break;
    }
  } else {
    LOG_INFO("CalibrationManager: no joint geometry available at startup, skipping calibration apply.");
  }

  // Subscribe to joint-geometry updates so calibration is applied when geometry changes.
  handler_context_.joint_geometry_provider->Subscribe([this]() {
    auto joint_geometry = handler_context_.joint_geometry_provider->GetJointGeometry();
    if (!joint_geometry) {
      LOG_INFO("CalibrationManager: joint geometry cleared or not available, skipping calibration apply.");
    } else {
      switch (joint_geometry->type) {
        case joint_geometry::Type::CW:
          if (cw_handler_->HasValidCalibration()) {
            cw_handler_->ApplyCalibration();
          } else {
            LOG_INFO("CalibrationManager: CW joint geometry but no valid CW calibration to apply on update.");
          }
          break;
        case joint_geometry::Type::LW:
          if (lw_handler_->HasValidCalibration()) {
            lw_handler_->ApplyCalibration();
          } else {
            LOG_INFO("CalibrationManager: LW joint geometry but no valid LW calibration to apply on update.");
          }
          break;
        case joint_geometry::Type::INVALID:
        default:
          LOG_INFO("CalibrationManager: joint geometry type is INVALID on update, skipping calibration apply.");
          break;
      }
    }

    // Notify subscribers that calibration status may have changed.
    if (calibration_status_subscriber_) {
      calibration_status_subscriber_();
    }
  });
}

void CalibrationManagerImpl::OnGeometryApplied(bool success) {
  if (auto* handler = GetActiveHandler()) {
    handler->OnGeometryApplied(success);
  }
}

void CalibrationManagerImpl::OnScannerDataUpdate(const lpcs::Slice& data, const common::Point& axis_position) {
  if (auto* handler = GetActiveHandler()) {
    handler->OnScannerDataUpdate(data, axis_position);
  }
}

auto CalibrationManagerImpl::CalibrationValid() const -> bool {
  auto joint_geometry = handler_context_.joint_geometry_provider->GetJointGeometry();
  if (!joint_geometry.has_value()) {
    return false;
  }

  switch (joint_geometry->type) {
    case joint_geometry::Type::CW:
      return cw_handler_->HasValidCalibration();
    case joint_geometry::Type::LW:
      return lw_handler_->HasValidCalibration();
    case joint_geometry::Type::INVALID:
    default:
      return false;
  }
};

void CalibrationManagerImpl::Subscribe(std::function<void()> subscriber) {
  calibration_status_subscriber_ = subscriber;
};

auto CalibrationManagerImpl::GetActiveHandler() -> CalibrationHandler* {
  const auto status = handler_context_.activity_status->Get();
  if (cw_handler_->CanHandle(status)) {
    return cw_handler_.get();
  }
  if (lw_handler_->CanHandle(status)) {
    return lw_handler_.get();
  }
  return nullptr;
}
