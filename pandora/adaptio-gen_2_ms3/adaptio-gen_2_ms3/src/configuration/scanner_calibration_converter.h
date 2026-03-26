#pragma once

#include <any>
#include <expected>
#include <filesystem>
#include <string>

#include "common/data/data_value.h"
#include "common/file/yaml.h"
#include "conf_file_handler.h"
#include "configuration/converter.h"
#include "scanner/core/scanner_calibration_configuration.h"

namespace configuration {

using common::data::DataValue;
using common::file::YamlPtr;

class ScannerCalibrationConverter : public Converter {
 public:
  explicit ScannerCalibrationConverter(const std::string& tag, const std::filesystem::path& yaml_file);

  auto ReadPersistentData() -> std::expected<void, std::error_code> override;
  auto WritePersistentData(std::any config_struct) -> std::expected<void, std::error_code> override;
  auto GetConfig() -> std::any override { return scanner_calibration_; };

 private:
  std::string tag_;
  std::filesystem::path yaml_file_;
  FileHandlerPtr fh_;

  // The struct that is mapped to a yaml file
  scanner::ScannerCalibrationData scanner_calibration_;
};
}  // namespace configuration
