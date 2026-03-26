#include "weld_process_parameters.h"

#include <fmt/core.h>
#include <SQLiteCpp/Exception.h>
#include <SQLiteCpp/Statement.h>
#include <SQLiteCpp/VariadicBind.h>

#include <cstdint>
#include <functional>
#include <nlohmann/json.hpp>
#include <nlohmann/json_fwd.hpp>
#include <optional>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

#include "common/logging/application_log.h"
#include "sql_table_names.h"
#include "weld_system_client/weld_system_types.h"

namespace weld_control {

auto WeldProcessParameters::Id() const -> int { return id_; }
auto WeldProcessParameters::Name() const -> std::string { return name_; }
auto WeldProcessParameters::MethodValue() const -> Method { return method_; }
auto WeldProcessParameters::RegulationTypeValue() const -> RegulationType { return regulation_type_; }
auto WeldProcessParameters::StartTypeValue() const -> StartType { return start_type_; }
auto WeldProcessParameters::StartAdjust() const -> uint32_t { return start_adjust_; }
auto WeldProcessParameters::Voltage() const -> float { return voltage_; }
auto WeldProcessParameters::Current() const -> float { return current_; }
auto WeldProcessParameters::WireSpeed() const -> float { return wire_speed_; }
auto WeldProcessParameters::IceWireSpeed() const -> float { return ice_wire_speed_; }
auto WeldProcessParameters::AcFrequency() const -> float { return ac_frequency_; }
auto WeldProcessParameters::AcOffset() const -> float { return ac_offset_; }
auto WeldProcessParameters::AcPhaseShift() const -> float { return ac_phase_shift_; }
auto WeldProcessParameters::CraterFillTime() const -> float { return crater_fill_time_; }
auto WeldProcessParameters::BurnBackTime() const -> float { return burn_back_time_; }

void WeldProcessParameters::SetId(int value) { id_ = value; }
void WeldProcessParameters::SetName(std::string value) { name_ = std::move(value); }
void WeldProcessParameters::SetMethod(Method value) { method_ = value; }
void WeldProcessParameters::SetRegulationType(RegulationType value) { regulation_type_ = value; }
void WeldProcessParameters::SetStartAdjust(uint32_t value) { start_adjust_ = value; }
void WeldProcessParameters::SetStartType(StartType value) { start_type_ = value; }
void WeldProcessParameters::SetVoltage(float value) { voltage_ = value; }
void WeldProcessParameters::SetCurrent(float value) { current_ = value; }
void WeldProcessParameters::SetWireSpeed(float value) { wire_speed_ = value; }
void WeldProcessParameters::SetIceWireSpeed(float value) { ice_wire_speed_ = value; }
void WeldProcessParameters::SetAcFrequency(float value) { ac_frequency_ = value; }
void WeldProcessParameters::SetAcOffset(float value) { ac_offset_ = value; }
void WeldProcessParameters::SetAcPhaseShift(float value) { ac_phase_shift_ = value; }
void WeldProcessParameters::SetCraterFillTime(float value) { crater_fill_time_ = value; }
void WeldProcessParameters::SetBurnBackTime(float value) { burn_back_time_ = value; }

auto WeldProcessParameters::IsValid() const -> bool {
  auto ok = true;

  ok &= !name_.empty();
  ok &= method_ != Method::INVALID;
  ok &= regulation_type_ != RegulationType::INVALID;
  ok &= start_type_ != StartType::INVALID;

  ok &= voltage_ >= 0.0f;
  ok &= current_ >= 0.0f;
  ok &= wire_speed_ >= 0.0f;
  ok &= ice_wire_speed_ >= 0.0f;
  ok &= ac_frequency_ >= 0.0f;
  ok &= ac_offset_ >= 0.0f;
  ok &= ac_phase_shift_ >= 0.0f;
  ok &= crater_fill_time_ >= 0.0f;
  ok &= burn_back_time_ >= 0.0f;

  ok &= ToWeldSystemSettings().has_value();

  return ok;
}

auto WeldProcessParameters::ToString() const -> std::string {
  return fmt::format(
      "id: {} name: {} method: {} regulation_type: {} start_adjust: {} start_type: {} voltage: {} current: {} "
      "wire_speed: {} ice_wire_speed: {} ac_frequency: {} ac_offset: {} ac_phase_shift: {} crater_fill_time: {} "
      "burn_back_time: {}",
      id_, name_, MethodToString(method_), RegulationTypeToString(regulation_type_), start_adjust_,
      StartTypeToString(start_type_), voltage_, current_, wire_speed_, ice_wire_speed_, ac_frequency_, ac_offset_,
      ac_phase_shift_, crater_fill_time_, burn_back_time_);
}

auto WeldProcessParameters::ToJson() const -> nlohmann::json {
  return {
      {"id",             id_                                     },
      {"name",           name_                                   },
      {"method",         MethodToString(method_)                 },
      {"regulationType", RegulationTypeToString(regulation_type_)},
      {"startAdjust",    start_adjust_                           },
      {"startType",      StartTypeToString(start_type_)          },
      {"voltage",        voltage_                                },
      {"current",        current_                                },
      {"wireSpeed",      wire_speed_                             },
      {"iceWireSpeed",   ice_wire_speed_                         },
      {"acFrequency",    ac_frequency_                           },
      {"acOffset",       ac_offset_                              },
      {"acPhaseShift",   ac_phase_shift_                         },
      {"craterFillTime", crater_fill_time_                       },
      {"burnBackTime",   burn_back_time_                         }
  };
}

auto WeldProcessParameters::FromJson(const nlohmann::json& json_obj) -> std::optional<WeldProcessParameters> {
  WeldProcessParameters wpp;
  try {
    wpp.SetName(json_obj.at("name").get<std::string>());
    wpp.SetMethod(MethodFromString(json_obj.at("method").get<std::string>()));
    wpp.SetRegulationType(RegulationTypeFromString(json_obj.at("regulationType").get<std::string>()));
    wpp.SetStartAdjust(json_obj.at("startAdjust").get<uint32_t>());
    wpp.SetStartType(StartTypeFromString(json_obj.at("startType").get<std::string>()));
    wpp.SetVoltage(json_obj.at("voltage").get<float>());
    wpp.SetCurrent(json_obj.at("current").get<float>());
    wpp.SetWireSpeed(json_obj.at("wireSpeed").get<float>());
    wpp.SetIceWireSpeed(json_obj.at("iceWireSpeed").get<float>());
    wpp.SetAcFrequency(json_obj.at("acFrequency").get<float>());
    wpp.SetAcOffset(json_obj.at("acOffset").get<float>());
    wpp.SetAcPhaseShift(json_obj.at("acPhaseShift").get<float>());
    wpp.SetCraterFillTime(json_obj.at("craterFillTime").get<float>());
    wpp.SetBurnBackTime(json_obj.at("burnBackTime").get<float>());
  } catch (const nlohmann::json::exception& e) {
    LOG_ERROR("Failed to parse WeldProcessParameters - exception: {}", e.what());
    return std::nullopt;
  }

  return wpp;
}

auto WeldProcessParameters::ToWeldSystemSettings() const -> std::optional<weld_system::WeldSystemSettings> {
  if (method_ == Method::INVALID || regulation_type_ == RegulationType::INVALID || start_type_ == StartType::INVALID) {
    return std::nullopt;
  }

  weld_system::WeldSystemSettings settings;
  // Method enum: INVALID=0, DC=1, DC_NEG=2, AC=3 -> WeldSystemSettings: DC=0, DC_NEG=1, AC=2
  settings.method = static_cast<weld_system::WeldSystemSettings::Method>(static_cast<uint32_t>(method_) - 1);
  // RegulationType enum: INVALID=0, CW=1, CA=2, CC=3 -> WeldSystemSettings: CW=0, CA=1, CC=2
  settings.regulation_type =
      static_cast<weld_system::WeldSystemSettings::RegulationType>(static_cast<uint32_t>(regulation_type_) - 1);
  // StartType enum: INVALID=0, DIRECT=1, SCRATCH=2 -> WeldSystemSettings: DIRECT=0, SCRATCH=1
  settings.start_type = static_cast<weld_system::WeldSystemSettings::StartType>(static_cast<uint32_t>(start_type_) - 1);
  settings.start_adjust     = start_adjust_;
  settings.voltage          = voltage_;
  settings.current          = current_;
  settings.wire_speed       = wire_speed_;
  settings.ice_wire_speed   = ice_wire_speed_;
  settings.ac_frequency     = ac_frequency_;
  settings.ac_offset        = ac_offset_;
  settings.ac_phase_shift   = ac_phase_shift_;
  settings.crater_fill_time = crater_fill_time_;
  settings.burn_back_time   = burn_back_time_;
  return settings;
}

void WeldProcessParameters::CreateTable(SQLite::Database* db) {
  if (db->tableExists(WELD_PROCESS_PARAMETERS_TABLE_NAME)) {
    return;
  }

  std::string cmd = fmt::format(
      "CREATE TABLE {} ("
      "id INTEGER PRIMARY KEY AUTOINCREMENT, "
      "data_json TEXT NOT NULL)",
      WELD_PROCESS_PARAMETERS_TABLE_NAME);

  db->exec(cmd);
}

auto WeldProcessParameters::StoreFn() -> std::function<bool(SQLite::Database*, const WeldProcessParameters&)> {
  return [](SQLite::Database* db, const WeldProcessParameters& wpp) -> bool {
    try {
      std::string cmd = fmt::format("INSERT INTO {} (data_json) VALUES (?)", WELD_PROCESS_PARAMETERS_TABLE_NAME);
      SQLite::Statement query(*db, cmd);
      SQLite::bind(query, wpp.ToJson().dump());
      return query.exec() == 1;
    } catch (const SQLite::Exception& e) {
      LOG_ERROR("Failed to store weld process parameters - exception: {}", e.what());
      return false;
    }
  };
}

auto WeldProcessParameters::UpdateFn() -> std::function<bool(SQLite::Database*, int, const WeldProcessParameters&)> {
  return [](SQLite::Database* db, int id, const WeldProcessParameters& wpp) -> bool {
    try {
      std::string cmd = fmt::format("UPDATE {} SET data_json = ? WHERE id = ?", WELD_PROCESS_PARAMETERS_TABLE_NAME);
      SQLite::Statement query(*db, cmd);
      SQLite::bind(query, wpp.ToJson().dump(), id);
      return query.exec() == 1;
    } catch (const SQLite::Exception& e) {
      LOG_ERROR("Failed to update weld process parameters id {} - exception: {}", id, e.what());
      return false;
    }
  };
}

auto WeldProcessParameters::RemoveFn() -> std::function<bool(SQLite::Database*, int)> {
  return [](SQLite::Database* db, int id) -> bool {
    try {
      std::string cmd = fmt::format("DELETE FROM {} WHERE id = ?", WELD_PROCESS_PARAMETERS_TABLE_NAME);
      SQLite::Statement query(*db, cmd);
      SQLite::bind(query, id);
      return query.exec() == 1;
    } catch (const SQLite::Exception& e) {
      LOG_ERROR("Failed to remove weld process parameters - exception: {}", e.what());
      return false;
    }
  };
}

auto WeldProcessParameters::GetAllFn() -> std::function<std::vector<WeldProcessParameters>(SQLite::Database*)> {
  return [](SQLite::Database* db) -> std::vector<WeldProcessParameters> {
    std::vector<WeldProcessParameters> result;
    std::string cmd = fmt::format("SELECT id, data_json FROM {}", WELD_PROCESS_PARAMETERS_TABLE_NAME);
    SQLite::Statement query(*db, cmd);

    while (query.executeStep()) {
      int id               = query.getColumn(0).getInt();
      std::string json_str = query.getColumn(1).getString();
      auto opt             = WeldProcessParameters::FromJson(nlohmann::json::parse(json_str));
      if (opt.has_value()) {
        auto wpp = opt.value();
        wpp.SetId(id);
        result.push_back(wpp);
      }
    }

    return result;
  };
}

auto WeldProcessParameters::MethodToString(Method value) -> std::string {
  switch (value) {
    case Method::DC:
      return "dc";
    case Method::DC_NEG:
      return "dc_neg";
    case Method::AC:
      return "ac";
    default:
      return "invalid";
  }
}

auto WeldProcessParameters::RegulationTypeToString(RegulationType value) -> std::string {
  switch (value) {
    case RegulationType::CW:
      return "cw";
    case RegulationType::CA:
      return "ca";
    case RegulationType::CC:
      return "cc";
    default:
      return "invalid";
  }
}

auto WeldProcessParameters::StartTypeToString(StartType value) -> std::string {
  switch (value) {
    case StartType::DIRECT:
      return "direct";
    case StartType::SCRATCH:
      return "scratch";
    default:
      return "invalid";
  }
}

auto WeldProcessParameters::MethodFromString(const std::string& str) -> Method {
  static const std::unordered_map<std::string, Method> MAP = {
      {"dc",     Method::DC    },
      {"dc_neg", Method::DC_NEG},
      {"ac",     Method::AC    }
  };

  auto it = MAP.find(str);
  return it != MAP.end() ? it->second : Method::INVALID;
}

auto WeldProcessParameters::RegulationTypeFromString(const std::string& str) -> RegulationType {
  static const std::unordered_map<std::string, RegulationType> MAP = {
      {"cw", RegulationType::CW},
      {"ca", RegulationType::CA},
      {"cc", RegulationType::CC}
  };

  auto it = MAP.find(str);
  return it != MAP.end() ? it->second : RegulationType::INVALID;
}

auto WeldProcessParameters::StartTypeFromString(const std::string& str) -> StartType {
  static const std::unordered_map<std::string, StartType> MAP = {
      {"direct",  StartType::DIRECT },
      {"scratch", StartType::SCRATCH}
  };

  auto it = MAP.find(str);
  return it != MAP.end() ? it->second : StartType::INVALID;
}

}  // namespace weld_control
