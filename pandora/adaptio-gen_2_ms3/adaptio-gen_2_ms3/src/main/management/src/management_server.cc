#include "management/src/management_server.h"

#include <algorithm>
#include <cstdint>
#include <functional>
#include <utility>
#include <vector>

#include "common/logging/application_log.h"
#include "coordination/activity_status.h"
#include "coordination/calibration_status.h"
#include "joint_geometry/joint_geometry_provider.h"
#include "tracking/tracking_manager.h"
#include "weld_control/weld_control.h"
#include "weld_control/weld_control_types.h"

using management::ManagementServer;

ManagementServer::ManagementServer(web_hmi::WebHmi* web_hmi,
                                   joint_geometry::JointGeometryProvider* joint_geometry_provider,
                                   coordination::ActivityStatus* activity_status,
                                   coordination::CalibrationStatus* calibration_status,
                                   weld_control::WeldControl* weld_control, std::function<void()> shutdown_handler,
                                   plc_oam_client::PlcOamClient* plc_oam_client,
                                   hwhmi_client::HwHmiClient* hwhmi_client)
    : web_hmi_(web_hmi),
      joint_geometry_provider_(joint_geometry_provider),
      activity_status_(activity_status),
      calibration_status_(calibration_status),
      weld_control_(weld_control),
      shutdown_handler_(shutdown_handler),
      plc_oam_client_(plc_oam_client),
      hwhmi_client_(hwhmi_client) {
  LOG_DEBUG("Creating ManagementServer");
  weld_control_->SetObserver(this);

  plc_oam_client_->SetShutdownCallback([this]() { this->shutdown_handler_(); });

  plc_oam_client_->SetHeartbeatLostCallback([this]() {
    LOG_ERROR("Heartbeat lost from PLC");
    StopActiveFunction();
  });

  hwhmi_client_->SetJoystickControlMode(hwhmi_client::JoystickControlMode::SLIDE_CROSS);

  auto on_weld_control_ready_update =
      [this](const std::vector<std::pair<weld_control::Mode, weld_control::LayerType>>& ready_modes) {
        weld_control_jt_ready_ =
            std::ranges::find(ready_modes, std::make_pair(weld_control::Mode::JOINT_TRACKING,
                                                          weld_control::LayerType::NOT_APPLICABLE)) !=
            ready_modes.end();
        weld_control_abp_ready_ =
            std::ranges::find(ready_modes, std::make_pair(weld_control::Mode::AUTOMATIC_BEAD_PLACEMENT,
                                                          weld_control::LayerType::FILL)) != ready_modes.end();

        weld_control_abp_cap_ready_ =
            std::ranges::find(ready_modes, std::make_pair(weld_control::Mode::AUTOMATIC_BEAD_PLACEMENT,
                                                          weld_control::LayerType::CAP)) != ready_modes.end();

        if (this->UpdateReadyState()) {
          this->SendReadyState();
        };
      };
  weld_control_->SubscribeReady(on_weld_control_ready_update);

  auto check_ready_state = [this]() {
    if (this->UpdateReadyState()) {
      this->SendReadyState();
    };
  };

  auto on_calibration_changed = [this, check_ready_state]() {
    weld_control_->ResetGrooveData();
    check_ready_state();
  };
  calibration_status_->Subscribe(on_calibration_changed);
  activity_status_->Subscribe(check_ready_state);
  joint_geometry_provider_->Subscribe(check_ready_state);

  UpdateReadyState();

  web_hmi_->Subscribe("SubscribeReadyState", [this](std::string const&, nlohmann::json const& payload) {
    this->OnSubscribeReadyState(payload);
  });
  web_hmi_->Subscribe("GetReadyState",
                      [this](std::string const&, nlohmann::json const& payload) { this->OnGetReadyState(payload); });
  web_hmi_->Subscribe("TrackingStart",
                      [this](std::string const&, nlohmann::json const& payload) { this->OnTrackingStart(payload); });
  web_hmi_->Subscribe("TrackingUpdate",
                      [this](std::string const&, nlohmann::json const& payload) { this->OnTrackingUpdate(payload); });
  web_hmi_->Subscribe("Stop", [this](std::string const&, nlohmann::json const& payload) { this->OnStop(payload); });
  web_hmi_->Subscribe("ABPStart",
                      [this](std::string const&, nlohmann::json const& payload) { this->OnABPStart(payload); });
  web_hmi_->Subscribe("ABPStop",
                      [this](std::string const&, nlohmann::json const& payload) { this->OnABPStop(payload); });
  web_hmi_->Subscribe("ABPCapStart",
                      [this](std::string const&, nlohmann::json const& payload) { this->OnABPCapStart(payload); });
  web_hmi_->Subscribe("ABPCapStop",
                      [this](std::string const&, nlohmann::json const& payload) { this->OnABPCapStop(payload); });
  web_hmi_->Subscribe("GetPlcSwVersion",
                      [this](std::string const&, nlohmann::json const& payload) { this->OnGetPlcSwVersion(payload); });
}

