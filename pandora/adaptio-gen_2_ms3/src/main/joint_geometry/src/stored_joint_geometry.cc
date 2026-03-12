#include "stored_joint_geometry.h"

#include <fmt/core.h>
#include <SQLiteCpp/Exception.h>
#include <SQLiteCpp/Statement.h>
#include <SQLiteCpp/VariadicBind.h>

#include <exception>
#include <functional>
#include <nlohmann/json_fwd.hpp>
#include <optional>
#include <string>
#include <utility>
#include <vector>

#include "common/logging/application_log.h"

namespace joint_geometry {

const std::string JOINT_GEOMETRY_TABLE_NAME = "joint_geometry_2";

auto StoredJointGeometry::Id() const -> int { return id_; }
auto StoredJointGeometry::Name() const -> std::string { return name_; }
auto StoredJointGeometry::UpperJointWidth() const -> double { return upper_joint_width_mm_; }
auto StoredJointGeometry::GrooveDepth() const -> double { return groove_depth_mm_; }
auto StoredJointGeometry::LeftJointAngle() const -> double { return left_joint_angle_rad_; }
auto StoredJointGeometry::RightJointAngle() const -> double { return right_joint_angle_rad_; }
auto StoredJointGeometry::LeftMaxSurfaceAngle() const -> double { return left_max_surface_angle_rad_; }
auto StoredJointGeometry::RightMaxSurfaceAngle() const -> double { return right_max_surface_angle_rad_; }
auto StoredJointGeometry::Type() const -> joint_geometry::Type { return type_; }

void StoredJointGeometry::SetId(int value) { id_ = value; }
void StoredJointGeometry::SetName(std::string value) { name_ = std::move(value); }
void StoredJointGeometry::SetUpperJointWidth(double value) { upper_joint_width_mm_ = value; }
void StoredJointGeometry::SetGrooveDepth(double value) { groove_depth_mm_ = value; }
void StoredJointGeometry::SetLeftJointAngle(double value) { left_joint_angle_rad_ = value; }
void StoredJointGeometry::SetRightJointAngle(double value) { right_joint_angle_rad_ = value; }
void StoredJointGeometry::SetLeftMaxSurfaceAngle(double value) { left_max_surface_angle_rad_ = value; }
void StoredJointGeometry::SetRightMaxSurfaceAngle(double value) { right_max_surface_angle_rad_ = value; }
void StoredJointGeometry::SetType(joint_geometry::Type value) { type_ = value; }

auto StoredJointGeometry::IsValid() const -> bool {
  auto ok = true;

  ok &= !name_.empty();

  ok &= upper_joint_width_mm_ > 0.0;
  ok &= groove_depth_mm_ > 0.0;
  ok &= left_joint_angle_rad_ > 0.0;
  ok &= right_joint_angle_rad_ > 0.0;
  ok &= (type_ == Type::CW || type_ == Type::LW);

  return ok;
}

auto StoredJointGeometry::ToJson() const -> nlohmann::json {
  return {
      {"id",                          id_                         },
      {"name",                        name_                       },
      {"upper_joint_width_mm",        upper_joint_width_mm_       },
      {"groove_depth_mm",             groove_depth_mm_            },
      {"left_joint_angle_rad",        left_joint_angle_rad_       },
      {"right_joint_angle_rad",       right_joint_angle_rad_      },
      {"left_max_surface_angle_rad",  left_max_surface_angle_rad_ },
      {"right_max_surface_angle_rad", right_max_surface_angle_rad_},
      {"type",                        TypeToString(type_)         },
  };
}

auto StoredJointGeometry::FromJson(const nlohmann::json& json_obj) -> std::optional<StoredJointGeometry> {
  StoredJointGeometry sjg;
  try {
    sjg.SetId(json_obj.at("id").get<int>());
    sjg.SetName(json_obj.at("name").get<std::string>());
    sjg.SetUpperJointWidth(json_obj.at("upper_joint_width_mm").get<double>());
    sjg.SetGrooveDepth(json_obj.at("groove_depth_mm").get<double>());
    sjg.SetLeftJointAngle(json_obj.at("left_joint_angle_rad").get<double>());
    sjg.SetRightJointAngle(json_obj.at("right_joint_angle_rad").get<double>());
    sjg.SetLeftMaxSurfaceAngle(json_obj.at("left_max_surface_angle_rad").get<double>());
    sjg.SetRightMaxSurfaceAngle(json_obj.at("right_max_surface_angle_rad").get<double>());
    const auto& type_val = json_obj.at("type");
    sjg.SetType(StringToType(type_val.get<std::string>()));
  } catch (const nlohmann::json::exception& e) {
    LOG_ERROR("Failed to parse Joint Geometry  from JSON - exception: {}", e.what());
    return std::nullopt;
  }

  return sjg;
}

auto StoredJointGeometry::ToString() const -> std::string {
  return fmt::format(
      "id: {} name: {} upper_joint_width_mm: {} groove_depth_mm: {} left_joint_angle_rad: {} "
      "right_joint_angle_rad: {}"
      "left_max_surface_angle_rad: {} "
      "right_max_surface_angle_rad: {} type: {}",
      id_, name_, upper_joint_width_mm_, groove_depth_mm_, left_joint_angle_rad_, right_joint_angle_rad_,
      left_max_surface_angle_rad_, right_max_surface_angle_rad_, TypeToString(type_));
}

void StoredJointGeometry::CreateTable(SQLite::Database* db) {
  if (db == nullptr) {
    return;
  }
  if (db->tableExists(JOINT_GEOMETRY_TABLE_NAME)) {
    return;
  }
  std::string cmd = fmt::format(
      "CREATE TABLE {} ("
      "id INTEGER PRIMARY KEY AUTOINCREMENT, "
      "geometry_json TEXT NOT NULL"
      ");",
      JOINT_GEOMETRY_TABLE_NAME);
  db->exec(cmd);
}

auto StoredJointGeometry::StoreFn() -> std::function<bool(SQLite::Database*, const StoredJointGeometry&)> {
  return [](SQLite::Database* db, const StoredJointGeometry& sjg) -> bool {
    try {
      std::string cmd =
          fmt::format("INSERT OR REPLACE INTO {} (id, geometry_json) VALUES (?, ?)", JOINT_GEOMETRY_TABLE_NAME);

      SQLite::Statement query(*db, cmd);
      SQLite::bind(query, sjg.Id(), sjg.ToJson().dump());

      return query.exec() > 0;
    } catch (const std::exception& e) {
      LOG_ERROR("Failed to store joint geometry  - exception: {}", e.what());
      return false;
    }
  };
}

auto StoredJointGeometry::UpdateFn() -> std::function<bool(SQLite::Database*, int, const StoredJointGeometry&)> {
  return [](SQLite::Database* db, int id, const StoredJointGeometry& sjg) -> bool {
    try {
      std::string cmd = fmt::format("UPDATE {} SET geometry_json = ? WHERE id = ?", JOINT_GEOMETRY_TABLE_NAME);

      SQLite::Statement query(*db, cmd);
      SQLite::bind(query, sjg.ToJson().dump(), id);

      return query.exec() == 1;
    } catch (const std::exception& e) {
      LOG_ERROR("Failed to update joint geometry id {} - exception: {}", id, e.what());
      return false;
    }
  };
}

auto StoredJointGeometry::RemoveFn() -> std::function<bool(SQLite::Database*, int)> {
  return [](SQLite::Database* db, int id) -> bool {
    try {
      std::string cmd = fmt::format("DELETE FROM {} WHERE id = ?", JOINT_GEOMETRY_TABLE_NAME);
      SQLite::Statement query(*db, cmd);
      SQLite::bind(query, id);
      return query.exec() == 1;
    } catch (const SQLite::Exception& e) {
      LOG_ERROR("Failed to remove joint geometry  - exception: {}", e.what());
      return false;
    }
  };
}

auto StoredJointGeometry::GetAllFn() -> std::function<std::vector<StoredJointGeometry>(SQLite::Database*)> {
  return [](SQLite::Database* db) -> std::vector<StoredJointGeometry> {
    std::vector<StoredJointGeometry> result;
    std::string cmd = fmt::format("SELECT id, geometry_json FROM {}", JOINT_GEOMETRY_TABLE_NAME);
    SQLite::Statement query(*db, cmd);

    while (query.executeStep()) {
      int id               = query.getColumn(0).getInt();
      std::string json_str = query.getColumn(1).getString();
      auto opt             = StoredJointGeometry::FromJson(nlohmann::json::parse(json_str));
      if (opt.has_value()) {
        StoredJointGeometry sjg = opt.value();
        sjg.SetId(id);

        result.push_back(sjg);
      }
    }

    return result;
  };
}
}  // namespace joint_geometry
