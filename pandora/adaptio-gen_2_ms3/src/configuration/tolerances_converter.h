#pragma once

#include <any>
#include <expected>
#include <filesystem>
#include <memory>
#include <optional>
#include <string>

#include "common/file/yaml.h"
#include "common/logging/application_log.h"
#include "common/tolerances/tolerances_configuration.h"
#include "conf_file_handler.h"
#include "configuration/converter.h"
#include "configuration_error.h"

namespace configuration {

using common::data::DataValue;

class TolerancesConverter {
 public:
  static auto ToStruct(const std::unordered_map<std::string, DataValue>& map, const std::filesystem::path& yaml_file,
                       tolerances::Configuration& config) -> std::expected<void, std::error_code> {
    const std::string tag = "configuration/tolerances";

    try {
      TryUpdate(map, tag + "/joint_geometry/upper_width", config.joint_geometry.upper_width);
      TryUpdate(map, tag + "/joint_geometry/surface_angle", config.joint_geometry.surface_angle);
      TryUpdate(map, tag + "/joint_geometry/wall_angle", config.joint_geometry.wall_angle);
    } catch (const std::exception& e) {
      LOG_ERROR("Format of configuration file is not supported: file: {} error: {}", yaml_file.string(), e.what());
      return std::unexpected{make_error_code(ConfigurationErrorCode::CONFIGURATION_READ_FILE_ERROR)};
    }
    return {};
  }
};

}  // namespace configuration
