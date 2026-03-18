#pragma once

#include <map>
#include <nlohmann/json.hpp>
#include <optional>
#include <string>

#include "common/zevs/zevs_socket.h"
#include "coordination/activity_status.h"
#include "hwhmi_client/hwhmi_client.h"
#include "web_hmi/web_hmi.h"
#include "weld_sequence_config.h"
#include "weld_system_client/weld_system_client.h"
#include "weld_system_client/weld_system_types.h"

namespace weld_control {

enum class ArcState {
  IDLE,        // No weld data set selected
  CONFIGURED,  // WDS selected; waiting for power sources to report READY_TO_START
  READY,       // WDS selected + all configured power sources READY_TO_START
  STARTING,    // Start commanded to PLC, waiting for arc confirmation
  ACTIVE,      // At least one weld system is arcing
};

inline auto ArcStateToString(ArcState state) -> std::string {
  switch (state) {
    case ArcState::IDLE:
      return "idle";
    case ArcState::CONFIGURED:
      return "configured";
    case ArcState::READY:
      return "ready";
    case ArcState::STARTING:
      return "starting";
    case ArcState::ACTIVE:
      return "active";
    default:
      return "unknown";
  }
}

class ManualWeld {
 public:
  ManualWeld(web_hmi::WebHmi* web_hmi, hwhmi_client::HwHmiClient* hwhmi_client,
             weld_system::WeldSystemClient* weld_system_client, WeldSequenceConfig* weld_sequence_config,
             coordination::ActivityStatus* activity_status, zevs::Timer* timer);
  ~ManualWeld();

 private:
  // WebHMI handlers
  void OnSelectWeldDataSet(nlohmann::json const& payload);
  void OnSubscribeArcState(nlohmann::json const& payload);
  void OnGetArcState(nlohmann::json const& payload);
  void OnSubscribeWeldData(nlohmann::json const& payload);
  void OnAdjustVoltage(nlohmann::json const& payload);
  void OnAdjustCurrent(nlohmann::json const& payload);

  // Hardware / PLC callbacks
  void OnButtonStateChange(hwhmi_client::ButtonState button_state);
  void OnWeldSystemStateChange(weld_system::WeldSystemId id, weld_system::WeldSystemState state);

  // State management
  void SetState(ArcState new_state);
  void PushArcState();
  void UpdateReadiness();

  // Weld data
  void OnWeldDataTimer();
  void RequestWeldData();
  void PushWeldData();

  web_hmi::WebHmi* web_hmi_;
  weld_system::WeldSystemClient* weld_system_client_;
  WeldSequenceConfig* weld_sequence_config_;
  coordination::ActivityStatus* activity_status_;
  zevs::Timer* timer_;

  ArcState state_{ArcState::IDLE};
  bool arc_state_subscribed_{false};
  bool weld_data_subscribed_{false};
  uint32_t weld_system_state_sub_handle_{0};
  std::optional<uint32_t> weld_data_timer_id_;
  int pending_weld_data_responses_{0};

  struct WeldSystemInfo {
    weld_system::WeldSystemState state{weld_system::WeldSystemState::INIT};
    weld_system::WeldSystemSettings working_settings{};
    float measured_voltage{0.0f};
    float measured_current{0.0f};
  };
  std::map<weld_system::WeldSystemId, WeldSystemInfo> weld_systems_;
};

}  // namespace weld_control
