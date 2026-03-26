#include "lw_calibration_handler.h"

#include <chrono>
#include <Eigen/Core>
#include <nlohmann/json.hpp>
#include <optional>

#include "calibration/src/calibration_grid_generator.h"
#include "calibration_log_helpers.h"
#include "calibration_solver.h"
#include "common/logging/application_log.h"
#include "common/time/format.h"
#include "joint_geometry/joint_geometry_provider.h"
#include "lpcs/lpcs_point.h"
#include "scanner_client/scanner_client.h"
#include "slice_translator/linear_model_config.h"
#include "stored_lw_cal_result.h"
#include "web_hmi/web_hmi.h"

namespace calibration {

const common::Vector3D DEFAULT_WELD_DIRECTION{.c1 = 0.0, .c2 = -1.0, .c3 = 0.0};  // Intentionally negative
const uint32_t CONFIDENCE_DATA_MAX_WAIT_SEC = 3;
const auto SUCCESS_PAYLOAD                  = nlohmann::json{
                     {"result", "ok"}
};
const auto FAILURE_PAYLOAD = nlohmann::json{
    {"result", "fail"}
};

LWCalibrationHandler::LWCalibrationHandler(SQLite::Database* db, DependencyContext* dep_ctx,
                                           slice_translator::LinearModelConfig* model_config,
                                           std::function<void()> calibration_status_subscriber,
                                           weld_motion_prediction::ConfigurableTransform* transformer)
    : dep_ctx_(dep_ctx),
      model_config_(model_config),
      transformer_(transformer),
      storage_(db, StoredLWCalResult::CreateTable, StoredLWCalResult::StoreFn(), StoredLWCalResult::GetFn()),
      calibration_status_subscriber_(calibration_status_subscriber) {}

auto LWCalibrationHandler::CanHandle(coordination::ActivityStatusE status) const -> bool {
  return status == coordination::ActivityStatusE::LW_CALIBRATION;
}

auto LWCalibrationHandler::IsBusy() const -> bool {
  return calibration_start_procedure_.has_value() || calibration_initial_observation_procedure_.has_value() ||
         calibration_top_pos_procedure_.has_value() || calibration_left_pos_procedure_.has_value() ||
         calibration_right_pos_procedure_.has_value();
}

void LWCalibrationHandler::OnScannerDataUpdate(const lpcs::Slice& data, const common::Point& axis_position) {
  // Convert procedure_start_time to raw ticks for comparison with data.time_stamp (uint64_t)
  if (data.time_stamp < procedure_start_time_.time_since_epoch().count()) {
    return;
  }

  if (calibration_top_pos_procedure_) {
    HandleTopPosData(axis_position);
    return;
  }

  if (calibration_left_pos_procedure_) {
    HandleLeftPosData(axis_position);
    return;
  }

  if (calibration_right_pos_procedure_) {
    HandleRightPosData(axis_position);
    return;
  }

  if (calibration_initial_observation_procedure_) {
    HandleInitialObservationData(data, axis_position);
    return;
  }
}

void LWCalibrationHandler::OnGeometryApplied(bool success) {
  if (calibration_start_procedure_) {
    (*calibration_start_procedure_)(success);
  }
}

void LWCalibrationHandler::Cleanup() {
  cal_ctx_                                   = LWCalibrationContext{};
  calibration_top_pos_procedure_             = {};
  calibration_left_pos_procedure_            = {};
  calibration_right_pos_procedure_           = {};
  calibration_initial_observation_procedure_ = {};
  calibration_start_procedure_               = {};
}

void LWCalibrationHandler::OnLWCalGet() {
  if (const auto lw_cal_result = storage_.Get()) {
    nlohmann::json payload = lw_cal_result.value().ToJson();
    dep_ctx_->web_hmi->Send("LWCalGetRsp", SUCCESS_PAYLOAD, payload);
  } else {
    dep_ctx_->web_hmi->Send("LWCalGetRsp", FAILURE_PAYLOAD, "No valid LW calibration stored", std::nullopt);
  }
}

void LWCalibrationHandler::OnLWCalSet(const nlohmann::json& payload) {
  const auto cal_data = StoredLWCalResult::FromJson(payload);
  if (cal_data.has_value()) {
    auto result = storage_.Store(cal_data.value());
    if (result) {
      if (const auto stored = storage_.Get()) {
        LOG_INFO("Stored LW calibration result updated to: {}", stored->ToJson().dump());
      }
      dep_ctx_->web_hmi->Send("LWCalSetRsp", SUCCESS_PAYLOAD, std::nullopt);
      calibration_status_subscriber_();
      return;
    }
  }

  dep_ctx_->web_hmi->Send("LWCalSetRsp", FAILURE_PAYLOAD, "Unable to store LW calibration data", std::nullopt);
}

void LWCalibrationHandler::OnLWCalStart(const nlohmann::json& payload) {
  if (IsBusy()) {
    SendLWCalStartFailure("Calibration already in progress");
    return;
  }

  if (!dep_ctx_->activity_status->IsIdle()) {
    SendLWCalStartFailure("Activity status not idle");
    return;
  }

  auto joint_geometry = dep_ctx_->joint_geometry_provider->GetJointGeometry();
  if (!joint_geometry) {
    SendLWCalStartFailure("Joint geometry not available");
    return;
  }

  if (joint_geometry->type != joint_geometry::Type::LW) {
    SendLWCalStartFailure("Joint geometry type is not LW");
    return;
  }

  try {
    payload.at("wireDiameter").get_to(cal_ctx_.wire_diameter);
    payload.at("distanceLaserTorch").get_to(cal_ctx_.distance_laser_torch);
    payload.at("stickout").get_to(cal_ctx_.stickout);
    payload.at("scannerMountAngle").get_to(cal_ctx_.scanner_mount_angle);

    if (cal_ctx_.wire_diameter <= 0.0 || cal_ctx_.distance_laser_torch <= 0.0 || cal_ctx_.stickout <= 0.0 ||
        cal_ctx_.scanner_mount_angle < 0.0) {
      SendLWCalStartFailure("Invalid LW calibration data: values must be positive");
      return;
    }
  } catch (const nlohmann::json::exception& e) {
    SendLWCalStartFailure(fmt::format("Invalid LW calibration data: {}", e.what()));
    return;
  }

  cal_ctx_.joint_geometry     = joint_geometry.value();
  cal_ctx_.single_observation = std::nullopt;

  dep_ctx_->activity_status->Set(coordination::ActivityStatusE::LW_CALIBRATION);

  calibration_start_procedure_ = [this](bool success) {
    LOG_INFO("LW Calibration start procedure completed");
    if (!success) {
      dep_ctx_->web_hmi->Send("LWCalStartRsp", FAILURE_PAYLOAD, "Scanner start failed", std::nullopt);
      LogCalibrationFailure("Scanner start failed");
      Cleanup();
      dep_ctx_->activity_status->Set(coordination::ActivityStatusE::IDLE);
    } else {
      // Set up a procedure to capture an initial observation when scanner data arrives
      SetProcedureStartTime();
      calibration_initial_observation_procedure_ = [this](const Observation& observation) {
        cal_ctx_.single_observation = observation;
        LOG_INFO("LW Calibration: captured single observation at h: {:.2f}, v: {:.2f}",
                 observation.slide_position.horizontal, observation.slide_position.vertical);

        dep_ctx_->web_hmi->Send("LWCalStartRsp", SUCCESS_PAYLOAD, std::nullopt);
        calibration_initial_observation_procedure_ = {};
      };
    }
    calibration_start_procedure_ = {};
  };

  dep_ctx_->scanner_client->SetJointGeometry(cal_ctx_.joint_geometry);
}

void LWCalibrationHandler::OnLWCalStop() {
  LOG_INFO("LWCalStop received");
  Cleanup();
  dep_ctx_->activity_status->Set(coordination::ActivityStatusE::IDLE);
  dep_ctx_->web_hmi->Send("LWCalStopRsp", SUCCESS_PAYLOAD, std::nullopt);
}

void LWCalibrationHandler::OnLWCalTopPos() {
  if (IsBusy()) {
    LOG_INFO("LWCalTopPos received when busy");
    dep_ctx_->web_hmi->Send("LWCalTopPosRsp", FAILURE_PAYLOAD, "Busy", std::nullopt);
    return;
  }

  if (dep_ctx_->activity_status->Get() != coordination::ActivityStatusE::LW_CALIBRATION) {
    LOG_INFO("LWCalTopPos received when activity status not LW_CALIBRATION");
    dep_ctx_->web_hmi->Send("LWCalTopPosRsp", FAILURE_PAYLOAD, "Activity status not LW_CALIBRATION", std::nullopt);
    return;
  }

  LOG_INFO("LWCalTopPos received");
  SetProcedureStartTime();

  calibration_top_pos_procedure_ = [this](const common::Point& axis_position) {
    cal_ctx_.top = Observation{.slide_position = axis_position, .abw_points_lpcs = {}};
    LOG_INFO("LW Calibration top touch position, recorded at h: {:.2f}, v: {:.2f}", axis_position.horizontal,
             axis_position.vertical);
    dep_ctx_->web_hmi->Send("LWCalTopPosRsp", SUCCESS_PAYLOAD, std::nullopt);
    calibration_top_pos_procedure_ = {};
  };
}

void LWCalibrationHandler::OnLWCalLeftPos() {
  if (IsBusy()) {
    LOG_INFO("LWCalLeftPos received when busy");
    dep_ctx_->web_hmi->Send("LWCalLeftPosRsp", FAILURE_PAYLOAD, "Busy", std::nullopt);
    return;
  }

  if (dep_ctx_->activity_status->Get() != coordination::ActivityStatusE::LW_CALIBRATION) {
    LOG_INFO("LWCalLeftPos received when activity status not LW_CALIBRATION");
    dep_ctx_->web_hmi->Send("LWCalLeftPosRsp", FAILURE_PAYLOAD, "Activity status not LW_CALIBRATION", std::nullopt);
    return;
  }

  LOG_INFO("LWCalLeftPos received");
  SetProcedureStartTime();

  calibration_left_pos_procedure_ = [this](const common::Point& axis_position) {
    cal_ctx_.left = axis_position;
    LOG_INFO("LW Calibration left touch position, recorded at h: {:.2f}, v: {:.2f}", axis_position.horizontal,
             axis_position.vertical);
    dep_ctx_->web_hmi->Send("LWCalLeftPosRsp", SUCCESS_PAYLOAD, std::nullopt);
    calibration_left_pos_procedure_ = {};
  };
}

void LWCalibrationHandler::OnLWCalRightPos() {
  if (IsBusy()) {
    LOG_INFO("LWCalRightPos received when busy");
    dep_ctx_->web_hmi->Send("LWCalRightPosRsp", FAILURE_PAYLOAD, "Busy", std::nullopt);
    return;
  }

  if (dep_ctx_->activity_status->Get() != coordination::ActivityStatusE::LW_CALIBRATION) {
    LOG_INFO("LWCalRightPos received when activity status not LW_CALIBRATION");
    dep_ctx_->web_hmi->Send("LWCalRightPosRsp", FAILURE_PAYLOAD, "Activity status not LW_CALIBRATION", std::nullopt);
    return;
  }

  LOG_INFO("LWCalRightPos received");
  SetProcedureStartTime();

  calibration_right_pos_procedure_ = [this](const common::Point& axis_position) {
    cal_ctx_.right = axis_position;
    LOG_INFO("LW Calibration right touch position, recorded at h: {:.2f}, v: {:.2f}", axis_position.horizontal,
             axis_position.vertical);
    dep_ctx_->web_hmi->Send("LWCalRightPosRsp", SUCCESS_PAYLOAD, std::nullopt);
    calibration_right_pos_procedure_ = {};

    if (!cal_ctx_.single_observation.has_value()) {
      HandleLWRightTouchFailure("Single observation not available");
      return;
    }

    // Create minimal Observation objects for left and right (only slide position, no scanner data)
    Observation left_obs{.slide_position = cal_ctx_.left, .abw_points_lpcs = {}};
    Observation right_obs{.slide_position = cal_ctx_.right, .abw_points_lpcs = {}};

    const auto result = TryComputeCalibrationResult();
    ReportCalibrationResult(result, cal_ctx_.single_observation.value(), cal_ctx_.top, left_obs, right_obs);

    Cleanup();
    dep_ctx_->activity_status->Set(coordination::ActivityStatusE::IDLE);
    dep_ctx_->kinematics_client->Release();
  };
}

auto LWCalibrationHandler::TryComputeCalibrationResult() -> std::optional<LWCalibrationResult> {
  auto point_macs = CalculateTopCenterMacs();
  auto point_lpcs = CalculateTopCenterLpcs();

  if (!point_macs || !point_lpcs) {
    return std::nullopt;
  }

  Eigen::Matrix3d rotation_lpcs_relative_macs;
  Eigen::Vector3d translation_tcs_relative_macs;
  Eigen::Vector3d p_macs;
  Eigen::Vector3d p_lpcs;
  Eigen::Vector3d translation_lpcs_relative_tcs;

  p_macs = {point_macs->horizontal, cal_ctx_.distance_laser_torch, point_macs->vertical};
  p_lpcs = {point_lpcs->x, point_lpcs->y, 0.0};

  rotation_lpcs_relative_macs   = transformer_->ComputeLpcsOrientation({cal_ctx_.scanner_mount_angle, 0.0, 0.0});
  translation_tcs_relative_macs = {cal_ctx_.single_observation->slide_position.horizontal, 0.0,
                                   cal_ctx_.single_observation->slide_position.vertical};
  translation_lpcs_relative_tcs = (p_macs - translation_tcs_relative_macs) - rotation_lpcs_relative_macs * p_lpcs;

  LWCalibrationResult result;
  result.torch_to_lpcs_translation = common::Vector3D{.c1 = translation_lpcs_relative_tcs(0),
                                                      .c2 = translation_lpcs_relative_tcs(1),
                                                      .c3 = translation_lpcs_relative_tcs(2)};
  return result;
}

void LWCalibrationHandler::ReportCalibrationResult(const std::optional<LWCalibrationResult>& result,
                                                   const Observation& single_obs, const Observation& top,
                                                   const Observation& left, const Observation& right) {
  if (result.has_value()) {
    auto stored_result =
        StoredLWCalResult::FromLWCalibrationResult(result.value(), cal_ctx_.distance_laser_torch, cal_ctx_.stickout,
                                                   cal_ctx_.scanner_mount_angle, cal_ctx_.wire_diameter);
    nlohmann::json payload = stored_result.ToJson();
    LOG_INFO("Successful LW calibration result: {}", payload.dump());
    dep_ctx_->web_hmi->Send("LWCalResult", SUCCESS_PAYLOAD, payload);
  } else {
    LOG_ERROR("LW Calibration failed");
    dep_ctx_->web_hmi->Send("LWCalResult", FAILURE_PAYLOAD, "Calibration failed", std::nullopt);
  }

  LogCalibrationRun(result, single_obs, top, left, right);
}

void LWCalibrationHandler::LogCalibrationRun(const std::optional<LWCalibrationResult>& result,
                                             const Observation& single_obs, const Observation& top,
                                             const Observation& left, const Observation& right) {
  auto now           = dep_ctx_->system_clock_now_func();
  nlohmann::json log = {
      {"timestamp", common::time::TimePointToString(now, common::time::FMT_TS_MS)},
      {"success", result.has_value()},
      {"jointGeometry", ToJsonLog(cal_ctx_.joint_geometry)},
      {"singleObservation", ToJsonLog(single_obs)},
      {"topObservation", ToJsonLog(top)},
      {"leftObservation", ToJsonLog(left)},
      {"rightObservation", ToJsonLog(right)},
  };

  if (result) {
    log["calibrationResult"] = ToJsonLog(*result);
  } else {
    log["failureReason"] = "Calibration computation failed";
  }
  dep_ctx_->calibration_logger->Log(log.dump());
}

void LWCalibrationHandler::LogCalibrationFailure(const std::string& reason) {
  auto now           = dep_ctx_->system_clock_now_func();
  nlohmann::json log = {
      {"timestamp", common::time::TimePointToString(now, common::time::FMT_TS_MS)},
      {"success", false},
      {"failureReason", reason},
      {"jointGeometry", ToJsonLog(cal_ctx_.joint_geometry)},
  };

  if (cal_ctx_.single_observation) {
    log["singleObservation"] = ToJsonLog(*cal_ctx_.single_observation);
  }

  dep_ctx_->calibration_logger->Log(log.dump());
}

void LWCalibrationHandler::SendLWCalStartFailure(const std::string& reason) {
  LOG_ERROR("LWCalStart failed: {}", reason);
  dep_ctx_->web_hmi->Send("LWCalStartRsp", FAILURE_PAYLOAD, reason, std::nullopt);
  LogCalibrationFailure(reason);
}

void LWCalibrationHandler::HandleInitialObservationData(const lpcs::Slice& data, const common::Point& axis_position) {
  if (CheckProcedureExpired()) {
    LOG_ERROR("LW Calibration: timeout waiting for initial observation");
    dep_ctx_->web_hmi->Send("LWCalStartRsp", FAILURE_PAYLOAD, "Timeout waiting for scanner data", std::nullopt);
    LogCalibrationFailure("Timeout waiting for scanner data");
    Cleanup();
    dep_ctx_->activity_status->Set(coordination::ActivityStatusE::IDLE);
    return;
  }

  if (data.confidence == lpcs::SliceConfidence::HIGH && data.groove) {
    Observation observation{.slide_position = axis_position, .abw_points_lpcs = *data.groove};
    (*calibration_initial_observation_procedure_)(observation);
  }
}

void LWCalibrationHandler::HandleTopPosData(const common::Point& axis_position) {
  if (CheckProcedureExpired()) {
    LOG_ERROR("LW Calibration top touch procedure expired");
    dep_ctx_->web_hmi->Send("LWCalTopPosRsp", FAILURE_PAYLOAD, "Procedure expired", std::nullopt);
    LogCalibrationFailure("Top touch procedure expired");
    Cleanup();
    dep_ctx_->activity_status->Set(coordination::ActivityStatusE::IDLE);
    return;
  }

  (*calibration_top_pos_procedure_)(axis_position);
}

void LWCalibrationHandler::HandleLeftPosData(const common::Point& axis_position) {
  if (CheckProcedureExpired()) {
    HandleLWLeftTouchFailure("Procedure expired");
    return;
  }

  (*calibration_left_pos_procedure_)(axis_position);
}

void LWCalibrationHandler::HandleRightPosData(const common::Point& axis_position) {
  if (CheckProcedureExpired()) {
    HandleLWRightTouchFailure("Procedure expired");
    return;
  }

  (*calibration_right_pos_procedure_)(axis_position);
}

void LWCalibrationHandler::HandleLWLeftTouchFailure(const std::string& reason) {
  LOG_ERROR("LW Calibration left touch procedure failed: {}", reason);
  dep_ctx_->web_hmi->Send("LWCalLeftPosRsp", FAILURE_PAYLOAD, reason, std::nullopt);
  LogCalibrationFailure("Left touch failed: " + reason);
  Cleanup();
  dep_ctx_->activity_status->Set(coordination::ActivityStatusE::IDLE);
}

void LWCalibrationHandler::HandleLWRightTouchFailure(const std::string& reason) {
  LOG_ERROR("LW Calibration right touch procedure failed: {}", reason);
  dep_ctx_->web_hmi->Send("LWCalRightPosRsp", FAILURE_PAYLOAD, reason, std::nullopt);
  LogCalibrationFailure("Right touch failed: " + reason);
  Cleanup();
  dep_ctx_->activity_status->Set(coordination::ActivityStatusE::IDLE);
}

auto LWCalibrationHandler::CheckProcedureExpired() -> bool {
  const auto now      = dep_ctx_->steady_clock_now_func();
  const auto deadline = procedure_start_time_ + std::chrono::seconds(CONFIDENCE_DATA_MAX_WAIT_SEC);
  return now > deadline;
}

void LWCalibrationHandler::SetProcedureStartTime() { procedure_start_time_ = dep_ctx_->steady_clock_now_func(); }

void LWCalibrationHandler::ApplyCalibration() {
  const auto stored_calibration_result = storage_.Get();

  if (stored_calibration_result && stored_calibration_result->IsValid()) {
    model_config_->ActivateWithConfig(DEFAULT_WELD_DIRECTION,
                                      {stored_calibration_result->ScannerMountAngle(), 0.0, 0.0},
                                      stored_calibration_result->TorchToLpcsTranslation());
    LOG_INFO("LW calibration: ApplyCalibration called.");
  } else {
    LOG_INFO("LW calibration: no valid calibration available to apply.");
  }
}

auto LWCalibrationHandler::HasValidCalibration() const -> bool {
  const auto stored = storage_.Get();
  return stored.has_value() && stored->IsValid();
}

void LWCalibrationHandler::SubscribeWebHmi() {
  dep_ctx_->web_hmi->Subscribe("LWCalGet", [this](std::string const&, const nlohmann::json&) { this->OnLWCalGet(); });
  dep_ctx_->web_hmi->Subscribe(
      "LWCalSet", [this](std::string const&, const nlohmann::json& payload) { this->OnLWCalSet(payload); });
  dep_ctx_->web_hmi->Subscribe(
      "LWCalStart", [this](std::string const&, const nlohmann::json& payload) { this->OnLWCalStart(payload); });
  dep_ctx_->web_hmi->Subscribe("LWCalStop", [this](std::string const&, const nlohmann::json&) { this->OnLWCalStop(); });
  dep_ctx_->web_hmi->Subscribe("LWCalTopPos",
                               [this](std::string const&, const nlohmann::json&) { this->OnLWCalTopPos(); });
  dep_ctx_->web_hmi->Subscribe("LWCalLeftPos",
                               [this](std::string const&, const nlohmann::json&) { this->OnLWCalLeftPos(); });
  dep_ctx_->web_hmi->Subscribe("LWCalRightPos",
                               [this](std::string const&, const nlohmann::json&) { this->OnLWCalRightPos(); });
}

auto LWCalibrationHandler::CalculateTopCenterMacs() -> std::optional<common::Point> {
  const auto& joint_geometry = cal_ctx_.joint_geometry;
  const auto& top_obs        = cal_ctx_.top;
  const auto& left_point     = cal_ctx_.left;
  const auto& right_point    = cal_ctx_.right;
  const auto stickout        = cal_ctx_.stickout;
  const auto wire_diameter   = cal_ctx_.wire_diameter;

  // Don't care about the top center point for LW. Using default height diff of zero.
  double left_to_right_height_diff = 0.0;

  return ValidateAndCalculateGrooveTopCenter2(joint_geometry, wire_diameter, stickout, left_point, right_point,
                                              top_obs.slide_position, left_to_right_height_diff);
}

auto LWCalibrationHandler::CalculateTopCenterLpcs() -> std::optional<lpcs::Point> {
  if (!cal_ctx_.single_observation) {
    return std::nullopt;
  }

  auto abw0 = cal_ctx_.single_observation->abw_points_lpcs.at(0);
  auto abw6 = cal_ctx_.single_observation->abw_points_lpcs.at(6);
  return std::make_optional<lpcs::Point>({.x = (abw0.x + abw6.x) / 2, .y = (abw0.y + abw6.y) / 2});
}

}  // namespace calibration
