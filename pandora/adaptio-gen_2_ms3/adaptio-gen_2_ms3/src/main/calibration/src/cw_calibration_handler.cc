#include "cw_calibration_handler.h"

#include <chrono>
#include <nlohmann/json.hpp>

#include "calibration_grid_generator.h"
#include "calibration_log_helpers.h"
#include "calibration_sequence_runner.h"
#include "common/groove/groove.h"
#include "common/logging/application_log.h"
#include "common/time/format.h"
#include "scanner_client/scanner_client.h"
#include "slice_translator/rotary_model_config.h"
#include "stored_calibration_result.h"
#include "web_hmi/web_hmi.h"

namespace calibration {

const double RSE_LIMIT                      = 1.0;
const uint32_t CONFIDENCE_DATA_MAX_WAIT_SEC = 3;
const auto SUCCESS_PAYLOAD                  = nlohmann::json{
                     {"result", "ok"}
};
const auto FAILURE_PAYLOAD = nlohmann::json{
    {"result", "fail"}
};

namespace {
struct CalibrationStartParams {
  double wire_diameter;
  double stickout;
  double weld_object_radius;
};

auto ParseCalibrationStartPayload(const nlohmann::json& payload) -> std::optional<CalibrationStartParams> {
  try {
    CalibrationStartParams params{};
    payload.at("wireDiameter").get_to(params.wire_diameter);
    payload.at("stickout").get_to(params.stickout);
    payload.at("weldObjectRadius").get_to(params.weld_object_radius);

    if (params.wire_diameter > 0 && params.stickout > 0 && params.weld_object_radius > 0) {
      return params;
    }
    LOG_ERROR("WeldObjectCalStart has invalid numeric values: {}, {}, {}", params.wire_diameter, params.stickout,
              params.weld_object_radius);

  } catch (const nlohmann::json::exception& e) {
    LOG_ERROR("Failed to parse WeldObjectCalStart payload: {}", e.what());
  }

  return std::nullopt;
}
}  // namespace

auto CWCalibrationHandler::CalibrationContext::TouchDepth() const -> double {
  return top_center.vertical - (left.slide_position.vertical - stickout);
}

CWCalibrationHandler::CWCalibrationHandler(SQLite::Database* db, DependencyContext* dep_ctx,
                                           CalibrationSolver* calibration_solver,
                                           slice_translator::RotaryModelConfig* model_config, zevs::Timer* timer,
                                           const GridConfiguration& grid_config,
                                           const RunnerConfiguration& runner_config,
                                           std::function<void()> calibration_status_subscriber)
    : dep_ctx_(dep_ctx),
      calibration_solver_(calibration_solver),
      model_config_(model_config),
      storage_(db, StoredCalibrationResult::CreateTable, StoredCalibrationResult::StoreFn(),
               StoredCalibrationResult::GetFn()),
      ltc_storage_(db, StoredLaserTorchConfiguration::CreateTable, StoredLaserTorchConfiguration::StoreFn(),
                   StoredLaserTorchConfiguration::GetFn()),
      timer_(timer),
      grid_config_(grid_config),
      runner_config_(runner_config),
      calibration_status_subscriber_(calibration_status_subscriber) {
  LOG_INFO("Calibration grid_config: {}", ToJsonLog(grid_config).dump());
  LOG_INFO("Calibration runner_config: {}", ToJsonLog(runner_config).dump());
}

auto CWCalibrationHandler::CanHandle(coordination::ActivityStatusE status) const -> bool {
  return status == coordination::ActivityStatusE::WELD_OBJECT_CALIBRATION ||
         status == coordination::ActivityStatusE::CALIBRATION_AUTO_MOVE;
}

auto CWCalibrationHandler::IsBusy() const -> bool {
  return calibration_start_procedure_.has_value() || calibration_top_pos_procedure_.has_value() ||
         calibration_left_pos_procedure_.has_value() || calibration_right_pos_procedure_.has_value() ||
         (sequence_runner_ && sequence_runner_->Busy());
}

auto CWCalibrationHandler::HasValidCalibration() const -> bool {
  const auto woc = storage_.Get();
  return woc.has_value();
}

void CWCalibrationHandler::OnScannerDataUpdate(const lpcs::Slice& data, const common::Point& axis_position) {
  if (sequence_runner_ && sequence_runner_->Busy()) {
    sequence_runner_->OnScannerDataUpdate(data, axis_position);
    return;
  }

  // Convert procedure_start_time to raw ticks for comparison with data.time_stamp (uint64_t)
  if (data.time_stamp < procedure_start_time_.time_since_epoch().count()) {
    return;
  }

  if (calibration_top_pos_procedure_) {
    HandleTopPosData(axis_position);
    return;
  }

  if (calibration_left_pos_procedure_) {
    HandleLeftPosData(data, axis_position);
    return;
  }

  if (calibration_right_pos_procedure_) {
    HandleRightPosData(data, axis_position);
    return;
  }
}

void CWCalibrationHandler::OnGeometryApplied(bool success) {
  if (calibration_start_procedure_) {
    (*calibration_start_procedure_)(success);
  }
}

void CWCalibrationHandler::Cleanup() {
  cal_ctx_                         = CalibrationContext{};
  calibration_top_pos_procedure_   = {};
  calibration_left_pos_procedure_  = {};
  calibration_right_pos_procedure_ = {};
  sequence_runner_                 = {};
  calibration_start_procedure_     = {};
}

void CWCalibrationHandler::OnLaserTorchCalGet() {
  if (const auto laser_torch_configuration = ltc_storage_.Get()) {
    nlohmann::json payload = laser_torch_configuration.value().ToJson();
    dep_ctx_->web_hmi->Send("LaserTorchCalGetRsp", SUCCESS_PAYLOAD, payload);
  } else {
    dep_ctx_->web_hmi->Send("LaserTorchCalGetRsp", FAILURE_PAYLOAD, "No valid laser to torch calibration stored",
                            std::nullopt);
  }
}

void CWCalibrationHandler::OnLaserTorchCalSet(const nlohmann::json& payload) {
  if (dep_ctx_->activity_status->Get() == coordination::ActivityStatusE::WELD_OBJECT_CALIBRATION ||
      dep_ctx_->activity_status->Get() == coordination::ActivityStatusE::LW_CALIBRATION) {
    dep_ctx_->activity_status->Set(coordination::ActivityStatusE::IDLE);
  }

  if (const auto joint_geometry = dep_ctx_->joint_geometry_provider->GetJointGeometry()) {
    if (joint_geometry->type != joint_geometry::Type::CW) {
      LOG_WARNING("LaserTorchCalSet received when joint geometry type is not CW");
    }
  }

  const auto cal_data = StoredLaserTorchConfiguration::FromJson(payload);
  if (cal_data.has_value()) {
    auto result = ltc_storage_.Store(cal_data.value());
    if (result) {
      if (const auto stored = ltc_storage_.Get()) {
        LOG_INFO("Stored laser torch configuration updated to: {}", stored->ToJson().dump());
      }

      storage_.Clear();

      model_config_->Reset();
      dep_ctx_->web_hmi->Send("LaserTorchCalSetRsp", SUCCESS_PAYLOAD, std::nullopt);
      return;
    }
  }

  dep_ctx_->web_hmi->Send("LaserTorchCalSetRsp", FAILURE_PAYLOAD, "Unable to store laser to torch calibration data",
                          std::nullopt);
}

void CWCalibrationHandler::OnWeldObjectCalGet() {
  if (const auto calibration_result = storage_.Get()) {
    nlohmann::json payload = calibration_result.value().ToJson();
    dep_ctx_->web_hmi->Send("WeldObjectCalGetRsp", SUCCESS_PAYLOAD, payload);
  } else {
    dep_ctx_->web_hmi->Send("WeldObjectCalGetRsp", FAILURE_PAYLOAD, "No valid weld-object calibration stored",
                            std::nullopt);
  }
}

void CWCalibrationHandler::ApplyCalibration() {
  const auto stored_calibration_result = storage_.Get();
  const auto laser_torch_configuration = ltc_storage_.Get();

  if (stored_calibration_result.has_value() && laser_torch_configuration.has_value()) {
    std::array<double, 3> scanner_angles = {laser_torch_configuration.value().ScannerMountAngle(), 0.0, 0.0};

    model_config_->ActivateWithConfig(stored_calibration_result.value().RotationCenter(), scanner_angles,
                                      stored_calibration_result.value().WeldObjectRotationAxis(),
                                      stored_calibration_result.value().TorchToLpcsTranslation());
    LOG_INFO("CW calibration: Applied stored calibration to ModelConfig");
  }
}

void CWCalibrationHandler::OnWeldObjectCalSet(const nlohmann::json& payload) {
  const auto cal_data                  = StoredCalibrationResult::FromJson(payload);
  const auto laser_torch_configuration = ltc_storage_.Get();
  if (cal_data.has_value() && laser_torch_configuration.has_value()) {
    auto result = storage_.Store(cal_data.value());
    if (result) {
      if (const auto stored = storage_.Get()) {
        LOG_INFO("Stored calibration result updated to: {}", stored->ToJson().dump());
      }
      std::array<double, 3> scanner_angles = {laser_torch_configuration.value().ScannerMountAngle(), 0.0, 0.0};

      model_config_->ActivateWithConfig(cal_data.value().RotationCenter(), scanner_angles,
                                        cal_data.value().WeldObjectRotationAxis(),
                                        cal_data.value().TorchToLpcsTranslation());
      dep_ctx_->web_hmi->Send("WeldObjectCalSetRsp", SUCCESS_PAYLOAD, std::nullopt);
      calibration_status_subscriber_();

      return;
    }
  }

  if (!laser_torch_configuration.has_value()) {
    LOG_ERROR("WeldObjectCalSet received but no laser to torch calibration is available");
  }

  dep_ctx_->web_hmi->Send("WeldObjectCalSetRsp", FAILURE_PAYLOAD, "Unable to store weld-object calibration data",
                          std::nullopt);
}

void CWCalibrationHandler::OnWeldObjectCalStart(const nlohmann::json& payload) {
  if (!ltc_storage_.Get()) {
    SendCalibrationStartFailure("Laser to torch calibration missing");
    return;
  }

  if (IsBusy()) {
    SendCalibrationStartFailure("Calibration already in progress");
    return;
  }

  if (!dep_ctx_->activity_status->IsIdle()) {
    SendCalibrationStartFailure("Activity status not idle");
    return;
  }

  auto params = ParseCalibrationStartPayload(payload);
  if (!params) {
    SendCalibrationStartFailure("Invalid or missing calibration parameters in payload");
    return;
  }

  LOG_INFO("WeldObjectCalStart: wireDiameter={}, stickout={}, weldObjectRadius={}", params->wire_diameter,
           params->stickout, params->weld_object_radius);

  auto joint_geometry = dep_ctx_->joint_geometry_provider->GetJointGeometry();
  if (!joint_geometry) {
    SendCalibrationStartFailure("Joint geometry not available");
    return;
  }

  if (joint_geometry->type != joint_geometry::Type::CW) {
    SendCalibrationStartFailure("Joint geometry type is not CW");
    return;
  }

  cal_ctx_.wire_diameter      = params->wire_diameter;
  cal_ctx_.stickout           = params->stickout;
  cal_ctx_.weld_object_radius = params->weld_object_radius;
  cal_ctx_.laser_torch_config = ltc_storage_.Get().value();
  cal_ctx_.joint_geometry     = joint_geometry.value();

  dep_ctx_->activity_status->Set(coordination::ActivityStatusE::WELD_OBJECT_CALIBRATION);

  calibration_start_procedure_ = [this](bool success) {
    LOG_INFO("Calibration start procedure completed ");
    dep_ctx_->web_hmi->Send("WeldObjectCalStartRsp", success ? SUCCESS_PAYLOAD : FAILURE_PAYLOAD,
                            success ? std::nullopt : std::make_optional<std::string>("Scanner start failed"),
                            std::nullopt);
    if (!success) {
      LogCalibrationFailure("Scanner start failed");
      Cleanup();
      dep_ctx_->activity_status->Set(coordination::ActivityStatusE::IDLE);
    }
    calibration_start_procedure_ = {};
  };

  dep_ctx_->scanner_client->SetJointGeometry(cal_ctx_.joint_geometry);
}

void CWCalibrationHandler::OnWeldObjectCalStop() {
  LOG_INFO("WeldObjectCalStop received");
  Cleanup();
  dep_ctx_->activity_status->Set(coordination::ActivityStatusE::IDLE);
  dep_ctx_->web_hmi->Send("WeldObjectCalStopRsp", SUCCESS_PAYLOAD, std::nullopt);
}

void CWCalibrationHandler::OnWeldObjectCalTopPos() {
  if (IsBusy()) {
    LOG_INFO("WeldObjectCalTopPos received when busy");
    dep_ctx_->web_hmi->Send("WeldObjectCalTopPosRsp", FAILURE_PAYLOAD, "Busy", std::nullopt);
    return;
  }

  if (dep_ctx_->activity_status->Get() != coordination::ActivityStatusE::WELD_OBJECT_CALIBRATION) {
    LOG_INFO("WeldObjectCalTopPos received when activity status not WELD_OBJECT_CALIBRATION");
    dep_ctx_->web_hmi->Send("WeldObjectCalTopPosRsp", FAILURE_PAYLOAD, "Activity status not WELD_OBJECT_CALIBRATION",
                            std::nullopt);
    return;
  }

  LOG_INFO("WeldObjectCalTopPos received");
  SetProcedureStartTime();

  calibration_top_pos_procedure_ = [this](const common::Point& axis_position) {
    this->OnTopPosProcedureComplete(axis_position);
  };
}

void CWCalibrationHandler::OnTopPosProcedureComplete(const common::Point& axis_position) {
  cal_ctx_.top = Observation{.slide_position = axis_position, .abw_points_lpcs = {}};
  LOG_INFO("Calibration top touch position, recorded at h: {:.2f}, v: {:.2f}", axis_position.horizontal,
           axis_position.vertical);
  dep_ctx_->web_hmi->Send("WeldObjectCalTopPosRsp", SUCCESS_PAYLOAD, std::nullopt);
  calibration_top_pos_procedure_ = {};
}

void CWCalibrationHandler::OnWeldObjectCalLeftPos() {
  if (IsBusy()) {
    LOG_INFO("WeldObjectCalLeftPos received when busy");
    dep_ctx_->web_hmi->Send("WeldObjectCalLeftPosRsp", FAILURE_PAYLOAD, "Busy", std::nullopt);
    return;
  }

  if (dep_ctx_->activity_status->Get() != coordination::ActivityStatusE::WELD_OBJECT_CALIBRATION) {
    LOG_INFO("WeldObjectCalLeftPos received when activity status not WELD_OBJECT_CALIBRATION");
    dep_ctx_->web_hmi->Send("WeldObjectCalLeftPosRsp", FAILURE_PAYLOAD, "Activity status not WELD_OBJECT_CALIBRATION",
                            std::nullopt);
    return;
  }

  LOG_INFO("WeldObjectCalLeftPos received");
  SetProcedureStartTime();

  calibration_left_pos_procedure_ = [this](const std::optional<Observation>& observation) {
    this->OnLeftPosProcedureComplete(observation);
  };
}

void CWCalibrationHandler::OnLeftPosProcedureComplete(const std::optional<Observation>& observation) {
  if (!observation) {
    HandleLeftTouchFailure("observation failed");
    return;
  }

  const auto& obs = observation.value();
  cal_ctx_.left   = obs;
  LOG_INFO("Calibration left touch position, recorded at h: {:.2f}, v: {:.2f}", obs.slide_position.horizontal,
           obs.slide_position.vertical);
  dep_ctx_->web_hmi->Send("WeldObjectCalLeftPosRsp", SUCCESS_PAYLOAD, std::nullopt);
  calibration_left_pos_procedure_ = {};
}

void CWCalibrationHandler::OnWeldObjectCalRightPos() {
  if (IsBusy()) {
    LOG_INFO("WeldObjectCalRightPos received when busy");
    dep_ctx_->web_hmi->Send("WeldObjectCalRightPosRsp", FAILURE_PAYLOAD, "Busy", std::nullopt);
    return;
  }

  if (dep_ctx_->activity_status->Get() != coordination::ActivityStatusE::WELD_OBJECT_CALIBRATION) {
    LOG_INFO("WeldObjectCalRightPos received when activity status not WELD_OBJECT_CALIBRATION");
    dep_ctx_->web_hmi->Send("WeldObjectCalRightPosRsp", FAILURE_PAYLOAD, "Activity status not WELD_OBJECT_CALIBRATION",
                            std::nullopt);
    return;
  }

  LOG_INFO("WeldObjectCalRightPos received");
  SetProcedureStartTime();

  calibration_right_pos_procedure_ = [this](const std::optional<Observation>& observation) {
    this->OnRightPosProcedureComplete(observation);
  };
}

void CWCalibrationHandler::OnRightPosProcedureComplete(const std::optional<Observation>& observation) {
  if (!observation) {
    HandleRightTouchFailure("observation failed");
    return;
  }

  const auto& obs = observation.value();
  cal_ctx_.right  = obs;
  LOG_INFO("Calibration right touch position, recorded at h: {:.2f}, v: {:.2f}", obs.slide_position.horizontal,
           obs.slide_position.vertical);

  if (cal_ctx_.left.slide_position.horizontal < cal_ctx_.right.slide_position.horizontal) {
    LOG_INFO("Walls touched in wrong order");
    std::swap(cal_ctx_.left, cal_ctx_.right);
  }

  const auto top_center = CalculateTopCenter();
  if (!top_center) {
    HandleRightTouchFailure("top_center calculation failed");
    return;
  }

  cal_ctx_.top_center = top_center.value();

  LOG_INFO("Top center calculated to h: {:.2f}, v: {:.2f}", top_center.value().horizontal, top_center.value().vertical);
  dep_ctx_->web_hmi->Send("WeldObjectCalRightPosRsp", SUCCESS_PAYLOAD, std::nullopt);
  calibration_right_pos_procedure_ = {};

  const auto grid_points = GenerateGridPoints();
  StartCalibrationSequence(grid_points);
}

void CWCalibrationHandler::SendCalibrationStartFailure(const std::string& reason) {
  LOG_ERROR("WeldObjectCalStart failed: {}", reason);
  dep_ctx_->web_hmi->Send("WeldObjectCalStartRsp", FAILURE_PAYLOAD, reason, std::nullopt);
  LogCalibrationFailure(reason);
}

void CWCalibrationHandler::HandleTopPosData(const common::Point& axis_position) {
  if (CheckProcedureExpired()) {
    HandleTopTouchFailure("Procedure expired");
    return;
  }

  (*calibration_top_pos_procedure_)(axis_position);
}

void CWCalibrationHandler::HandleLeftPosData(const lpcs::Slice& data, const common::Point& axis_position) {
  if (CheckProcedureExpired()) {
    HandleLeftTouchFailure("Procedure expired (no scanner data)");
    return;
  }

  if (data.confidence == lpcs::SliceConfidence::NO || !data.groove) {
    return;
  }

  Observation observation{.slide_position = axis_position, .abw_points_lpcs = *data.groove};
  (*calibration_left_pos_procedure_)(observation);
}

void CWCalibrationHandler::HandleRightPosData(const lpcs::Slice& data, const common::Point& axis_position) {
  if (CheckProcedureExpired()) {
    HandleRightTouchFailure("Procedure expired (no scanner data)");
    return;
  }

  if (data.confidence == lpcs::SliceConfidence::NO || !data.groove) {
    return;
  }

  Observation observation{.slide_position = axis_position, .abw_points_lpcs = *data.groove};
  (*calibration_right_pos_procedure_)(observation);
}

void CWCalibrationHandler::HandleTopTouchFailure(const std::string& reason) {
  LOG_ERROR("Calibration top touch procedure failed: {}", reason);
  dep_ctx_->web_hmi->Send("WeldObjectCalTopPosRsp", FAILURE_PAYLOAD, reason, std::nullopt);
  LogCalibrationFailure("Top touch failed: " + reason);
  Cleanup();
  dep_ctx_->activity_status->Set(coordination::ActivityStatusE::IDLE);
}

void CWCalibrationHandler::HandleLeftTouchFailure(const std::string& reason) {
  LOG_ERROR("Calibration left touch procedure failed: {}", reason);
  dep_ctx_->web_hmi->Send("WeldObjectCalLeftPosRsp", FAILURE_PAYLOAD, reason, std::nullopt);
  LogCalibrationFailure("Left touch failed: " + reason);
  Cleanup();
  dep_ctx_->activity_status->Set(coordination::ActivityStatusE::IDLE);
}

void CWCalibrationHandler::HandleRightTouchFailure(const std::string& reason) {
  LOG_ERROR("Calibration right touch procedure failed: {}", reason);
  dep_ctx_->web_hmi->Send("WeldObjectCalRightPosRsp", FAILURE_PAYLOAD, reason, std::nullopt);
  LogCalibrationFailure("Right touch failed: " + reason);
  Cleanup();
  dep_ctx_->activity_status->Set(coordination::ActivityStatusE::IDLE);
}

auto CWCalibrationHandler::CalculateTopCenter() -> std::optional<common::Point> {
  const auto& joint_geometry = cal_ctx_.joint_geometry;
  const auto& top_obs        = cal_ctx_.top;
  const auto& left_obs       = cal_ctx_.left;
  const auto& right_obs      = cal_ctx_.right;
  const auto stickout        = cal_ctx_.stickout;
  const auto wire_diameter   = cal_ctx_.wire_diameter;

  // Work around to handle cases when top surfaces are not at the same level
  if (right_obs.abw_points_lpcs.size() < common::ABW_POINTS) {
    LOG_ERROR("Could not compute top surface height diff. No abw points observed on right wall touch point");
    return {};
  }

  // Choise of right obs. is arbitrary. Left could be used as well.
  // This laser plane height diff is only approximation of height diff at torch plane
  double left_to_right_height_diff =
      right_obs.abw_points_lpcs.at(common::ABW_UPPER_RIGHT).y - right_obs.abw_points_lpcs.at(common::ABW_UPPER_LEFT).y;

  return ValidateAndCalculateGrooveTopCenter2(joint_geometry, wire_diameter, stickout, left_obs.slide_position,
                                              right_obs.slide_position, top_obs.slide_position,
                                              left_to_right_height_diff);
}

auto CWCalibrationHandler::GenerateGridPoints() -> std::vector<GridPoint> {
  const auto& left_pos  = cal_ctx_.left.slide_position;
  const auto& right_pos = cal_ctx_.right.slide_position;

  auto touch_depth = cal_ctx_.TouchDepth();
  LOG_INFO("Touch depth calculated to {:.1f} mm", touch_depth);

  return GenerateCalibrationDots(grid_config_, left_pos.horizontal, right_pos.horizontal, right_pos.vertical,
                                 touch_depth);
}

void CWCalibrationHandler::StartCalibrationSequence(std::vector<GridPoint> grid_points) {
  sequence_runner_ = std::make_unique<CalibrationSequenceRunner>(
      timer_, dep_ctx_->kinematics_client, std::move(grid_points),

      // On failure
      [this]() {
        LOG_ERROR("Calibration sequence failed");
        dep_ctx_->web_hmi->Send("WeldObjectCalResult", FAILURE_PAYLOAD, "Calibration sequence failed", std::nullopt);
        LogCalibrationFailure("Calibration sequence failed");
        Cleanup();
        dep_ctx_->activity_status->Set(coordination::ActivityStatusE::IDLE);
        dep_ctx_->kinematics_client->Release();
      },

      // On complete
      [this](const std::vector<Observation>& observations) { this->OnCalibrationSequenceComplete(observations); },

      // On progress
      [this](double progress) {
        LOG_DEBUG("Calibration progress: {}%", std::round(progress * 100));
        dep_ctx_->web_hmi->Send("WeldObjectCalProgress", std::nullopt,
                                nlohmann::json{
                                    {"progress", progress}
        });
      },

      runner_config_);

  sequence_runner_->Start();

  dep_ctx_->activity_status->Set(coordination::ActivityStatusE::CALIBRATION_AUTO_MOVE);
}

void CWCalibrationHandler::OnCalibrationSequenceComplete(const std::vector<Observation>& observations) {
  LOG_INFO("Calibration measurement sequence complete");
  const TorchPlaneInfo torch_plane_info{.top_center_at_torch_plane = cal_ctx_.top_center};

  const auto& ltc = cal_ctx_.laser_torch_config;
  const GeometricConstants geometric_constants{.object_radius            = cal_ctx_.weld_object_radius,
                                               .scanner_mount_angle      = ltc.ScannerMountAngle(),
                                               .ltc_stickout             = ltc.Stickout(),
                                               .ltc_laser_plane_distance = ltc.DistanceLaserTorch()};

  const auto result = TryComputeCalibrationResult(torch_plane_info, geometric_constants, observations);

  ReportCalibrationResult(result, torch_plane_info, geometric_constants, observations);

  Cleanup();
  dep_ctx_->activity_status->Set(coordination::ActivityStatusE::IDLE);
  dep_ctx_->kinematics_client->Release();
}

auto CWCalibrationHandler::TryComputeCalibrationResult(const TorchPlaneInfo& torch_plane_info,
                                                       const GeometricConstants& geometric_constants,
                                                       const std::vector<Observation>& observations)
    -> std::optional<CalibrationResult> {
  try {
    LOG_INFO("Calling calculate with: torch_plane_info={}, geometric_constants={}", ToString(torch_plane_info),
             ToString(geometric_constants));
    return calibration_solver_->Calculate(torch_plane_info, geometric_constants, observations);
  } catch (const std::exception& e) {
    LOG_ERROR("CalibrationSolver::Calculate threw: {}", e.what());
    return std::nullopt;
  }
}

void CWCalibrationHandler::ReportCalibrationResult(const std::optional<CalibrationResult>& result,
                                                   const TorchPlaneInfo& torch_plane_info,
                                                   const GeometricConstants& geometric_constants,
                                                   const std::vector<Observation>& observations) {
  if (result.has_value()) {
    auto calibration_result = StoredCalibrationResult::FromCalibrationResult(
        result.value(), cal_ctx_.weld_object_radius, cal_ctx_.wire_diameter, cal_ctx_.stickout);
    nlohmann::json payload = calibration_result.ToJson();
    if (result->residual_standard_error < RSE_LIMIT) {
      LOG_INFO("Successful calibration result: {}", payload.dump());
      dep_ctx_->web_hmi->Send("WeldObjectCalResult", SUCCESS_PAYLOAD, payload);
    } else {
      LOG_ERROR("RSE too high in calibration: {}", payload.dump());
      dep_ctx_->web_hmi->Send("WeldObjectCalResult", FAILURE_PAYLOAD, "Residual standard error too high", std::nullopt);
    }
  } else {
    LOG_ERROR("Calibration failed");
    dep_ctx_->web_hmi->Send("WeldObjectCalResult", FAILURE_PAYLOAD, "Calibration failed", std::nullopt);
  }

  LogCalibrationRun(torch_plane_info, geometric_constants, observations, result);
}

void CWCalibrationHandler::LogCalibrationRun(const TorchPlaneInfo& tp, const GeometricConstants& gc,
                                             const std::vector<Observation>& obs,
                                             const std::optional<CalibrationResult>& result) {
  auto now           = dep_ctx_->system_clock_now_func();
  bool success       = result.has_value() && result->residual_standard_error < RSE_LIMIT;
  nlohmann::json log = {
      {"timestamp", common::time::TimePointToString(now, common::time::FMT_TS_MS)},
      {"success", success},
      {"torchPlaneInfo", ToJsonLog(tp)},
      {"geometricConstants", ToJsonLog(gc)},
      {"grid_config", ToJsonLog(grid_config_)},
      {"runner_config", ToJsonLog(runner_config_)}
  };

  if (!success) {
    if (!result) {
      log["failureReason"] = "Calibration computation failed";
    } else {
      log["failureReason"] = "Residual standard error too high";
    }
  }
  log["jointGeometry"]       = ToJsonLog(cal_ctx_.joint_geometry);
  log["topCenter"]           = ToJsonLog(cal_ctx_.top_center);
  log["topPosObservation"]   = ToJsonLog(cal_ctx_.top);
  log["leftPosObservation"]  = ToJsonLog(cal_ctx_.left);
  log["rightPosObservation"] = ToJsonLog(cal_ctx_.right);

  for (const auto& item : obs) {
    log["observations"].push_back(ToJsonLog(item));
  }

  if (result) {
    log["calibrationResult"] = ToJsonLog(*result);
  }

  dep_ctx_->calibration_logger->Log(log.dump());
}

void CWCalibrationHandler::LogCalibrationFailure(const std::string& reason) {
  auto now           = dep_ctx_->system_clock_now_func();
  nlohmann::json log = {
      {"timestamp", common::time::TimePointToString(now, common::time::FMT_TS_MS)},
      {"success", false},
      {"failureReason", reason},
      {"jointGeometry", ToJsonLog(cal_ctx_.joint_geometry)},
      {"topCenter", ToJsonLog(cal_ctx_.top_center)},
      {"topPosObservation", ToJsonLog(cal_ctx_.top)},
      {"leftPosObservation", ToJsonLog(cal_ctx_.left)},
      {"rightPosObservation", ToJsonLog(cal_ctx_.right)},
      {"grid_config", ToJsonLog(grid_config_)},
      {"runner_config", ToJsonLog(runner_config_)},
  };

  dep_ctx_->calibration_logger->Log(log.dump());
}

auto CWCalibrationHandler::CheckProcedureExpired() -> bool {
  const auto now      = dep_ctx_->steady_clock_now_func();
  const auto deadline = procedure_start_time_ + std::chrono::seconds(CONFIDENCE_DATA_MAX_WAIT_SEC);
  return now > deadline;
}

void CWCalibrationHandler::SetProcedureStartTime() { procedure_start_time_ = dep_ctx_->steady_clock_now_func(); }

void CWCalibrationHandler::SubscribeWebHmi() {
  dep_ctx_->web_hmi->Subscribe("LaserTorchCalGet",
                               [this](std::string const&, const nlohmann::json&) { this->OnLaserTorchCalGet(); });

  dep_ctx_->web_hmi->Subscribe("LaserTorchCalSet", [this](std::string const&, const nlohmann::json& payload) {
    this->OnLaserTorchCalSet(payload);
  });

  dep_ctx_->web_hmi->Subscribe("WeldObjectCalGet",
                               [this](std::string const&, const nlohmann::json&) { this->OnWeldObjectCalGet(); });

  dep_ctx_->web_hmi->Subscribe("WeldObjectCalSet", [this](std::string const&, const nlohmann::json& payload) {
    this->OnWeldObjectCalSet(payload);
  });

  dep_ctx_->web_hmi->Subscribe("WeldObjectCalStart", [this](std::string const&, const nlohmann::json& payload) {
    this->OnWeldObjectCalStart(payload);
  });

  dep_ctx_->web_hmi->Subscribe("WeldObjectCalStop",
                               [this](std::string const&, const nlohmann::json&) { this->OnWeldObjectCalStop(); });

  dep_ctx_->web_hmi->Subscribe("WeldObjectCalTopPos",
                               [this](std::string const&, const nlohmann::json&) { this->OnWeldObjectCalTopPos(); });

  dep_ctx_->web_hmi->Subscribe("WeldObjectCalLeftPos",
                               [this](std::string const&, const nlohmann::json&) { this->OnWeldObjectCalLeftPos(); });

  dep_ctx_->web_hmi->Subscribe("WeldObjectCalRightPos",
                               [this](std::string const&, const nlohmann::json&) { this->OnWeldObjectCalRightPos(); });
}

}  // namespace calibration
