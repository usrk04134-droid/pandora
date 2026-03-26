
#include "weld_control_impl.h"

#include <algorithm>
#include <cassert>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <filesystem>
#include <functional>
#include <nlohmann/json.hpp>
#include <nlohmann/json_fwd.hpp>
#include <numbers>
#include <optional>
#include <string>
#include <utility>
#include <vector>

#include "abp_parameters.h"
#include "bead_control/bead_control.h"
#include "bead_control/bead_control_types.h"
#include "common/clock_functions.h"
#include "common/groove/groove.h"
#include "common/groove/point.h"
#include "common/logging/application_log.h"
#include "common/logging/component_logger.h"
#include "common/math/math.h"
#include "common/time/format.h"
#include "common/zevs/zevs_socket.h"
#include "delay_buffer.h"
#include "event_handler/event_codes.h"
#include "event_handler/event_handler.h"
#include "image_logging/image_logging_manager.h"
#include "joint_geometry/joint_geometry.h"
#include "kinematics/kinematics_client.h"
#include "lpcs/lpcs_point.h"
#include "lpcs/lpcs_slice.h"
#include "macs/macs_slice.h"
#include "scanner_client/scanner_client.h"
#include "slice_translator/slice_translator_service_v2.h"
#include "tracking/tracking_manager.h"
#include "web_hmi/web_hmi.h"
#include "weld_calculations.h"
#include "weld_control/src/confident_slice_buffer.h"
#include "weld_control/src/settings_provider.h"
#include "weld_control/src/weld_sequence_config.h"
#include "weld_control/weld_control.h"
#include "weld_control/weld_control_types.h"
#include "weld_data_set.h"
#include "weld_process_parameters.h"
#include "weld_system_client/weld_system_client.h"
#include "weld_system_client/weld_system_types.h"

namespace {

auto const TWO_PI = 2.0 * std::numbers::pi;

// With 1 seconds rate-limit there will be ~175MB data stored per day if each log entry contains 2kB data
auto const LOG_RATE_LIMIT                             = std::chrono::milliseconds(1000);
auto const LOG_1_DECIMALS                             = 1;
auto const LOG_3_DECIMALS                             = 3;
auto const HORIZONTAL_VELOCITY                        = 3.667;                             // 22 cm/min
auto const VERTICAL_VELOCITY                          = 3.667;                             // 22 cm/min
auto const VERTICAL_VELOCITY_ARCING                   = 2.0;                               // 12 cm/min
auto const REPOSITION_IN_POSITION_TOLERANCE           = 2.;                                // in mm
auto const WELD_OBJECT_MOVING_THRESHOLD               = common::math::CmMinToMmSec(0.25);  // linear velocity in mm/sec
auto const WELD_AXIS_POSITION_MAX_REVERSE_THRESHOLD   = 10;                                // in mm
auto const WELD_OBJECT_DISTANCE_MAX_REVERSE_THRESHOLD = 5;                                 // in mm
auto const WELD_AXIS_POSITION_OUT_OF_BOUNDS_THRESHOLD = 1.0 + common::math::DegToRad(3.0) / TWO_PI;
auto const FIXED_HANDOVER_GRACE                       = std::chrono::seconds(3);
auto const READY_FOR_CAP_CONFIDENT_BUFFER_FILL_RATIO  = 0.95;
auto const JOINT_GEOMETRY_DEPTH_MIN_VALID_MM          = 10.0;

auto ToWeldAxisState(kinematics::State state) -> weld_control::WeldAxisState {
  switch (state) {
    case kinematics::State::HOMED:
      return weld_control::WeldAxisState::INITIALIZED;
    case kinematics::State::INIT:
    default:
      return weld_control::WeldAxisState::NOT_INITIALIZED;
  }
}
// Map depth 0..joint_geometry_depth to gain 1..max_gain (linear)
inline auto DepthScaledGain(double depth, double joint_geometry_depth_mm, double max_gain) -> double {
  if (max_gain <= 1.0 || joint_geometry_depth_mm < JOINT_GEOMETRY_DEPTH_MIN_VALID_MM) {
    return 1.0;
  }
  auto const depth_in_range = std::clamp(depth, 0.0, joint_geometry_depth_mm);
  return 1.0 + ((max_gain - 1.0) * depth_in_range / joint_geometry_depth_mm);
}

// Scale the "deviation from 1.0" by gain
inline auto ApplyAdaptivityGain(double ratio, double gain) -> double { return 1.0 + (ratio - 1.0) * gain; }

auto WeldAxisStateToString(weld_control::WeldAxisState state) -> std::string {
  switch (state) {
    case weld_control::WeldAxisState::NOT_INITIALIZED:
      return "not_initialized";
    case weld_control::WeldAxisState::INITIALIZED:
      return "initialized";
    default:
      break;
  }
}
auto StateToString(weld_control::State state) -> std::string {
  switch (state) {
    case weld_control::State::IDLE:
      return "idle";
    case weld_control::State::WELDING:
      return "welding";
    default:
      break;
  }
  return "invalid";
}

const auto SUCCESS_PAYLOAD = nlohmann::json{
    {"result", "ok"}
};
const auto FAILURE_PAYLOAD = nlohmann::json{
    {"result", "fail"}
};

}  // namespace