void ManagementServer::OnTrackingStart(nlohmann::json const& payload) {
  auto joint_geometry = joint_geometry_provider_->GetJointGeometry();
  if (!joint_geometry.has_value()) {
    // This should not happen since check is part of ready_state
    LOG_ERROR("Cannot start Joint tracking, JointGeometry not available");
    return;
  }

  LOG_DEBUG("ManagementServer Starting joint tracking");

  try {
    auto tracking_mode_str = payload.at("joint_tracking_mode").get<std::string>();
    auto horizontal_offset = payload.at("horizontal_offset").get<float>();
    auto vertical_offset   = payload.at("vertical_offset").get<float>();

    auto tracking_mode = tracking::StringToTrackingMode(tracking_mode_str);
    if (!tracking_mode) {
      LOG_ERROR("Invalid joint_tracking_mode: {}", tracking_mode_str);
      return;
    }

    activity_status_->Set(coordination::ActivityStatusE::TRACKING);
    weld_control_->JointTrackingStart(joint_geometry.value(), tracking_mode.value(), horizontal_offset,
                                      vertical_offset);
  } catch (const nlohmann::json::exception& e) {
    LOG_ERROR("Failed to parse TrackingStart payload: {}", e.what());
  }
}

void ManagementServer::OnSubscribeReadyState(nlohmann::json const& /*payload*/) {
  ready_state_subscribed_ = true;

  SendReadyState();
}

void ManagementServer::OnGetReadyState(nlohmann::json const& /*payload*/) {
  UpdateReadyState();

  std::string state_str;
  switch (ready_state_) {
    case ReadyState::NOT_READY:
      state_str = "not_ready";
      break;
    case ReadyState::NOT_READY_AUTO_CAL_MOVE:
      state_str = "not_ready_auto_cal_move";
      break;
    case ReadyState::TRACKING_READY:
      state_str = "tracking_ready";
      break;
    case ReadyState::ABP_READY:
      state_str = "abp_ready";
      break;
    case ReadyState::ABP_CAP_READY:
      state_str = "abp_cap_ready";
      break;
    case ReadyState::ABP_AND_ABP_CAP_READY:
      state_str = "abp_and_abp_cap_ready";
      break;
  }

  nlohmann::json payload = {
      {"state", state_str}
  };
  nlohmann::json result = {
      {"result", "ok"}
  };
  web_hmi_->Send("GetReadyStateRsp", result, payload);
}

