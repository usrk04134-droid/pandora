#include "manual_weld.h"

#include <algorithm>
#include <ranges>

#include "common/logging/application_log.h"
#include "weld_data_set.h"
#include "weld_process_parameters.h"

namespace {
const uint32_t WELD_DATA_TIMER_MS      = 200;
const std::string WELD_DATA_TIMER_NAME = "manual_weld_data_timer";

const auto SUCCESS_PAYLOAD = nlohmann::json{
    {"result", "ok"}
};
const auto FAILURE_PAYLOAD = nlohmann::json{
    {"result", "fail"}
};
}  // namespace

using weld_control::ArcState;
using weld_control::ManualWeld;

ManualWeld::ManualWeld(web_hmi::WebHmi* web_hmi, hwhmi_client::HwHmiClient* hwhmi_client,
                       weld_system::WeldSystemClient* weld_system_client, WeldSequenceConfig* weld_sequence_config,
                       coordination::ActivityStatus* activity_status, zevs::Timer* timer)
    : web_hmi_(web_hmi),
      weld_system_client_(weld_system_client),
      weld_sequence_config_(weld_sequence_config),
      activity_status_(activity_status),
      timer_(timer) {
  weld_systems_[weld_system::WeldSystemId::ID1] = {};
  weld_systems_[weld_system::WeldSystemId::ID2] = {};

  weld_system_state_sub_handle_ = weld_system_client_->SubscribeWeldSystemStateChanges(
      [this](weld_system::WeldSystemId id, weld_system::WeldSystemState state) { OnWeldSystemStateChange(id, state); });

  hwhmi_client->SetButtonStateCallback(
      [this](hwhmi_client::ButtonState button_state) { OnButtonStateChange(button_state); });

  web_hmi_->Subscribe("SelectWeldDataSet",
                      [this](std::string const&, nlohmann::json const& payload) { OnSelectWeldDataSet(payload); });
  web_hmi_->Subscribe("SubscribeArcState",
                      [this](std::string const&, nlohmann::json const& payload) { OnSubscribeArcState(payload); });
  web_hmi_->Subscribe("GetArcState",
                      [this](std::string const&, nlohmann::json const& payload) { OnGetArcState(payload); });
  web_hmi_->Subscribe("SubscribeWeldData",
                      [this](std::string const&, nlohmann::json const& payload) { OnSubscribeWeldData(payload); });
  web_hmi_->Subscribe("AdjustVoltage",
                      [this](std::string const&, nlohmann::json const& payload) { OnAdjustVoltage(payload); });
  web_hmi_->Subscribe("AdjustCurrent",
                      [this](std::string const&, nlohmann::json const& payload) { OnAdjustCurrent(payload); });
}

ManualWeld::~ManualWeld() {
  weld_system_client_->UnSubscribeWeldSystemStateChanges(weld_system_state_sub_handle_);
  if (weld_data_timer_id_.has_value()) {
    timer_->Cancel(weld_data_timer_id_.value());
  }
}

void ManualWeld::OnSelectWeldDataSet(nlohmann::json const& payload) {
  if (state_ == ArcState::STARTING || state_ == ArcState::ACTIVE) {
    web_hmi_->Send("SelectWeldDataSetRsp", FAILURE_PAYLOAD, "Cannot change weld data set while welding", std::nullopt);
    return;
  }

  int id  = 0;
  bool ok = payload.contains("id") && payload.at("id").get_to(id);

  if (!ok) {
    web_hmi_->Send("SelectWeldDataSetRsp", FAILURE_PAYLOAD, "Missing or invalid 'id' field", std::nullopt);
    return;
  }

  auto const weld_data_sets = weld_sequence_config_->GetWeldDataSets();
  auto const wds_it = std::ranges::find_if(weld_data_sets, [id](WeldDataSet const& wds) { return wds.Id() == id; });

  if (wds_it == weld_data_sets.end()) {
    LOG_ERROR("ManualWeld: WeldDataSet with id {} not found", id);
    web_hmi_->Send("SelectWeldDataSetRsp", FAILURE_PAYLOAD, "Weld data set not found", std::nullopt);
    return;
  }

  auto const weld_process_parameters = weld_sequence_config_->GetWeldProcessParameters();
  auto const ws1_wpp_it =
      std::ranges::find_if(weld_process_parameters,
                           [&wds = *wds_it](WeldProcessParameters const& wpp) { return wpp.Id() == wds.Ws1WppId(); });
  auto const ws2_wpp_it =
      std::ranges::find_if(weld_process_parameters,
                           [&wds = *wds_it](WeldProcessParameters const& wpp) { return wpp.Id() == wds.Ws2WppId(); });

  if (ws1_wpp_it == weld_process_parameters.end() || ws2_wpp_it == weld_process_parameters.end()) {
    LOG_ERROR("ManualWeld: WeldProcessParameters not found for WeldDataSet {}", id);
    web_hmi_->Send("SelectWeldDataSetRsp", FAILURE_PAYLOAD, "Weld process parameters not found", std::nullopt);
    return;
  }

  auto const ws1_settings = ws1_wpp_it->ToWeldSystemSettings();
  auto const ws2_settings = ws2_wpp_it->ToWeldSystemSettings();

  if (!ws1_settings.has_value() || !ws2_settings.has_value()) {
    LOG_ERROR("ManualWeld: Failed to convert WeldProcessParameters to WeldSystemSettings");
    web_hmi_->Send("SelectWeldDataSetRsp", FAILURE_PAYLOAD, "Failed to convert weld process parameters", std::nullopt);
    return;
  }

  weld_system_client_->SetWeldSystemData(weld_system::WeldSystemId::ID1, ws1_settings.value());
  weld_system_client_->SetWeldSystemData(weld_system::WeldSystemId::ID2, ws2_settings.value());

  weld_systems_[weld_system::WeldSystemId::ID1].working_settings = ws1_settings.value();
  weld_systems_[weld_system::WeldSystemId::ID2].working_settings = ws2_settings.value();

  LOG_INFO("ManualWeld: Selected WeldDataSet id: {} (name: {})", id, wds_it->Name());

  web_hmi_->Send("SelectWeldDataSetRsp", SUCCESS_PAYLOAD, std::nullopt);

  SetState(ArcState::CONFIGURED);
  UpdateReadiness();
}