namespace weld_control {

WeldControlImpl::WeldControlImpl(
    const Configuration& config, WeldSequenceConfig* weld_sequence_config, SettingsProvider* settings_provider,
    web_hmi::WebHmi* web_hmi, kinematics::KinematicsClient* kinematics_client, std::filesystem::path const& path_logs,
    weld_system::WeldSystemClient* weld_system_client, tracking::TrackingManager* tracking_manager,
    scanner_client::ScannerClient* scanner_client, zevs::Timer* timer, event::EventHandler* event_handler,
    bead_control::BeadControl* bead_control, DelayBuffer* delay_buffer,
    clock_functions::SystemClockNowFunc system_clock_now_func,
    clock_functions::SteadyClockNowFunc steady_clock_now_func,
    image_logging::ImageLoggingManager* image_logging_manager,
    slice_translator::SliceTranslatorServiceV2* slice_translator_v2, SQLite::Database* db, WeldControlMetrics* metrics)
    : config_(config),
      weld_sequence_config_(weld_sequence_config),
      settings_provider_(settings_provider),
      web_hmi_(web_hmi),
      kinematics_client_(kinematics_client),
      weld_system_client_(weld_system_client),
      tracking_manager_(tracking_manager),
      scanner_client_(scanner_client),
      timer_(timer),
      event_handler_(event_handler),
      image_logging_manager_(image_logging_manager),
      slice_translator_v2_(slice_translator_v2),
      bead_control_(bead_control),
      delay_buffer_(delay_buffer),
      confident_slice_buffer_(config.weld_data_persistent_storage ? db : nullptr),
      groove_profile_buffer_(config.weld_data_persistent_storage ? db : nullptr),
      weld_systems_{
          {weld_system::WeldSystemId::ID1, {}},
          {weld_system::WeldSystemId::ID2, {}}
},
      system_clock_now_func_(system_clock_now_func),
      steady_clock_now_func_(steady_clock_now_func),
      smooth_weld_speed_(config.adaptivity.gaussian_filter.kernel_size, config.adaptivity.gaussian_filter.sigma),
      smooth_ws2_current_(config.adaptivity.gaussian_filter.kernel_size, config.adaptivity.gaussian_filter.sigma),
      metrics_(metrics),
      weld_observability_(slides_actual_, cached_mcs_, vertical_offset_, web_hmi_) {
  weld_sequence_config_->SubscribeToUpdates([this] {
    UpdateBeadControlParameters();
    CheckReady();
  });

  LOG_INFO("config: {{{}}}", ConfigurationToString(config_));

  metrics_->Setup(confident_slice_buffer_);

  settings_provider_->SubscribeToUpdates([this] {
    auto const settings = settings_provider_->GetSettings();
    if (!settings.has_value()) {
      LOG_ERROR("no settings available!");
      return;
    }

    if (IsLW() || (settings->UseEdgeSensor() == settings_.UseEdgeSensor() &&
                   settings->EdgeSensorPlacementValue() == settings_.EdgeSensorPlacementValue())) {
      return;
    }

    settings_ = settings.value();
    LOG_INFO("Settings updated: {}", settings_.ToString());
    UpdateReady();
  });

  settings_ = settings_provider_->GetSettings().value_or(Settings{});

  kinematics_client_->SubscribeStateChanges(
      [this](const kinematics::StateChange& data) {
        auto new_state = ToWeldAxisState(data.weld_axis_state);
        if (weld_axis_state_ != new_state) {
          LOG_INFO("Weld-axis state changed from {} -> {}",
                   weld_axis_state_ ? WeldAxisStateToString(*weld_axis_state_) : "unknown",
                   WeldAxisStateToString(new_state));
        }

        if (weld_axis_state_) {
          switch (new_state) {
            case WeldAxisState::INITIALIZED:
              /* stored position are no longer valid -> reset groove data */
              last_weld_axis_position_ = {};
              cached_segment_.position = 0.0;
              ResetGrooveDataHomed();
              break;
            case WeldAxisState::NOT_INITIALIZED:
            default:
              break;
          }
        }

        weld_axis_state_ = new_state;
        CheckReady();
      },
      [this](const kinematics::EdgeState& state) {
        if (IsEdgeSensorPresent() && state == GetEdgeSensorState()) {
          return;
        }

        if (!IsLW() && UseEdgeSensor() && IsEdgeSensorPresent() && state == kinematics::EdgeState::NOT_AVAILABLE) {
          confident_slice_buffer_.Clear();

          if (state_ == State::WELDING) {
            LOG_ERROR("Edge sensor is no longer available when in welding state!");
            event_handler_->SendEvent(event::EDGE_SENSOR_LOST, std::nullopt);
            observer_->OnError();
          }
        }

        LOG_INFO("Edge state changed from {} -> {}", kinematics::EdgeStateToString(GetEdgeSensorState()),
                 kinematics::EdgeStateToString(state));

        edge_state_ = state;

        if (UseEdgeSensor()) {
          CheckReady();
        }
      },
      [this]() {
        if (!cached_linear_object_distance_.has_value()) {
          // Should not happen
          LOG_ERROR("Torch at entry position but no linear object distance");
          return;
        }

        auto linear_position = cached_linear_object_distance_.value();
        // Get position when laser line is on start of weld object
        torch_position_when_laser_on_entry_edge_ = linear_position - cached_distance_from_torch_to_scanner_;

        LOG_INFO("Torch at entry position: {:.5f} torch position when laser on entry: {:.5f}", linear_position,
                 torch_position_when_laser_on_entry_edge_);
      });

  auto weld_control_status = [this](std::string const& /*topic*/, const nlohmann::json& /*payload*/) {
    this->GetWeldControlStatus();
  };
  web_hmi_->Subscribe("GetWeldControlStatus", weld_control_status);

  auto clear_weld_session = [this](std::string const& /*topic*/, const nlohmann::json& /*payload*/) {
    auto ok = false;
    std::string msg;

    if (mode_ == Mode::AUTOMATIC_BEAD_PLACEMENT) {
      msg = "Unable to clear weld session with ABP active.";
    } else {
      ok = true;
    }

    if (ok) {
      ClearWeldSession();

    } else {
      LOG_ERROR("Failed to clear weld session ({})", msg);
    }

    web_hmi_->Send("ClearWeldSessionRsp", ok ? SUCCESS_PAYLOAD : FAILURE_PAYLOAD,
                   ok ? std::optional<std::string>{} : "Failed to clear weld session" + msg, std::nullopt);
  };
  web_hmi_->Subscribe("ClearWeldSession", clear_weld_session);

  auto weld_system_state_change = [this](weld_system::WeldSystemId id, weld_system::WeldSystemState state) {
    this->WeldSystemStateChange(id, state);
  };

  weld_system_client_->SubscribeWeldSystemStateChanges(weld_system_state_change);

  UpdateBeadControlParameters();

  // Set storage so that at least one week of logging can be stored before logs are being rotated
  auto const wcl_config = common::logging::ComponentLoggerConfig{
      .component      = "weldcontrol",
      .path_directory = path_logs / "weldcontrol",
      .file_name      = "%Y%m%d_%H%M%S.log",
      .max_file_size  = 1300 * 1000 * 1000, /* 1.3 GB */
      .max_nb_files   = 10,
  };

  weld_logger_ = common::logging::ComponentLogger(wcl_config);
  scanner_client_->SubscribeScanner([this](bool success) { OnGeometryApplied(success); }, {});
}

void WeldControlImpl::UpdateBeadControlParameters() {
  auto const abp_parameters = weld_sequence_config_->GetABPParameters();

  if (abp_parameters.has_value()) {
    bead_control_->SetWallOffset(abp_parameters->WallOffset());
    bead_control_->SetBeadOverlap(abp_parameters->BeadOverlap());
    bead_control_->SetStepUpValue(abp_parameters->StepUpValue());
    bead_control_->SetBeadSwitchAngle(abp_parameters->BeadSwitchAngle());
    bead_control_->SetKGain(abp_parameters->KGain());
    bead_control_->SetCapBeads(abp_parameters->CapBeads());
    bead_control_->SetCapCornerOffset(abp_parameters->CapCornerOffset());

    std::vector<bead_control::BeadControl::BeadTopWidthData> data;
    for (auto bead_no = 3;; ++bead_no) {
      auto const width = abp_parameters->StepUpLimit(bead_no);
      if (!width.has_value()) {
        break;
      }
      data.push_back({
          .beads_allowed  = bead_no,
          .required_width = width.value(),
      });
    }
    bead_control_->SetTopWidthToNumBeads(data);

    switch (abp_parameters->FirstBeadPositionValue()) {
      case ABPParameters::FirstBeadPosition::LEFT:
        bead_control_->SetFirstBeadPosition(bead_control::WeldSide::LEFT);
        break;
      case ABPParameters::FirstBeadPosition::RIGHT:
        bead_control_->SetFirstBeadPosition(bead_control::WeldSide::RIGHT);
        break;
      default:
        break;
    }
  }
}

void WeldControlImpl::OnGeometryApplied(bool success) {
  if (mode_ == Mode::IDLE) {
    // Scanner started from another class
    return;
  }

  if (!success) {
    LOG_ERROR("Scanner start failed");
    event_handler_->SendEvent(event::SCANNER_START_FAILED, std::nullopt);
    observer_->OnError();
  }
}

void WeldControlImpl::GetWeldControlStatus() const {
  auto const bead_control_status = bead_control_->GetStatus();
  auto response                  = nlohmann::json{
                       {"mode",          ModeToString(mode_)                                   },
                       {"weldingState",  StateToString(state_)                                 },
                       {"beadOperation", bead_control::StateToString(bead_control_status.state)},
                       {"layerNumber",   bead_control_status.layer_number                      },
                       {"beadNumber",    bead_control_status.bead_number                       },
                       {"progress",      bead_control_status.progress                          },
  };

  if (bead_control_status.total_beads.has_value()) {
    response["totalBeads"] = bead_control_status.total_beads.value();
  }

  web_hmi_->Send("GetWeldControlStatusRsp", SUCCESS_PAYLOAD, response);
};

void WeldControlImpl::LogData(std::optional<std::string> annotation = std::nullopt) {
  auto const now = system_clock_now_func_();

  auto floor = [](double value, int decimals) -> double {
    double const md = pow(10, decimals);
    return std::floor(value * md) / md;
  };

  auto const tp_scanner = std::chrono::system_clock::time_point{std::chrono::nanoseconds{cached_lpcs_.time_stamp}};
  auto radius           = cached_object_path_length_ / TWO_PI;
  auto logdata          = nlohmann::json{
               {"timestamp", common::time::TimePointToString(now, common::time::FMT_TS_MS)},
               {"type", "data"},
               {"timestampScanner", common::time::TimePointToString(tp_scanner, common::time::FMT_TS_MS)},
               {"mode", ModeToString(mode_)},
               {"grooveArea", cached_groove_area_},
               {"weldAxis",
                {
           {"position", cached_segment_.position * cached_segment_.max_value},
           {
               "velocity",
               {
                   {"actual", cached_velocity_},  // mm/s
                   {"desired", weld_axis_ang_velocity_desired_ * radius},
               },
           },
           {"radius", radius},
           {"distance", cached_linear_object_distance_.has_value() ? cached_linear_object_distance_.value() : 0.0},

       }},
  };

  if (annotation.has_value()) {
    logdata["annotation"] = annotation.value();
  }

  nlohmann::json mcs = nlohmann::json::array();
  if (cached_mcs_.groove.has_value()) {
    for (auto const& point : cached_mcs_.groove.value()) {
      mcs.push_back({
          {"x", floor(point.horizontal, LOG_3_DECIMALS)},
          {"z", floor(point.vertical,   LOG_3_DECIMALS)},
      });
    }
  }

  nlohmann::json mcs_delayed = nlohmann::json::array();
  if (cached_delayed_mcs_.has_value()) {
    for (auto const& point : cached_delayed_mcs_.value()) {
      mcs_delayed.push_back({
          {"x", floor(point.horizontal, LOG_3_DECIMALS)},
          {"z", floor(point.vertical,   LOG_3_DECIMALS)},
      });
    }
  }

  nlohmann::json lpcs = nlohmann::json::array();
  if (cached_lpcs_.groove.has_value()) {
    for (auto const& point : cached_lpcs_.groove.value()) {
      lpcs.push_back({
          {"x", floor(point.x, LOG_3_DECIMALS)},
          {"y", floor(point.y, LOG_3_DECIMALS)},
      });
    }
  }
  logdata["mcs"]        = mcs;
  logdata["mcsDelayed"] = mcs_delayed;
  logdata["lpcs"]       = lpcs;

  if (slides_desired_.has_value()) {
    logdata["slides"]["desired"] = {
        {"horizontal", slides_desired_->horizontal_pos},
        {"vertical",   slides_desired_->vertical_pos  }
    };
    logdata["slides"]["actual"] = {
        {"horizontal", slides_actual_.horizontal},
        {"vertical",   slides_actual_.vertical  }
    };
    ;
  }

  auto log_weld_system_data = [logdata, floor](const WeldSystem& ws) -> nlohmann::json {
    return nlohmann::json{
        {"state", weld_system::WeldSystemStateToString(ws.state)},
        {"current",
         {
             {"desired", floor(ws.settings.current, LOG_1_DECIMALS)},
             {"actual", floor(ws.data.current, LOG_1_DECIMALS)},
         }},
        {"voltage", floor(ws.data.voltage, LOG_1_DECIMALS)},
        {"wireSpeed", floor(ws.data.wire_lin_velocity, LOG_1_DECIMALS)},
        {"depositionRate", floor(ws.data.deposition_rate, LOG_1_DECIMALS)},
        {"heatInput", floor(ws.data.heat_input, LOG_3_DECIMALS)},
        {"wireDiameter", floor(ws.data.wire_diameter, LOG_1_DECIMALS)},
        {"twinWire", ws.data.twin_wire},
    };
  };

  logdata["weldSystems"] = {log_weld_system_data(weld_systems_[weld_system::WeldSystemId::ID1]),
                            log_weld_system_data(weld_systems_[weld_system::WeldSystemId::ID2])};

  auto const bead_control_status = bead_control_->GetStatus();
  logdata["beadControl"]         = {
      {"state",              bead_control::StateToString(bead_control_status.state)},
      {"layerNo",            bead_control_status.layer_number                      },
      {"beadNo",             bead_control_status.bead_number                       },
      {"progress",           bead_control_status.progress                          },
      {"beadSliceAreaRatio", bead_slice_area_ratio_                                },
      {"grooveAreaRatio",    groove_area_ratio_                                    },
      {"horizontalOffset",   bead_control_horizontal_offset_                       },
  };

  if (UseEdgeSensor()) {
    logdata["edgePosition"] = cached_edge_position_;
  }

  nlohmann::json mcs_profile = nlohmann::json::array();
  for (auto const& point : cached_mcs_.profile) {
    mcs_profile.push_back({
        {"x", floor(point.horizontal, LOG_3_DECIMALS)},
        {"z", floor(point.vertical,   LOG_3_DECIMALS)},
    });
  }
  logdata["mcsProfile"] = mcs_profile;

  weld_logger_.Log(logdata.dump());

  last_log_ = now;
}

void WeldControlImpl::LogDataRateLimited() {
  auto const elapsed = system_clock_now_func_() - last_log_;
  if (elapsed > LOG_RATE_LIMIT) {
    LogData();
  }
}

void WeldControlImpl::LogModeChange() {
  auto logdata = nlohmann::json{
      {"timestamp", common::time::TimePointToString(system_clock_now_func_(), common::time::FMT_TS_MS)},
      {"type", "modeChange"},
      {"mode", ModeToString(mode_)},
  };

  switch (mode_) {
    case Mode::AUTOMATIC_BEAD_PLACEMENT: {
      auto const abp_parameters = weld_sequence_config_->GetABPParameters();

      assert(abp_parameters.has_value());

      logdata["abpParameters"] = abp_parameters->ToJson();
    }
    case Mode::JOINT_TRACKING: {
      logdata["verticalOffset"] = vertical_offset_;
      break;
    }
    case Mode::IDLE:
    default:
      break;
  };

  weld_logger_.Log(logdata.dump());
}

auto WeldControlImpl::JTReady() const -> bool {
  // edge sensor not required for JT
  if (!UseEdgeSensor()) {
    return true;
  }
  // edge sensor required for JT and not present
  if (!IsEdgeSensorPresent()) {
    return false;
  }
  // for CW joint with edge sensor, check if edge is available
  return GetEdgeSensorState() == kinematics::EdgeState::AVAILABLE;
}

auto WeldControlImpl::ABPReady() const -> bool {
  auto const weld_axis_ok = weld_axis_state_ && *weld_axis_state_ == WeldAxisState::INITIALIZED;
  bool edge_sensor_ok     = true;
  if (UseEdgeSensor()) {
    if (!IsEdgeSensorPresent()) {
      edge_sensor_ok = false;
    } else {
      edge_sensor_ok = GetEdgeSensorState() == kinematics::EdgeState::AVAILABLE;
    }
  }
  auto const abp_parameters_ok = weld_sequence_config_->GetABPParameters().has_value();
  auto const weld_session_ok   = !weld_session_.resume_blocked;

  return weld_axis_ok && edge_sensor_ok && abp_parameters_ok && weld_session_ok;
}

void WeldControlImpl::UpdateReady() {
  if (on_ready_update_) {
    auto ready_modes = std::vector<std::pair<Mode, LayerType>>{};
    if (JTReady()) {
      ready_modes.emplace_back(Mode::JOINT_TRACKING, LayerType::NOT_APPLICABLE);
    }

    if (ABPReady()) {
      if (!weld_session_.active || !weld_session_.ready_for_cap) {
        ready_modes.emplace_back(Mode::AUTOMATIC_BEAD_PLACEMENT, LayerType::FILL);
      }

      if ((weld_session_.active && weld_session_.ready_for_cap) ||
          (!weld_session_.active && ready_for_jt_to_auto_cap_)) {
        ready_modes.emplace_back(Mode::AUTOMATIC_BEAD_PLACEMENT, LayerType::CAP);
      }
    };

    on_ready_update_(ready_modes);
  }
}
void WeldControlImpl::CheckReady() {
  if (mode_ == Mode::AUTOMATIC_BEAD_PLACEMENT) {
    return;
  }

  if (ABPReady()) {
    auto on_weld_axis_response = [this](std::uint64_t /*time_stamp*/, double /*position*/, double /*ang_velocity*/,
                                        double length, double /*linear_object_distance*/) {
      if (mode_ != Mode::AUTOMATIC_BEAD_PLACEMENT) {
        if (!IsLW()) {
          cached_object_path_length_ = length;
        }
        UpdateOutput(1., 1.);
      }
    };
    kinematics_client_->GetWeldAxisData(on_weld_axis_response);
  }

  UpdateReady();
}

void WeldControlImpl::WeldSystemStateChange(weld_system::WeldSystemId id, weld_system::WeldSystemState state) {
  auto const arcing = state == weld_system::WeldSystemState::ARCING;

  LOG_INFO("Weld system {} state change {} -> {}", weld_system::WeldSystemIdToString(id),
           weld_system::WeldSystemStateToString(weld_systems_[id].state), weld_system::WeldSystemStateToString(state));

  switch (mode_) {
    case Mode::AUTOMATIC_BEAD_PLACEMENT: {
      /* compare previous state with new state to see if arcing is lost */
      auto const arcing_lost = weld_systems_[id].state == weld_system::WeldSystemState::ARCING && !arcing;

      if (arcing_lost && !weld_systems_[id].arcing_lost_timestamp) {
        LOG_ERROR("Unexpected weld-system-{} arcing lost", weld_system::WeldSystemIdToString(id));
        weld_systems_[id].arcing_lost_timestamp = steady_clock_now_func_();
      } else if (arcing && weld_systems_[id].arcing_lost_timestamp.has_value()) {
        auto const now                     = steady_clock_now_func_();
        auto const duration_without_arcing = std::chrono::duration_cast<std::chrono::milliseconds>(
            now - weld_systems_[id].arcing_lost_timestamp.value());
        LOG_INFO("Regained weld-system-{} arcing after {} ms", weld_system::WeldSystemIdToString(id),
                 duration_without_arcing.count());
      }
      break;
    }
    case Mode::IDLE:
    case Mode::JOINT_TRACKING:
      if (arcing) {
        ClearWeldSession();
      }
      break;
  }

  if (arcing) {
    weld_systems_[id].arcing_lost_timestamp = {};
  }

  weld_systems_[id].state = state;

  // Log all weld-system state changes to make it possible to determine how much time is spent welding
  // for the different weld-control state/modes (Manual, JT, ABP).
  LogData("weld-system-state-change");
}

auto WeldControlImpl::ValidateInput() -> std::optional<event::Code> {
  if (weld_axis_state_ != WeldAxisState::INITIALIZED) {
    return {};
  }

  if (cached_object_path_length_ <= 0.) {
    LOG_ERROR("Invalid weld object length: {}", cached_object_path_length_);
    return event::ABP_INVALID_INPUT;
  }

  if (cached_segment_.position < 0.0) {
    LOG_ERROR("Invalid weld axis position: {}", cached_segment_.position);
    return event::ABP_INVALID_INPUT;
  }

  if (cached_segment_.position >= WELD_AXIS_POSITION_OUT_OF_BOUNDS_THRESHOLD) {
    LOG_ERROR("Weld axis position out of bounds: {}", cached_segment_.position);
    return event::WELD_AXIS_INVALID_POSITION;
  }

  if (cached_segment_.position >= 1.0) {
    LOG_TRACE("Weld axis position > 1.0: {:.7f} set to 0.0", cached_segment_.position);
    cached_segment_.position = 0.0;
  }

  auto distance_since_last_pos = 0.0;
  if (last_weld_axis_position_.has_value()) {
    if (IsLW()) {
      distance_since_last_pos = cached_segment_.position - last_weld_axis_position_.value();
    } else {
      distance_since_last_pos =
          common::math::WrappedDist(last_weld_axis_position_.value(), cached_segment_.position, 1.0);
    }
  }

  if (distance_since_last_pos < 0.0 && cached_velocity_ > 0.0) {
    auto const distance_linear = distance_since_last_pos * cached_object_path_length_;
    if (state_ == State::WELDING && -distance_linear > WELD_AXIS_POSITION_MAX_REVERSE_THRESHOLD) {
      LOG_ERROR("Invalid weld-axis position change from {} -> {} diff(mm): {:.1f}", last_weld_axis_position_.value(),
                cached_segment_.position, distance_linear);
      return event::ABP_INVALID_INPUT;
    }

    /* within tolerance - use last valid position */
    cached_segment_.position = last_weld_axis_position_.value();
  }

  if (LaserOnObject()) {
    last_weld_axis_position_ = cached_segment_.position;
  } else {
    last_weld_axis_position_.reset();
  }

  return {};
}

auto WeldControlImpl::CheckSupervision() -> std::optional<event::Code> {
  for (auto [id, ws] : weld_systems_) {
    auto const now = steady_clock_now_func_();
    if (ws.arcing_lost_timestamp.has_value() &&
        now - ws.arcing_lost_timestamp.value() > config_.supervision.arcing_lost_grace) {
      LOG_ERROR("Failed weld-system-{} arcing supervision", weld_system::WeldSystemIdToString(id));
      return event::ARCING_LOST;
    }
  }

  return {};
}

void WeldControlImpl::ChangeMode(Mode new_mode) {
  LOG_INFO("Mode change {} -> {} (state: {})", ModeToString(mode_), ModeToString(new_mode), StateToString(state_));

  mode_ = new_mode;
  metrics_->UpdateOperationalState(mode_, state_);

  LogModeChange();
}

void WeldControlImpl::ChangeState(State new_state) {
  LOG_INFO("State change {} -> {} (mode: {})", StateToString(state_), StateToString(new_state), ModeToString(mode_));

  for (auto* observer : weld_state_observers_) {
    observer->OnWeldStateChanged(new_state == State::WELDING ? WeldStateObserver::State::WELDING
                                                             : WeldStateObserver::State::IDLE);
  }

  state_ = new_state;
  metrics_->UpdateOperationalState(mode_, state_);
}

auto WeldControlImpl::LaserBeforeEntryEdge() -> bool {
  return IsLW() && cached_linear_object_distance_.value() < torch_position_when_laser_on_entry_edge_;
}

auto WeldControlImpl::LaserOnObject() -> bool {
  // Laser line is always on a circular object
  if (!IsLW()) {
    return true;
  }

  if (!cached_linear_object_distance_.has_value()) {
    return false;
  }

  if (torch_position_when_laser_on_entry_edge_ == 0.0 || cached_object_path_length_ == 0.0) {
    return false;
  }

  auto position = cached_linear_object_distance_.value();

  return position >= torch_position_when_laser_on_entry_edge_ &&
         position <= (torch_position_when_laser_on_entry_edge_ + cached_object_path_length_);
}

void WeldControlImpl::UpdateConfidentSlice() {
  if (weld_axis_state_ != WeldAxisState::INITIALIZED && LaserOnObject()) {
    return;
  }

  metrics_->SetConfidentSliceBuffer(confident_slice_buffer_);

  if (cached_lpcs_.confidence == lpcs::SliceConfidence::HIGH) {
    if (!confident_slice_buffer_.Available()) {
      confident_slice_buffer_.Init(cached_object_path_length_, config_.storage_resolution);
    }

    confident_slice_buffer_.Store(cached_segment_.position,
                                  {.edge_position = cached_edge_position_, .groove = cached_mcs_.groove.value()});
  }

  auto const data = confident_slice_buffer_.Get(cached_segment_.position);
  if (!data) {
    metrics_->IncConfidentSliceNoData();
    return;
  }

  auto const fill_ratio = confident_slice_buffer_.FillRatio();
  LOG_TRACE("confident_slice_buffer filled-ratio: {:.1f}%", fill_ratio * 100);

  auto groove                       = data.value().second.groove;
  auto const edge_sensor_adjustment = data.value().second.edge_position - cached_edge_position_;

  groove.Move(common::Point{
      .horizontal = settings_.EdgeSensorPlacementValue() == Settings::EdgeSensorPlacement::RIGHT
                        ? -edge_sensor_adjustment
                        : edge_sensor_adjustment,
  });

  auto const use_edge_sensor = UseEdgeSensor();

  auto const upper_width           = groove.TopWidth();
  auto const left_wall_angle       = groove.LeftWallAngle();
  auto const right_wall_angle      = groove.RightWallAngle();
  auto const upper_width_tolerance = config_.scanner_groove_geometry_update.tolerance.upper_width;
  auto const wall_angle_tolerance  = config_.scanner_groove_geometry_update.tolerance.wall_angle;
  auto const lpcs_groove =
      use_edge_sensor ? slice_translator_v2_->MCSToLPCS(groove.ToVector(), slides_actual_) : std::nullopt;
  LOG_TRACE(
      "Update scanner groove geometry - upper_width: {:.2f} wall_angle(left/right): {:.3f}/{:.3f} "
      "tolerance(width/wall angle): {:.3f}/{:.3f} edge_sensor_adjustment: {:.3f} translation_ok: {}",
      upper_width, left_wall_angle, right_wall_angle, upper_width_tolerance, wall_angle_tolerance,
      edge_sensor_adjustment, lpcs_groove.has_value() ? "yes" : "no");

  scanner_client_->Update({
      .upper_width      = upper_width,
      .left_wall_angle  = left_wall_angle,
      .right_wall_angle = right_wall_angle,
      .tolerance{.upper_width = upper_width_tolerance, .wall_angle = wall_angle_tolerance},
      .abw0_horizontal = lpcs_groove ? lpcs_groove.value()[common::ABW_UPPER_LEFT].x : 0.0,
      .abw6_horizontal = lpcs_groove ? lpcs_groove.value()[common::ABW_UPPER_RIGHT].x : 0.0,
  });

  if (lpcs_groove.has_value()) {
    metrics_->IncConfidentSliceOk();
  } else {
    metrics_->IncConfidentSliceTranslationFailed();
  }
}

void WeldControlImpl::UpdateGrooveProfile() {
  if (!LaserOnObject()) {
    return;
  }

  if (cached_mcs_.profile.empty()) {
    return;
  }

  if (cached_object_path_length_ <= 0.0 || config_.storage_resolution <= 0.0) {
    return;
  }

  if (!groove_profile_buffer_.Available()) {
    groove_profile_buffer_.Init(cached_object_path_length_, config_.storage_resolution);
  }

  groove_profile_buffer_.Store(cached_segment_.position, {.profile = cached_mcs_.profile});
}

void WeldControlImpl::UpdateReadyForABPCap() {
  /* this function handles ready-for-ABP-CAP when in JT mode - once ready_for_jt_to_auto_cap_ is set we do not allow it
   * to go back to avoid toggling the value back and forth */

  if (weld_axis_state_ != WeldAxisState::INITIALIZED || !UseEdgeSensor()) {
    return;
  }

  if (mode_ != Mode::JOINT_TRACKING) {
    return;
  }

  if (ready_for_jt_to_auto_cap_) {
    return;
  }

  auto const abp_parameters = weld_sequence_config_->GetABPParameters();
  if (!abp_parameters.has_value()) {
    return;
  }

  if (confident_slice_buffer_.FillRatio() < READY_FOR_CAP_CONFIDENT_BUFFER_FILL_RATIO) {
    return;
  }

  if (cached_mcs_.groove->AvgDepth() > abp_parameters->CapInitDepth()) {
    return;
  }

  ready_for_jt_to_auto_cap_ = true;
  UpdateReady();
}

void WeldControlImpl::ProcessInput() {
  /* check pending operations */
  if (pending_get_weld_axis_data_ || pending_get_weld_system1_data_ || pending_get_weld_system2_data_ ||
      pending_get_edge_position_) {
    return;
  }

  if (mode_ == Mode::IDLE) {
    if (ManualWeldingArcing()) {
      LogDataRateLimited();
    }
    return;
  }

  if (!UpdateSliceConfidence()) {
    return;
  }

  auto const event_invalid_input = ValidateInput();
  if (event_invalid_input.has_value()) {
    event_handler_->SendEvent(event_invalid_input.value(), std::nullopt);
    observer_->OnError();
    LogData("invalid-input");
    return;
  }

  auto const event_failed_supervision = CheckSupervision();
  if (event_failed_supervision.has_value()) {
    event_handler_->SendEvent(event_failed_supervision.value(), std::nullopt);
    observer_->OnError();
    LogData("failed-supervision-input");
    return;
  }

  auto const welding = weld_systems_[weld_system::WeldSystemId::ID1].state == weld_system::WeldSystemState::ARCING &&
                       cached_velocity_ > 0.;

  if (welding && state_ == State::IDLE) {
    ChangeState(State::WELDING);
    HandleChangeState(State::WELDING);
  } else if (!welding && state_ == State::WELDING) {
    ChangeState(State::IDLE);
    HandleChangeState(State::IDLE);
  }

  if (LaserBeforeEntryEdge() && cache_start_mcs_.has_value()) {
    delay_buffer_->Store(cache_start_mcs_.value().position, cache_start_mcs_.value().groove);
    cache_start_mcs_ = {};
  }

  UpdateTrackingPosition();
  UpdateConfidentSlice();
  UpdateGrooveProfile();
  UpdateReadyForABPCap();
  LogDataRateLimited();
}

void WeldControlImpl::HandleChangeState(State state) {
  if (!IsLW()) {
    return;
  }
  auto weld_head_start  = torch_position_when_laser_on_entry_edge_ + cached_distance_from_torch_to_scanner_;
  auto current_position = cached_linear_object_distance_.value();

  if (state == State::WELDING && !target_path_position_.has_value()) {
    // Welding started on a new bead. Expect that weld head is on run-on plate
    target_path_position_ = ((weld_head_start - current_position) * 2.) + cached_object_path_length_ + current_position;
    kinematics_client_->SetTargetPathPosition(target_path_position_.value());
    LOG_INFO("Target path position: {:.5f} current: {:.5f}", target_path_position_.value(), current_position);
  } else if (state == State::IDLE && current_position > weld_head_start + cached_object_path_length_) {
    // Welding stopped and weld head is on run-off plate i.e. bead ready
    target_path_position_ = {};
  }
}

void WeldControlImpl::StoreGrooveInDelayBuffer() {
  if (cached_linear_object_distance_.has_value()) {
    auto position = cached_linear_object_distance_.value();

    if (LaserOnObject()) {
      delay_buffer_->Store(position, cached_mcs_.groove.value());

      if (!cache_start_mcs_.has_value()) {
        cache_start_mcs_ = {.position = position, .groove = cached_mcs_.groove.value()};
      } else if ((cache_start_mcs_.value().position - WELD_OBJECT_DISTANCE_MAX_REVERSE_THRESHOLD) > position) {
        // If we are moving backwards (closer to start of weld entry) we should update start slice
        cache_start_mcs_ = {.position = position, .groove = cached_mcs_.groove.value()};
      }
    }
  }
}

auto WeldControlImpl::GetDelayedGrooveMCS() -> common::Groove {
  auto const current = cached_mcs_.groove.value();
  if (!cached_linear_object_distance_.has_value()) {
    return current;
  }
  auto const delay =
      GetSampleToTorchDist(cached_lpcs_.time_stamp, cached_velocity_, cached_distance_from_torch_to_scanner_);

  auto delayed_groove = delay_buffer_->Get(cached_linear_object_distance_.value(), delay).value_or(current);

  return delayed_groove;
}

auto WeldControlImpl::GetHybridGrooveMCS() const -> common::Groove {
  auto const current_groove = cached_mcs_.groove.value();
  if (!cached_linear_object_distance_.has_value()) {
    return current_groove;
  }
  auto const delayed_groove =
      delay_buffer_->Get(cached_linear_object_distance_.value(), cached_distance_from_torch_to_scanner_)
          .value_or(current_groove);

  // Use ABW0,6 from current groove
  // Attempt to update the y values for the bottom of the groove.
  // Translate them in y according to the current movement of abw0 in y.
  // abw1_y = abw1_y_prev + abw0_y - abw0_y_prev

  // When a longitudinal weld is encountered, one of abw0 or abw6 moves upward in y
  // and we need to use the top corner with the lowest *absolute* abw_y - abw_y_prev

  // The edge case would be if the object tips to the side at the site of a longitudinal weld,
  // (not unlikely). For best results the bead starts should be far away from the longitudinal welds

  auto merged = current_groove;
  auto idx =
      fabs(current_groove[common::ABW_UPPER_LEFT].vertical - delayed_groove[common::ABW_UPPER_LEFT].vertical) <
              fabs(current_groove[common::ABW_UPPER_RIGHT].vertical - delayed_groove[common::ABW_UPPER_RIGHT].vertical)
          ? common::ABW_UPPER_LEFT
          : common::ABW_UPPER_RIGHT;

  const double dx = current_groove[idx].horizontal - delayed_groove[idx].horizontal;
  const double dy = current_groove[idx].vertical - delayed_groove[idx].vertical;

  for (int i = common::ABW_LOWER_LEFT; i <= common::ABW_LOWER_RIGHT; i++) {
    merged[i].horizontal = delayed_groove[i].horizontal + dx;
    merged[i].vertical   = delayed_groove[i].vertical + dy;
  }
  LOG_TRACE(
      "Delay: torch_to_scanner(mm): {:.2f}. ABW1 ({:4f},{:4f},{:4f},{:4f}), ABW5 "
      "({:4f},{:4f},{:4f},{:4f}), Delta dx/dy ({:4f}, {:4f}), Corner ({})",
      cached_distance_from_torch_to_scanner_, delayed_groove[common::ABW_LOWER_LEFT].horizontal,
      merged[common::ABW_LOWER_LEFT].horizontal, delayed_groove[common::ABW_LOWER_LEFT].vertical,
      merged[common::ABW_LOWER_LEFT].vertical, delayed_groove[common::ABW_LOWER_RIGHT].horizontal,
      merged[common::ABW_LOWER_RIGHT].horizontal, delayed_groove[common::ABW_LOWER_RIGHT].vertical,
      merged[common::ABW_LOWER_RIGHT].vertical, dx, dy, idx == common::ABW_UPPER_LEFT ? "LEFT" : "RIGHT");

  return merged;
}

auto WeldControlImpl::GetSampleToTorchDist(uint64_t ts_sample, double velocity, double torch_to_scanner_distance)
    -> double {
  if (weld_axis_state_ != WeldAxisState::INITIALIZED) {
    return std::max(torch_to_scanner_distance - 5.0, 0.);
  }

  /* return distance from sample to torch in mm */
  auto const now        = steady_clock_now_func_();
  auto const tp_scanner = std::chrono::steady_clock::time_point{std::chrono::nanoseconds{ts_sample}};
  auto const duration_seconds =
      static_cast<double>(std::chrono::duration_cast<std::chrono::microseconds>(now - tp_scanner).count()) / 1000000.;

  auto const dist_since_sample = std::max(velocity * duration_seconds, 0.);
  auto const delay             = std::max(torch_to_scanner_distance - dist_since_sample, 0.);

  return delay;
}

void WeldControlImpl::UpdateOutput(double bead_slice_area_ratio, double area_ratio) {
  auto const abp_parameters = weld_sequence_config_->GetABPParameters();
  if (!abp_parameters.has_value()) {
    return;
  }

  if (mode_ == Mode::AUTOMATIC_BEAD_PLACEMENT && state_ == State::WELDING) {
    // Compute gains based on current groove depth
    double depth_mm = 0.0;
    if (cached_mcs_.groove.has_value()) {
      depth_mm = cached_mcs_.groove->AvgDepth();  // measured depth
    }

    double joint_geometry_depth_mm = 0.0;
    if (joint_geometry_.has_value()) {
      joint_geometry_depth_mm = joint_geometry_->groove_depth_mm;
    }

    auto const speed_gain =
        DepthScaledGain(depth_mm, joint_geometry_depth_mm, config_.adaptivity.speed_adaptivity_max_gain);
    auto const current_gain =
        DepthScaledGain(depth_mm, joint_geometry_depth_mm, config_.adaptivity.current_adaptivity_max_gain);

    // Scale the *deviation from 1.0* for each ratio independently
    auto const weld_speed_ratio   = ApplyAdaptivityGain(area_ratio, speed_gain);
    auto const weld_current_ratio = ApplyAdaptivityGain(bead_slice_area_ratio, current_gain);

    LOG_TRACE(
        "adaptivity: depth(mm): {:.2f} gains(speed/current): {:.2f}/{:.2f} "
        "ratios_in(speed/current): {:.4f}/{:.4f} ratios_out(speed/current): {:.4f}/{:.4f}",
        depth_mm, speed_gain, current_gain, area_ratio, bead_slice_area_ratio, weld_speed_ratio, weld_current_ratio);

    auto const result = WeldCalc::CalculateAdaptivity(WeldCalc::CalculateAdaptivityInput{
        .weld_current_ratio = weld_current_ratio,
        .weld_speed_ratio   = weld_speed_ratio,
        .heat_input_min     = abp_parameters->HeatInputMin(),
        .heat_input_max     = abp_parameters->HeatInputMax(),
        .ws1 =
            {
                  .current = weld_systems_[weld_system::WeldSystemId::ID1].data.current,
                  .voltage = weld_systems_[weld_system::WeldSystemId::ID1].data.voltage,
                  },
        .ws2 =
            {
                  .current_min = abp_parameters->WS2CurrentMin(),
                  .current_max = abp_parameters->WS2CurrentMax(),
                  .voltage     = weld_systems_[weld_system::WeldSystemId::ID2].data.voltage,
                  },
        .weld_object = {
                  .weld_speed_min = abp_parameters->WeldSpeedMin(),
                  .weld_speed_max = abp_parameters->WeldSpeedMax(),
                  }
    });

    auto const smooth_weld_speed  = smooth_weld_speed_.Update(result.weld_speed);
    auto const smooth_ws2_current = smooth_ws2_current_.Update(result.ws2_current);

    weld_systems_[weld_system::WeldSystemId::ID2].settings.current = smooth_ws2_current;
    weld_axis_ang_velocity_desired_ = smooth_weld_speed / (cached_object_path_length_ / TWO_PI);

  } else {
    /* set weld-speed and ws2 current to make the transition to ABP smooth */
    weld_systems_[weld_system::WeldSystemId::ID2].settings.current = abp_parameters->WS2CurrentAvg();
    weld_axis_ang_velocity_desired_ = abp_parameters->WeldSpeedAvg() / (cached_object_path_length_ / TWO_PI);
  }

  auto radius = cached_object_path_length_ / TWO_PI;

  LOG_TRACE(
      "output: ws2-current: {:.1f}, weld-axis velocity(rad/sec)/velocity(cm/min)/radius(mm): {:.4f}/{:.1f}/{:.1f}",
      weld_systems_[weld_system::WeldSystemId::ID2].settings.current, weld_axis_ang_velocity_desired_,
      common::math::MmSecToCmMin(weld_axis_ang_velocity_desired_ * radius), radius);

  weld_system_client_->SetWeldSystemData(weld_system::WeldSystemId::ID2,
                                         weld_systems_[weld_system::WeldSystemId::ID2].settings);

  kinematics_client_->SetWeldAxisData(weld_axis_ang_velocity_desired_);
}

void WeldControlImpl::UpdateTrackingPosition() {
  double slide_horizontal_lin_velocity = HORIZONTAL_VELOCITY;
  double slide_vertical_velocity       = VERTICAL_VELOCITY;

  StoreGrooveInDelayBuffer();

  auto const hybrid_mcs = GetHybridGrooveMCS();

  tracking::TrackingManager::Input tracking_input{
      .mode                   = tracking_mode_,
      .horizontal_offset      = horizontal_offset_,
      .vertical_offset        = vertical_offset_,
      .groove                 = hybrid_mcs,
      .axis_position          = slides_actual_,
      .smooth_vertical_motion = state_ == State::WELDING,
  };

  cached_delayed_mcs_ = GetDelayedGrooveMCS();

  switch (mode_) {
    case Mode::AUTOMATIC_BEAD_PLACEMENT: {
      auto const input = bead_control::BeadControl::Input{
          .segment            = {cached_segment_.position, cached_segment_.max_value},
          .velocity           = cached_velocity_,
          .object_path_length = cached_object_path_length_,
          .weld_system1 = {.wire_lin_velocity = weld_systems_[weld_system::WeldSystemId::ID1].data.wire_lin_velocity,
                                 .current           = weld_systems_[weld_system::WeldSystemId::ID1].data.current,
                                 .wire_diameter     = weld_systems_[weld_system::WeldSystemId::ID1].data.wire_diameter,
                                 .twin_wire         = weld_systems_[weld_system::WeldSystemId::ID1].data.twin_wire},
          .weld_system2 = {.wire_lin_velocity = weld_systems_[weld_system::WeldSystemId::ID2].data.wire_lin_velocity,
                                 .current           = weld_systems_[weld_system::WeldSystemId::ID2].data.current,
                                 .wire_diameter     = weld_systems_[weld_system::WeldSystemId::ID2].data.wire_diameter,
                                 .twin_wire         = weld_systems_[weld_system::WeldSystemId::ID2].data.twin_wire},
          .groove       = cached_delayed_mcs_.value(),
          .in_horizontal_position =
              std::fabs(slides_actual_.horizontal - slides_desired_->horizontal_pos) < REPOSITION_IN_POSITION_TOLERANCE,
          .paused = state_ == State::IDLE,
      };
      auto const [result, output] = bead_control_->Update(input);
      switch (result) {
        case bead_control::BeadControl::Result::OK:
          break;
        case bead_control::BeadControl::Result::ERROR:
          event_handler_->SendEvent(event::ABP_CALCULATION_ERROR, std::nullopt);
          observer_->OnError();
          LogData("abp-calculation-error");
          return;
        case bead_control::BeadControl::Result::FINISHED:
          LOG_INFO("Groove finished!");
          observer_->OnGracefulStop();
          return;
      }

      UpdateOutput(output.bead_slice_area_ratio, output.groove_area_ratio);

      bead_slice_area_ratio_          = output.bead_slice_area_ratio;
      groove_area_ratio_              = output.groove_area_ratio;
      bead_control_horizontal_offset_ = output.horizontal_offset;

      tracking_input.mode              = output.tracking_mode;
      tracking_input.reference         = output.tracking_reference;
      tracking_input.horizontal_offset = output.horizontal_offset;

      if (output.horizontal_lin_velocity.has_value()) {
        slide_horizontal_lin_velocity = output.horizontal_lin_velocity.value();
      }
    }  // fallthrough
    case Mode::JOINT_TRACKING: {
      slides_desired_ = tracking_manager_->Update(tracking_input);
      if (!slides_desired_.has_value()) {
        LOG_ERROR("tracking-manager update failed!");
        return;
      }

      if (state_ == State::WELDING) {
        slide_vertical_velocity = VERTICAL_VELOCITY_ARCING;
      }
      kinematics_client_->SetSlidesPosition(slides_desired_->horizontal_pos, slides_desired_->vertical_pos,
                                            slide_horizontal_lin_velocity, slide_vertical_velocity);
      break;
    }
    case Mode::IDLE:
    default:
      break;
  }
}

auto WeldControlImpl::CheckHandover() -> bool {
  auto const now = steady_clock_now_func_();
  if (handover_to_abp_cap_timestamp_ && now > handover_to_abp_cap_timestamp_.value() + config_.handover_grace) {
    LOG_ERROR("Handover to ABP CAP failed");
    event_handler_->SendEvent(event::HANDOVER_FAILED, std::nullopt);
    observer_->OnError();
    return false;
  }

  if (handover_to_manual_timestamp_ && now > handover_to_manual_timestamp_.value() + config_.handover_grace) {
    LOG_ERROR("Handover to manual failed");
    event_handler_->SendEvent(event::HANDOVER_FAILED, std::nullopt);
    observer_->OnError();
    return false;
  }

  return true;
}

auto WeldControlImpl::UpdateSliceConfidence() -> bool {
  auto const now = steady_clock_now_func_();

  metrics_->IncSliceConfidence(cached_lpcs_.confidence);

  if (!LaserOnObject()) {
    scanner_no_confidence_timestamp_.reset();
  }

  switch (cached_lpcs_.confidence) {
    case lpcs::SliceConfidence::NO:
      if (!scanner_no_confidence_timestamp_) {
        scanner_no_confidence_timestamp_ = now;
      } else if (now > scanner_no_confidence_timestamp_.value() + config_.scanner_no_confidence_grace) {
        LOG_ERROR("Scanner NO confidence grace timeout!");
        event_handler_->SendEvent(event::GROOVE_DETECTION_ERROR, std::nullopt);
        scanner_client_->FlushImageBuffer();
        observer_->OnGrooveDataTimeout();
        return false;
      }

      if (!scanner_low_confidence_timestamp_) {
        scanner_low_confidence_timestamp_ = now;
      }

      break;
    case lpcs::SliceConfidence::LOW:
      if (!scanner_low_confidence_timestamp_) {
        scanner_low_confidence_timestamp_ = now;
      } else if (!handover_to_manual_timestamp_ &&
                 now > scanner_low_confidence_timestamp_.value() + config_.scanner_low_confidence_grace) {
        LOG_INFO("Scanner LOW confidence grace timeout - Handover-to-manual triggered with {} seconds timeout",
                 config_.handover_grace);
        handover_to_manual_timestamp_ = steady_clock_now_func_();
        observer_->OnNotifyHandoverToManual();
        weld_session_.resume_blocked = true;
        UpdateReady();
      }

      scanner_no_confidence_timestamp_.reset();

      break;
    case lpcs::SliceConfidence::MEDIUM:
    case lpcs::SliceConfidence::HIGH:
      scanner_no_confidence_timestamp_.reset();
      scanner_low_confidence_timestamp_.reset();
      break;
  }

  if (cached_lpcs_.confidence == lpcs::SliceConfidence::NO) {
    if (!last_confident_mcs_.has_value() || !last_confident_lpcs_.has_value()) {
      /* Update Confident slice to that we are not stuck with NO confidence when close to the top surface */
      UpdateConfidentSlice();

      LOG_INFO("Skipping input due to NO confidence and no cached data.");
      return false;
    }
    cached_lpcs_ = last_confident_lpcs_.value();
    cached_mcs_  = last_confident_mcs_.value();
  } else {
    last_confident_mcs_  = cached_mcs_;
    last_confident_lpcs_ = cached_lpcs_;
  }

  return true;
}

auto WeldControlImpl::ManualWeldingArcing() const -> bool {
  return weld_systems_.at(weld_system::WeldSystemId::ID1).state == weld_system::WeldSystemState::ARCING ||
         weld_systems_.at(weld_system::WeldSystemId::ID2).state == weld_system::WeldSystemState::ARCING;
}

void WeldControlImpl::CacheInputData(const macs::Slice& machine_data, const lpcs::Slice& scanner_data,
                                     const common::Point& slides_actual, double distance_from_torch_to_scanner) {
  slides_actual_                         = slides_actual;
  cached_mcs_                            = machine_data;
  cached_lpcs_                           = scanner_data;
  cached_distance_from_torch_to_scanner_ = distance_from_torch_to_scanner;
  cached_groove_area_                    = scanner_data.groove_area;
}

void WeldControlImpl::OnWeldAxisResponse(double position, double ang_velocity, double length,
                                         double linear_object_distance) {
  auto radius   = length / TWO_PI;
  auto velocity = ang_velocity * radius;
  if (weld_axis_state_ == WeldAxisState::INITIALIZED &&
      radius > 0.0) { /* invalid radius handled in ValidateInput function */
    if (fabs(velocity) < WELD_OBJECT_MOVING_THRESHOLD) {
      velocity = 0.0;
    }

    if (cached_segment_.position == 0.0 && velocity > 0.0) {
      LOG_INFO("Weld object rotation started");
    } else if (cached_segment_.position > 0.0 && velocity == 0.0) {
      LOG_INFO("Weld object rotation stopped");
    }
  }
  cached_velocity_ = velocity;
  if (!cached_linear_object_distance_.has_value()) {
    cached_linear_object_distance_ = linear_object_distance;
  }

  if (IsLW()) {
    cached_object_path_length_ = length;
    cached_segment_.max_value  = length;
    cached_segment_.position   = 0.0;
    weld_axis_state_           = WeldAxisState::INITIALIZED;
    if (LaserOnObject()) {
      cached_segment_.position = (position - torch_position_when_laser_on_entry_edge_) / cached_object_path_length_;
    }
  } else {
    cached_object_path_length_ = TWO_PI * radius;
    cached_segment_.max_value  = TWO_PI;
    cached_segment_.position   = position / TWO_PI;
  }

  auto const distance_since_last_pos = linear_object_distance - cached_linear_object_distance_.value();

  cached_linear_object_distance_ = linear_object_distance;

  if (linear_object_distance >= cached_linear_object_distance_.value()) {
    cached_linear_object_distance_ = linear_object_distance;
  } else if (-distance_since_last_pos > WELD_OBJECT_DISTANCE_MAX_REVERSE_THRESHOLD) {
    if (weld_axis_state_ != WeldAxisState::INITIALIZED) {
      delay_buffer_->Clear();
      cached_linear_object_distance_ = linear_object_distance;
    }
  }
  pending_get_weld_axis_data_ = false;

  ProcessInput();
}

void WeldControlImpl::OnWeldSystemResponse(weld_system::WeldSystemId id, const weld_system::WeldSystemData& data) {
  weld_systems_[id].data = data;

  switch (id) {
    case weld_system::WeldSystemId::ID1:
      pending_get_weld_system1_data_ = false;
      break;
    case weld_system::WeldSystemId::ID2:
      pending_get_weld_system2_data_ = false;
      break;
    case weld_system::WeldSystemId::INVALID:
    default:
      return;
  }

  ProcessInput();
}

void WeldControlImpl::Receive(const macs::Slice& machine_data, const lpcs::Slice& scanner_data,
                              const common::Point& slides_actual, const double distance_from_torch_to_scanner) {
  {
    auto const now        = steady_clock_now_func_();
    auto const tp_scanner = std::chrono::steady_clock::time_point{std::chrono::nanoseconds{scanner_data.time_stamp}};
    std::chrono::duration<double> const latency = now - tp_scanner;
    metrics_->ObserveLatency(latency.count());
  }

  if (mode_ == Mode::IDLE) {
    CacheInputData(machine_data, scanner_data, slides_actual, distance_from_torch_to_scanner);
    if (!ManualWeldingArcing()) {
      return;
    }
    if (pending_get_weld_axis_data_ || pending_get_weld_system1_data_ || pending_get_weld_system2_data_) {
      LOG_ERROR("Got new scanner input with pending operations weld-axis/ws1/ws2: {}/{}/{}",
                pending_get_weld_axis_data_, pending_get_weld_system1_data_, pending_get_weld_system2_data_);
      return;
    }
    if (machine_data.groove.has_value()) {
      metrics_->SetGroove(machine_data.groove.value());
    }
    pending_get_weld_axis_data_    = true;
    pending_get_weld_system1_data_ = true;
    pending_get_weld_system2_data_ = true;
    pending_get_edge_position_     = false;

    kinematics_client_->GetWeldAxisData(
        machine_data.time_stamp,
        [this](std::uint64_t, double position, double ang_velocity, double length, double linear_object_distance) {
          OnWeldAxisResponse(position, ang_velocity, length, linear_object_distance);
        });
    weld_system_client_->GetWeldSystemData(
        weld_system::WeldSystemId::ID1,
        [this](weld_system::WeldSystemId id, auto const& data) { OnWeldSystemResponse(id, data); });
    weld_system_client_->GetWeldSystemData(
        weld_system::WeldSystemId::ID2,
        [this](weld_system::WeldSystemId id, auto const& data) { OnWeldSystemResponse(id, data); });
    return;
  }

  if (!machine_data.groove.has_value()) {
    LOG_ERROR("No groove mcs values");
    return;
  }

  if (!CheckHandover()) {
    return;
  }

  if (pending_get_weld_axis_data_ || pending_get_weld_system1_data_ || pending_get_weld_system2_data_) {
    LOG_ERROR("Got new scanner input with pending operations weld-axis/ws1/ws2: {}/{}/{}", pending_get_weld_axis_data_,
              pending_get_weld_system1_data_, pending_get_weld_system2_data_);
    return;
  }

  CacheInputData(machine_data, scanner_data, slides_actual, distance_from_torch_to_scanner);

  const auto& groove = machine_data.groove.value();
  metrics_->SetGroove(groove);

  auto on_edge_position_response = [this](double position) {
    pending_get_edge_position_ = false;
    cached_edge_position_      = position;
    ProcessInput();
  };

  pending_get_weld_axis_data_    = true;
  pending_get_weld_system1_data_ = true;
  pending_get_weld_system2_data_ = true;
  pending_get_edge_position_     = UseEdgeSensor() && !IsLW();

  kinematics_client_->GetWeldAxisData(
      machine_data.time_stamp,
      [this](std::uint64_t, double position, double ang_velocity, double length, double linear_object_distance) {
        OnWeldAxisResponse(position, ang_velocity, length, linear_object_distance);
      });
  weld_system_client_->GetWeldSystemData(
      weld_system::WeldSystemId::ID1,
      [this](weld_system::WeldSystemId id, auto const& data) { OnWeldSystemResponse(id, data); });
  weld_system_client_->GetWeldSystemData(
      weld_system::WeldSystemId::ID2,
      [this](weld_system::WeldSystemId id, auto const& data) { OnWeldSystemResponse(id, data); });

  if (!IsLW() && UseEdgeSensor()) {
    kinematics_client_->GetEdgePosition(on_edge_position_response);
  } else {
    cached_edge_position_ = 0.0;
  }
}

void WeldControlImpl::JointTrackingStart(const joint_geometry::JointGeometry& joint_geometry,
                                         tracking::TrackingMode tracking_mode, double horizontal_offset,
                                         double vertical_offset) {
  switch (mode_) {
    case Mode::IDLE: {
      LOG_INFO("JT Start with mode: {} horizontal-offset: {} vertical-offset: {} type: {}",
               tracking::TrackingModeToString(tracking_mode), horizontal_offset, vertical_offset,
               joint_geometry::TypeToString(joint_geometry.type));

      joint_geometry_ = joint_geometry;
      scanner_client_->SetJointGeometry(joint_geometry);
      break;
    }
    case Mode::AUTOMATIC_BEAD_PLACEMENT:
      bead_control_->Reset();
      break;
    case Mode::JOINT_TRACKING:
    default:
      LOG_ERROR("Not allowed in current state: {}", StateToString(state_));
      return;
  }

  tracking_mode_     = tracking_mode;
  horizontal_offset_ = horizontal_offset;
  vertical_offset_   = vertical_offset;

  ChangeMode(Mode::JOINT_TRACKING);
  LogData("adaptio-state-change");
}

void WeldControlImpl::JointTrackingUpdate(tracking::TrackingMode tracking_mode, double horizontal_offset,
                                          double vertical_offset) {
  switch (mode_) {
    case Mode::JOINT_TRACKING:
      tracking_mode_     = tracking_mode;
      horizontal_offset_ = horizontal_offset;
      vertical_offset_   = vertical_offset;
      LOG_INFO("JT Update with mode: {} horizontal-offset: {:.3f} vertical-offset: {:.3f}",
               tracking::TrackingModeToString(tracking_mode), horizontal_offset, vertical_offset);
      break;
    case Mode::AUTOMATIC_BEAD_PLACEMENT:
    case Mode::IDLE:
    default:
      LOG_ERROR("Not allowed in current state: {}", StateToString(state_));
      return;
  }
}

void WeldControlImpl::AutoBeadPlacementStart(LayerType layer_type) {
  if (!ABPReady()) {
    LOG_ERROR("ABP not ready!");
    return;
  }

  auto const abp_parameters = weld_sequence_config_->GetABPParameters();
  smooth_weld_speed_.Fill(abp_parameters->WeldSpeedAvg());
  smooth_ws2_current_.Fill(abp_parameters->WS2CurrentAvg());

  ready_for_jt_to_auto_cap_ = false;
  UpdateReady();

  auto on_cap_notification = [this]() {
    auto const fill_ratio = confident_slice_buffer_.FillRatio();
    LOG_INFO("CAP notification - fill-ratio: {:.1f}%", fill_ratio * 100);

    if (UseEdgeSensor() && fill_ratio >= READY_FOR_CAP_CONFIDENT_BUFFER_FILL_RATIO) {
      LOG_INFO("Handover to ABP-CAP");
      handover_to_abp_cap_timestamp_ = steady_clock_now_func_();
      weld_session_.ready_for_cap    = true;
      UpdateReady();
    } else {
      LOG_INFO("Handover to manual");
      handover_to_manual_timestamp_ = steady_clock_now_func_();
      observer_->OnNotifyHandoverToManual();
      weld_session_.resume_blocked = true;
      UpdateReady();
    }
  };

  switch (mode_) {
    case Mode::JOINT_TRACKING: {
      LOG_INFO("ABP Start with parameters: {} session: {}",
               weld_sequence_config_->GetABPParameters().value_or(ABPParameters{}).ToString(),
               weld_session_.active ? "resume" : "new");
      ChangeMode(Mode::AUTOMATIC_BEAD_PLACEMENT);
      weld_session_.active = true;
      break;
    }
    case Mode::AUTOMATIC_BEAD_PLACEMENT:
      handover_to_abp_cap_timestamp_ = {};
      break;
    case Mode::IDLE:
    default:
      LOG_ERROR("Not allowed in current state: {}", StateToString(state_));
      return;
  }

  switch (layer_type) {
    case LayerType::FILL:
      bead_control_->RegisterCapNotification(config_.handover_grace + FIXED_HANDOVER_GRACE,
                                             abp_parameters->CapInitDepth(), on_cap_notification);
      break;
    case LayerType::CAP:
      handover_to_abp_cap_timestamp_ = {};
      bead_control_->UnregisterCapNotification();
      bead_control_->NextLayerCap();
      weld_session_.ready_for_cap = true;
      break;
    case LayerType::NOT_APPLICABLE:
      /* not a valid ABP layer type */
      return;
  }

  LogData("adaptio-state-change");
}

void WeldControlImpl::AutoBeadPlacementStop() {
  switch (mode_) {
    case Mode::AUTOMATIC_BEAD_PLACEMENT:
      weld_systems_[weld_system::WeldSystemId::ID1].arcing_lost_timestamp = {};
      weld_systems_[weld_system::WeldSystemId::ID2].arcing_lost_timestamp = {};
      handover_to_abp_cap_timestamp_                                      = {};
      ChangeMode(Mode::JOINT_TRACKING);

      if (state_ == State::WELDING) {
        ClearWeldSession();
      }

      LOG_INFO("ABP stop - weld object pos: {:.4f}", cached_segment_.position);

      break;
    case Mode::JOINT_TRACKING:
    case Mode::IDLE:
    default:
      LOG_ERROR("AutoBeadPlacementStop not allowed in current state: {}", StateToString(state_));
      return;
  }

  LogData("adaptio-state-change");

  UpdateReady();
}

void WeldControlImpl::Stop() {
  LOG_INFO("Stop - weld object pos: {:.4f}", cached_segment_.position);
  last_weld_axis_position_  = {};
  ready_for_jt_to_auto_cap_ = false;

  kinematics_client_->Release();
  tracking_manager_->Reset();
  delay_buffer_->Clear();
  weld_systems_[weld_system::WeldSystemId::ID1].arcing_lost_timestamp = {};
  weld_systems_[weld_system::WeldSystemId::ID2].arcing_lost_timestamp = {};
  handover_to_abp_cap_timestamp_                                      = {};
  handover_to_manual_timestamp_                                       = {};
  bead_control_->UnregisterCapNotification();
  metrics_->ResetGroove();

  scanner_no_confidence_timestamp_  = {};
  scanner_low_confidence_timestamp_ = {};
  handover_to_manual_timestamp_     = {};

  last_confident_lpcs_ = {};
  last_confident_mcs_  = {};

  cached_linear_object_distance_ = {};
  ChangeMode(Mode::IDLE);
  ChangeState(State::IDLE);

  LogData("adaptio-state-change");

  UpdateReady();
}

void WeldControlImpl::SetObserver(WeldControlObserver* observer) { observer_ = observer; }

auto WeldControlImpl::GetObserver() const -> WeldControlObserver* { return observer_; }

void WeldControlImpl::SubscribeReady(
    std::function<void(const std::vector<std::pair<Mode, LayerType>>&)> on_ready_update) {
  on_ready_update_ = on_ready_update;

  CheckReady();
}

void WeldControlImpl::ResetGrooveData() {
  delay_buffer_->Clear();
  ResetGrooveDataHomed();
}

void WeldControlImpl::WeldControlCommand(weld_system::WeldControlCommand command) {
  weld_system_client_->WeldControlCommand(command);
}

void WeldControlImpl::ResetGrooveDataHomed() {
  bead_control_->ResetGrooveData();
  confident_slice_buffer_.Clear();
  groove_profile_buffer_.Clear();
  ClearWeldSession();
}

void WeldControlImpl::AddWeldStateObserver(WeldStateObserver* observer) { weld_state_observers_.push_back(observer); }

void WeldControlImpl::ClearWeldSession() {
  if (weld_session_.active) {
    LOG_INFO("Clearing active weld session!");
  }

  weld_session_ = {};

  bead_control_->Reset();

  UpdateReady();
}

auto WeldControlImpl::IsLW() const -> bool {
  return joint_geometry_.has_value() && joint_geometry_->type == joint_geometry::Type::LW;
}

auto WeldControlImpl::UseEdgeSensor() const -> bool {
  if (IsLW()) {
    return true;
  }
  return settings_.UseEdgeSensor();
}

auto WeldControlImpl::IsEdgeSensorPresent() const -> bool {
  if (IsLW()) {
    return true;
  }
  return edge_state_.has_value();
}

auto WeldControlImpl::GetEdgeSensorState() const -> kinematics::EdgeState {
  if (IsLW()) {
    return kinematics::EdgeState::AVAILABLE;
  }
  return edge_state_.value_or(kinematics::EdgeState::NOT_AVAILABLE);
}

}  // namespace weld_control