void ManagementServer::OnTrackingUpdate(nlohmann::json const& payload) {
  try {
    auto tracking_mode_str = payload.at("joint_tracking_mode").get<std::string>();
    auto horizontal_offset = payload.at("horizontal_offset").get<float>();
    auto vertical_offset   = payload.at("vertical_offset").get<float>();

    auto tracking_mode = tracking::StringToTrackingMode(tracking_mode_str);
    if (!tracking_mode) {
      LOG_ERROR("Invalid joint_tracking_mode: {}", tracking_mode_str);
      return;
    }

    LOG_DEBUG("ManagementServer::OnTrackingUpdate, joint_tracking_mode={}, horizontal_offset={}, vertical_offset={}",
              tracking_mode_str, horizontal_offset, vertical_offset);

    weld_control_->JointTrackingUpdate(tracking_mode.value(), horizontal_offset, vertical_offset);
  } catch (const nlohmann::json::exception& e) {
    LOG_ERROR("Failed to parse TrackingUpdate payload: {}", e.what());
  }
}

void ManagementServer::OnStop(nlohmann::json const& /*payload*/) {
  if (activity_status_->Get() != coordination::ActivityStatusE::TRACKING) {
    LOG_INFO("ManagementServer::OnStop, incorrect status:{}", static_cast<uint32_t>(activity_status_->Get()));
    return;
  }

  StopActiveFunction();
}

void ManagementServer::OnABPStart(nlohmann::json const& /*payload*/) {
  if (activity_status_->Get() != coordination::ActivityStatusE::TRACKING) {
    LOG_ERROR("Cannot start ABP - status:{}", static_cast<uint32_t>(activity_status_->Get()));
    return;
  }
  LOG_DEBUG("ManagementServer Starting Automatic Bead Placement");
  weld_control_->AutoBeadPlacementStart(weld_control::LayerType::FILL);
}

void ManagementServer::OnABPStop(nlohmann::json const& /*payload*/) {
  LOG_DEBUG("ManagementServer Stopping Automatic Bead Placement");
  weld_control_->AutoBeadPlacementStop();
}

void ManagementServer::OnABPCapStart(nlohmann::json const& /*payload*/) {
  if (activity_status_->Get() != coordination::ActivityStatusE::TRACKING) {
    LOG_ERROR("Cannot start ABP CAP - status:{}", static_cast<uint32_t>(activity_status_->Get()));
    return;
  }
  LOG_DEBUG("ManagementServer Starting Automatic CAP Bead Placement");
  weld_control_->AutoBeadPlacementStart(weld_control::LayerType::CAP);
}

void ManagementServer::OnABPCapStop(nlohmann::json const& /*payload*/) {
  LOG_DEBUG("ManagementServer Stopping Automatic CAP Bead Placement");
  weld_control_->AutoBeadPlacementStop();
}

void ManagementServer::OnGetPlcSwVersion(nlohmann::json const& /*payload*/) {
  plc_oam_client_->GetPlcSwVersion([this](plc_oam_client::PlcSwVersion const& version) {
    nlohmann::json payload = {
        {"major", version.aws_major},
        {"minor", version.aws_minor},
        {"patch", version.aws_patch},
    };
    nlohmann::json result = {
        {"result", "ok"}
    };
    web_hmi_->Send("GetPlcSwVersionRsp", result, payload);
  });
}

void ManagementServer::StopActiveFunction() {
  if (activity_status_->Get() != coordination::ActivityStatusE::TRACKING) {
    return;
  }

  LOG_DEBUG("ManagementServer Stopping joint tracking / abp");
  weld_control_->Stop();

  activity_status_->Set(coordination::ActivityStatusE::IDLE);
}

