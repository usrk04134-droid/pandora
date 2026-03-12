#include "weld_data_set.h"

#include <fmt/core.h>
#include <SQLiteCpp/Exception.h>
#include <SQLiteCpp/Statement.h>
#include <SQLiteCpp/VariadicBind.h>

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

auto WeldDataSet::Id() const -> int { return id_; }
auto WeldDataSet::Name() const -> std::string { return name_; }
auto WeldDataSet::Ws1WppId() const -> int { return ws1_wpp_id_; }
auto WeldDataSet::Ws2WppId() const -> int { return ws2_wpp_id_; }

void WeldDataSet::SetId(int v) { id_ = v; }
void WeldDataSet::SetName(std::string v) { name_ = std::move(v); }
void WeldDataSet::SetWs1WppId(int v) { ws1_wpp_id_ = v; }
void WeldDataSet::SetWs2WppId(int v) { ws2_wpp_id_ = v; }

auto WeldDataSet::IsValid() const -> bool {
  auto ok = true;

  ok &= !name_.empty();
  ok &= ws1_wpp_id_ > 0;

  return ok;
}

auto WeldDataSet::ToString() const -> std::string {
  return fmt::format("WeldDataSet(id={}, name={}, ws1_wpp_id={}, ws2_wpp_id={})", id_, name_, ws1_wpp_id_, ws2_wpp_id_);
}

auto WeldDataSet::ToJson() const -> nlohmann::json {
  return {
      {"id",       id_        },
      {"name",     name_      },
      {"ws1WppId", ws1_wpp_id_},
      {"ws2WppId", ws2_wpp_id_}
  };
}

auto WeldDataSet::FromJson(const nlohmann::json& json) -> std::optional<WeldDataSet> {
  WeldDataSet wds;
  try {
    std::string name;
    int ws1{};
    int ws2{};

    json.at("name").get_to(name);
    json.at("ws1WppId").get_to(ws1);
    json.at("ws2WppId").get_to(ws2);

    wds.SetName(name);
    wds.SetWs1WppId(ws1);
    wds.SetWs2WppId(ws2);

  } catch (const nlohmann::json::exception& e) {
    LOG_ERROR("Failed to parse WeldDataSet from JSON - exception: {}", e.what());
    return std::nullopt;
  }

  return wds;
}

void WeldDataSet::CreateTable(SQLite::Database* db) {
  if (db->tableExists(WELD_DATA_SET_TABLE_NAME)) {
    return;
  }

  std::string const cmd = fmt::format(
      "CREATE TABLE {} ("
      "id INTEGER PRIMARY KEY AUTOINCREMENT, "
      "data_json TEXT NOT NULL)",
      WELD_DATA_SET_TABLE_NAME);

  db->exec(cmd);
}

auto WeldDataSet::StoreFn() -> std::function<bool(SQLite::Database*, const WeldDataSet&)> {
  return [](SQLite::Database* db, const WeldDataSet& wds) -> bool {
    try {
      std::string const cmd = fmt::format("INSERT INTO {} (data_json) VALUES (?)", WELD_DATA_SET_TABLE_NAME);
      SQLite::Statement query(*db, cmd);
      SQLite::bind(query, wds.ToJson().dump());
      return query.exec() == 1;
    } catch (const SQLite::Exception& e) {
      LOG_ERROR("Failed to store WeldDataSet - exception: {}", e.what());
      return false;
    }
  };
}

auto WeldDataSet::UpdateFn() -> std::function<bool(SQLite::Database*, int, const WeldDataSet&)> {
  return [](SQLite::Database* db, int id, const WeldDataSet& wds) -> bool {
    try {
      std::string const cmd = fmt::format("UPDATE {} SET data_json = ? WHERE id = ?", WELD_DATA_SET_TABLE_NAME);
      SQLite::Statement query(*db, cmd);
      SQLite::bind(query, wds.ToJson().dump(), id);
      return query.exec() == 1;
    } catch (const SQLite::Exception& e) {
      LOG_ERROR("Failed to update WeldDataSet id {} - exception: {}", id, e.what());
      return false;
    }
  };
}

auto WeldDataSet::RemoveFn() -> std::function<bool(SQLite::Database*, int)> {
  return [](SQLite::Database* db, int id) -> bool {
    try {
      std::string const cmd = fmt::format("DELETE FROM {} WHERE id = ?", WELD_DATA_SET_TABLE_NAME);
      SQLite::Statement query(*db, cmd);
      SQLite::bind(query, id);
      return query.exec() == 1;
    } catch (const SQLite::Exception& e) {
      LOG_ERROR("Failed to remove WeldDataSet - exception: {}", e.what());
      return false;
    }
  };
}

auto WeldDataSet::GetAllFn() -> std::function<std::vector<WeldDataSet>(SQLite::Database*)> {
  return [](SQLite::Database* db) -> std::vector<WeldDataSet> {
    std::vector<WeldDataSet> result;

    std::string const cmd = fmt::format("SELECT id, data_json FROM {}", WELD_DATA_SET_TABLE_NAME);
    SQLite::Statement query(*db, cmd);

    while (query.executeStep()) {
      int id               = query.getColumn(0).getInt();
      std::string json_str = query.getColumn(1).getString();
      auto opt             = WeldDataSet::FromJson(nlohmann::json::parse(json_str));
      if (opt.has_value()) {
        auto wds = opt.value();
        wds.SetId(id);
        result.push_back(wds);
      }
    }

    return result;
  };
}

}  // namespace weld_control