void ManualWeld::OnSubscribeArcState(nlohmann::json const& /*payload*/) {
  arc_state_subscribed_ = true;
  PushArcState();
}

void ManualWeld::OnGetArcState(nlohmann::json const& /*payload*/) {
  nlohmann::json payload = {
      {"state", ArcStateToString(state_)}
  };
  web_hmi_->Send("GetArcStateRsp", SUCCESS_PAYLOAD, payload);
}

void ManualWeld::OnSubscribeWeldData(nlohmann::json const& /*payload*/) {
  weld_data_subscribed_ = true;
  web_hmi_->Send("SubscribeWeldDataRsp", SUCCESS_PAYLOAD, std::nullopt);
}

void ManualWeld::OnAdjustVoltage(nlohmann::json const& payload) {
  if (state_ != ArcState::READY && state_ != ArcState::ACTIVE) {
    return;
  }

  try {
    auto const ws_id = payload.at("wsId").get<int>();
    auto const delta = payload.at("delta").get<float>();
    auto const id    = static_cast<weld_system::WeldSystemId>(ws_id);
    auto it          = weld_systems_.find(id);

    if (it == weld_systems_.end()) {
      LOG_ERROR("ManualWeld::AdjustVoltage: invalid wsId {}", ws_id);
      web_hmi_->Send("AdjustVoltageRsp", FAILURE_PAYLOAD, "Invalid weld system id", std::nullopt);
      return;
    }

    it->second.working_settings.voltage += static_cast<double>(delta);
    weld_system_client_->SetWeldSystemData(id, it->second.working_settings);

    LOG_INFO("ManualWeld: AdjustVoltage ws{} delta={} new={}", ws_id, delta, it->second.working_settings.voltage);

    web_hmi_->Send("AdjustVoltageRsp", SUCCESS_PAYLOAD, std::nullopt);
  } catch (nlohmann::json::exception const& e) {
    LOG_ERROR("ManualWeld::AdjustVoltage: failed to parse payload: {}", e.what());
    web_hmi_->Send("AdjustVoltageRsp", FAILURE_PAYLOAD, "Invalid payload", std::nullopt);
  }
}

void ManualWeld::OnAdjustCurrent(nlohmann::json const& payload) {
  if (state_ != ArcState::READY && state_ != ArcState::ACTIVE) {
    return;
  }

  try {
    auto const ws_id = payload.at("wsId").get<int>();
    auto const delta = payload.at("delta").get<float>();
    auto const id    = static_cast<weld_system::WeldSystemId>(ws_id);
    auto it          = weld_systems_.find(id);

    if (it == weld_systems_.end()) {
      LOG_ERROR("ManualWeld::AdjustCurrent: invalid wsId {}", ws_id);
      web_hmi_->Send("AdjustCurrentRsp", FAILURE_PAYLOAD, "Invalid weld system id", std::nullopt);
      return;
    }

    it->second.working_settings.current += static_cast<double>(delta);
    weld_system_client_->SetWeldSystemData(id, it->second.working_settings);

    LOG_INFO("ManualWeld: AdjustCurrent ws{} delta={} new={}", ws_id, delta, it->second.working_settings.current);

    web_hmi_->Send("AdjustCurrentRsp", SUCCESS_PAYLOAD, std::nullopt);
  } catch (nlohmann::json::exception const& e) {
    LOG_ERROR("ManualWeld::AdjustCurrent: failed to parse payload: {}", e.what());
    web_hmi_->Send("AdjustCurrentRsp", FAILURE_PAYLOAD, "Invalid payload", std::nullopt);
  }
}

void ManualWeld::OnButtonStateChange(hwhmi_client::ButtonState button_state) {
  switch (button_state) {
    case hwhmi_client::ButtonState::START:
      if (state_ == ArcState::READY) {
        weld_system_client_->WeldControlCommand(weld_system::WeldControlCommand::START);
        SetState(ArcState::STARTING);
      }
      break;
    case hwhmi_client::ButtonState::STOP:
      if (state_ == ArcState::STARTING || state_ == ArcState::ACTIVE) {
        weld_system_client_->WeldControlCommand(weld_system::WeldControlCommand::STOP);
      }
      break;
    default:
      break;
  }
}