auto ManagementServer::UpdateReadyState() -> bool {
  bool busy_from_webhmi{};

  switch (activity_status_->Get()) {
    case coordination::ActivityStatusE::IDLE:
    case coordination::ActivityStatusE::TRACKING:
      busy_from_webhmi = false;
      break;
    default:
      busy_from_webhmi = true;
      break;
  }
  auto calibration_valid = calibration_status_->CalibrationValid();
  auto joint_geometry    = joint_geometry_provider_->GetJointGeometry();

  ReadyState new_ready_state = ReadyState::NOT_READY;
  if (activity_status_->Get() == coordination::ActivityStatusE::CALIBRATION_AUTO_MOVE) {
    new_ready_state = ReadyState::NOT_READY_AUTO_CAL_MOVE;
  } else {
    if (!busy_from_webhmi && calibration_valid && joint_geometry.has_value() && weld_control_jt_ready_) {
      new_ready_state = ReadyState::TRACKING_READY;
    }

    if (new_ready_state == ReadyState::TRACKING_READY) {
      if (weld_control_abp_ready_ && weld_control_abp_cap_ready_) {
        new_ready_state = ReadyState::ABP_AND_ABP_CAP_READY;
      } else if (weld_control_abp_ready_) {
        new_ready_state = ReadyState::ABP_READY;
      } else if (weld_control_abp_cap_ready_) {
        new_ready_state = ReadyState::ABP_CAP_READY;
      }
    }
  }

  if (new_ready_state != ready_state_) {
    LOG_INFO(
        "Changed ready state {} -> {}, cal: {}, jg: {}, busy_from_webhmi: {}, "
        "weld_control_jt_ready: {}, weld_control_abp_ready: {}, weld_control_abp_cap_ready: {}, activity_status: {}",
        ToString(ready_state_), ToString(new_ready_state), calibration_valid, joint_geometry.has_value(),
        busy_from_webhmi, weld_control_jt_ready_, weld_control_abp_ready_, weld_control_abp_cap_ready_,
        ActivityStatusToString(activity_status_->Get()));

    ready_state_ = new_ready_state;
    return true;
  }
  LOG_INFO(
      "Unchanged ready state: {}, cal: {}, jg: {}, busy_from_webhmi: {}, weld_control_jt_ready: {}, "
      "weld_control_abp_ready: {}, weld_control_abp_cap_ready: {}, activity_status: {}",
      ToString(ready_state_), calibration_valid, joint_geometry.has_value(), busy_from_webhmi, weld_control_jt_ready_,
      weld_control_abp_ready_, weld_control_abp_cap_ready_, ActivityStatusToString(activity_status_->Get()));

  return false;
}

void ManagementServer::SendReadyState() {
  if (!ready_state_subscribed_) {
    return;
  }

  std::string state_str;
  switch (ready_state_) {
    case ReadyState::NOT_READY:
      state_str = "not_ready";
      break;
    case ReadyState::NOT_READY_AUTO_CAL_MOVE:
      state_str = "not_ready_auto_cal_move";
      break;
    case ReadyState::TRACKING_READY:
      state_str = "tracking_ready";
      break;
    case ReadyState::ABP_READY:
      state_str = "abp_ready";
      break;
    case ReadyState::ABP_CAP_READY:
      state_str = "abp_cap_ready";
      break;
    case ReadyState::ABP_AND_ABP_CAP_READY:
      state_str = "abp_and_abp_cap_ready";
      break;
  }

  nlohmann::json payload = {
      {"state", state_str}
  };
  web_hmi_->Send("ReadyState", std::nullopt, payload);
}

void ManagementServer::OnNotifyHandoverToManual() {
  LOG_DEBUG("Notify Hanover to manual");
  web_hmi_->Send("NotifyHandoverToManual", std::nullopt, nlohmann::json::object());
}

void ManagementServer::OnGrooveDataTimeout() {
  LOG_DEBUG("Groove data timeout, stop joint tracking / abp");
  web_hmi_->Send("TrackingStoppedGrooveDataTimeout", std::nullopt, nlohmann::json::object());
  StopActiveFunction();
}

void ManagementServer::OnError() {
  LOG_DEBUG("OnError, stop joint tracking / abp");
  web_hmi_->Send("ScannerError", std::nullopt, nlohmann::json::object());
  StopActiveFunction();
}

void ManagementServer::OnGracefulStop() {
  LOG_DEBUG("Graceful Stop");
  web_hmi_->Send("GracefulStop", std::nullopt, nlohmann::json::object());
  StopActiveFunction();
}
