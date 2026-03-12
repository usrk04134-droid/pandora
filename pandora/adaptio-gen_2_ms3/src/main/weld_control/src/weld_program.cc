#include "weld_program.h"

#include <fmt/core.h>
#include <SQLiteCpp/Exception.h>
#include <SQLiteCpp/Statement.h>
#include <SQLiteCpp/VariadicBind.h>
#include <sys/types.h>

#include <exception>
#include <functional>
#include <nlohmann/json.hpp>
#include <nlohmann/json_fwd.hpp>
#include <optional>
#include <string>
#include <utility>
#include <vector>

#include "common/logging/application_log.h"
#include "sql_table_names.h"

namespace weld_control {

auto WeldProgram::Id() const -> int { return id_; }
auto WeldProgram::Name() const -> std::string { return name_; }
auto WeldProgram::GrooveId() const -> int { return groove_id_; }
auto WeldProgram::Layers() const -> std::vector<WeldProgramLayer> { return layers_; }

void WeldProgram::SetId(int v) { id_ = v; }
void WeldProgram::SetName(std::string v) { name_ = std::move(v); }
void WeldProgram::SetGrooveId(int v) { groove_id_ = v; }
void WeldProgram::SetLayers(std::vector<WeldProgramLayer> v) { layers_ = std::move(v); }

void WeldProgram::AddLayer(WeldProgramLayer const& layer) { layers_.push_back(layer); }

auto WeldProgram::NumLayers() const -> uint { return layers_.size(); }

auto WeldProgram::IsValid() const -> bool {
  auto ok = true;

  ok &= !name_.empty();
  ok &= groove_id_ >= 0;
  ok &= !layers_.empty();

  return ok;
}

auto WeldProgram::ToString() const -> std::string {
  std::string layer_str;
  for (const auto& layer : layers_) {
    layer_str +=
        fmt::format("{{ layer_number: {}, weld_data_set_id: {} }}, ", layer.layer_number, layer.weld_data_set_id);
  }
  if (!layer_str.empty()) {
    layer_str.pop_back();
    layer_str.pop_back();
  }
  return fmt::format("id: {} name: {} groove_id: {} layers: [{}]", id_, name_, groove_id_, layer_str);
}

auto WeldProgram::ToJson() const -> nlohmann::json {
  nlohmann::json json_layers = nlohmann::json::array();
  for (const auto& layer : layers_) {
    json_layers.push_back({
        {"layerNumber",   layer.layer_number    },
        {"weldDataSetId", layer.weld_data_set_id}
    });
  }
  return {
      {"id",       id_        },
      {"name",     name_      },
      {"grooveId", groove_id_ },
      {"layers",   json_layers}
  };
}

auto WeldProgram::FromJson(const nlohmann::json& payload) -> std::optional<WeldProgram> {
  WeldProgram wp;
  try {
    wp.name_      = payload.at("name").get<std::string>();
    wp.groove_id_ = payload.at("grooveId").get<int>();

    for (const auto& layer_json : payload.at("layers")) {
      WeldProgramLayer layer;
      layer.layer_number     = layer_json.at("layerNumber").get<int>();
      layer.weld_data_set_id = layer_json.at("weldDataSetId").get<int>();
      wp.layers_.push_back(layer);
    }
  } catch (const nlohmann::json::exception& e) {
    LOG_ERROR("Failed to parse WeldProgram from JSON - exception: {}", e.what());
    return std::nullopt;
  }

  return wp;
}

void WeldProgram::CreateTable(SQLite::Database* db) {
  if (db->tableExists(WELD_PROGRAMS_TABLE_NAME)) {
    return;
  }

  try {
    std::string cmd = fmt::format(
        "CREATE TABLE {} ("
        "id INTEGER PRIMARY KEY AUTOINCREMENT, "
        "data_json TEXT NOT NULL)",
        WELD_PROGRAMS_TABLE_NAME);
    db->exec(cmd);
  } catch (const std::exception& e) {
    LOG_ERROR("Failed to create {} table - exception: {}", WELD_PROGRAMS_TABLE_NAME, e.what());
  }
}

auto WeldProgram::GetAllFn() -> std::function<std::vector<WeldProgram>(SQLite::Database*)> {
  return [](SQLite::Database* db) -> std::vector<WeldProgram> {
    std::vector<WeldProgram> result;
    std::string query_str = fmt::format("SELECT id, data_json FROM {}", WELD_PROGRAMS_TABLE_NAME);
    SQLite::Statement query(*db, query_str);

    while (query.executeStep()) {
      int id               = query.getColumn(0).getInt();
      std::string json_str = query.getColumn(1).getString();
      auto opt             = WeldProgram::FromJson(nlohmann::json::parse(json_str));
      if (opt.has_value()) {
        auto wp = opt.value();
        wp.SetId(id);
        result.push_back(std::move(wp));
      }
    }

    return result;
  };
}

auto WeldProgram::RemoveFn() -> std::function<bool(SQLite::Database*, int)> {
  return [](SQLite::Database* db, int id) -> bool {
    try {
      std::string cmd = fmt::format("DELETE FROM {} WHERE id = ?", WELD_PROGRAMS_TABLE_NAME);
      SQLite::Statement query(*db, cmd);
      SQLite::bind(query, id);
      return query.exec() == 1;
    } catch (const std::exception& e) {
      LOG_ERROR("Failed to remove WeldProgram id {} - exception: {}", id, e.what());
      return false;
    }
  };
}

auto WeldProgram::UpdateFn() -> std::function<bool(SQLite::Database*, int, const WeldProgram&)> {
  return [](SQLite::Database* db, int id, const WeldProgram& wp) -> bool {
    try {
      std::string cmd = fmt::format("UPDATE {} SET data_json = ? WHERE id = ?", WELD_PROGRAMS_TABLE_NAME);
      SQLite::Statement query(*db, cmd);
      SQLite::bind(query, wp.ToJson().dump(), id);
      return query.exec() == 1;
    } catch (const SQLite::Exception& e) {
      LOG_ERROR("Failed to update WeldProgram id {} - exception: {}", id, e.what());
      return false;
    }
  };
}

auto WeldProgram::StoreFn() -> std::function<bool(SQLite::Database*, const WeldProgram&)> {
  return [](SQLite::Database* db, const WeldProgram& wp) -> bool {
    try {
      std::string cmd = fmt::format("INSERT INTO {} (data_json) VALUES (?)", WELD_PROGRAMS_TABLE_NAME);
      SQLite::Statement query(*db, cmd);
      SQLite::bind(query, wp.ToJson().dump());
      return query.exec() == 1;
    } catch (const SQLite::Exception& e) {
      LOG_ERROR("Failed to store WeldProgram '{}' - exception: {}", wp.Name(), e.what());
      return false;
    }
  };
}

}  // namespace weld_control