void ManualWeld::OnWeldSystemStateChange(weld_system::WeldSystemId id, weld_system::WeldSystemState state) {
  auto it = weld_systems_.find(id);
  if (it == weld_systems_.end()) {
    return;
  }

  it->second.state = state;

  if (state_ == ArcState::STARTING && state == weld_system::WeldSystemState::ARCING) {
    SetState(ArcState::ACTIVE);
    return;
  }

  if (state_ == ArcState::STARTING) {
    // Roll back only when the weld system reports a definitive non-welding state
    // (READY_TO_START, INIT, ERROR). IN_WELDING_SEQUENCE is a normal transition
    // toward ARCING and must not trigger a rollback.
    bool const is_rollback_state =
        (state == weld_system::WeldSystemState::READY_TO_START || state == weld_system::WeldSystemState::INIT ||
         state == weld_system::WeldSystemState::ERROR);
    if (is_rollback_state) {
      bool const all_ready = std::ranges::all_of(weld_systems_, [](auto const& pair) {
        return pair.second.state == weld_system::WeldSystemState::READY_TO_START;
      });
      SetState(all_ready ? ArcState::READY : ArcState::CONFIGURED);
    }
    return;
  }

  if (state_ == ArcState::ACTIVE) {
    bool const any_arcing = std::ranges::any_of(
        weld_systems_, [](auto const& pair) { return pair.second.state == weld_system::WeldSystemState::ARCING; });
    if (!any_arcing) {
      SetState(ArcState::READY);
      return;
    }
  }

  UpdateReadiness();
}

void ManualWeld::SetState(ArcState new_state) {
  if (new_state == state_) {
    return;
  }

  LOG_INFO("ManualWeld: {} -> {}", ArcStateToString(state_), ArcStateToString(new_state));

  auto const old_state = state_;
  state_               = new_state;

  if (new_state == ArcState::ACTIVE) {
    activity_status_->Set(coordination::ActivityStatusE::MANUAL_WELDING);
    if (!weld_data_timer_id_.has_value()) {
      weld_data_timer_id_ =
          timer_->RequestPeriodic(&ManualWeld::OnWeldDataTimer, this, WELD_DATA_TIMER_MS, WELD_DATA_TIMER_NAME);
    }
  } else if (old_state == ArcState::ACTIVE) {
    activity_status_->Set(coordination::ActivityStatusE::IDLE);
    if (weld_data_timer_id_.has_value()) {
      timer_->Cancel(weld_data_timer_id_.value());
      weld_data_timer_id_.reset();
    }
  }

  PushArcState();
}

void ManualWeld::PushArcState() {
  if (!arc_state_subscribed_) {
    return;
  }
  nlohmann::json payload = {
      {"state", ArcStateToString(state_)}
  };
  web_hmi_->Send("ArcState", std::nullopt, payload);
}

void ManualWeld::UpdateReadiness() {
  if (state_ != ArcState::CONFIGURED && state_ != ArcState::READY) {
    return;
  }

  bool const all_ready = std::ranges::all_of(weld_systems_, [](auto const& pair) {
    return pair.second.state == weld_system::WeldSystemState::READY_TO_START;
  });

  if (all_ready && state_ == ArcState::CONFIGURED) {
    SetState(ArcState::READY);
  } else if (!all_ready && state_ == ArcState::READY) {
    SetState(ArcState::CONFIGURED);
  }
}

void ManualWeld::OnWeldDataTimer() { RequestWeldData(); }

void ManualWeld::RequestWeldData() {
  pending_weld_data_responses_ = static_cast<int>(weld_systems_.size());
  for (auto const& [ws_id, info] : weld_systems_) {
    weld_system_client_->GetWeldSystemData(
        ws_id, [this](weld_system::WeldSystemId id, weld_system::WeldSystemData const& data) {
          auto it = weld_systems_.find(id);
          if (it != weld_systems_.end()) {
            it->second.measured_voltage = static_cast<float>(data.voltage);
            it->second.measured_current = static_cast<float>(data.current);
          }
          if (--pending_weld_data_responses_ == 0) {
            PushWeldData();
          }
        });
  }
}

void ManualWeld::PushWeldData() {
  if (!weld_data_subscribed_) {
    return;
  }

  nlohmann::json weld_data_array = nlohmann::json::array();
  for (auto const& [ws_id, info] : weld_systems_) {
    weld_data_array.push_back({
        {"wsId",            static_cast<int>(ws_id)                          },
        {"measuredVoltage", info.measured_voltage                            },
        {"measuredCurrent", info.measured_current                            },
        {"workingVoltage",  static_cast<float>(info.working_settings.voltage)},
        {"workingCurrent",  static_cast<float>(info.working_settings.current)},
    });
  }

  nlohmann::json payload = {
      {"weldData", weld_data_array}
  };
  web_hmi_->Send("WeldData", std::nullopt, payload);
}
