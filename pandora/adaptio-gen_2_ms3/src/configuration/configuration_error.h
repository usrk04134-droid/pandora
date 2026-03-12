#pragma once

#include <cstdint>
#include <system_error>

namespace configuration {

enum class ConfigurationErrorCode : uint32_t {
  NO_ERROR                         = 0,
  CONFIGURATION_READ_FILE_ERROR    = 1,
  CONFIGURATION_WRITE_FILE_MISSING = 2,
  CONFIGURATION_MISSING_CHECKSUM   = 3,
  CONFIGURATION_INVALID_CHECKSUM   = 4,
};
// NOLINTNEXTLINE(*-identifier-naming)
[[maybe_unused]] auto make_error_code(ConfigurationErrorCode) -> std::error_code;

}  // namespace configuration

namespace std {
template <>
struct is_error_code_enum<configuration::ConfigurationErrorCode> : true_type {};
}  // namespace std
