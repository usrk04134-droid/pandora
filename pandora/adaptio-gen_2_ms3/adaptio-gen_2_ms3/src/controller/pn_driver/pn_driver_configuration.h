#pragma once

#include <cstdint>
#include <filesystem>
#include <string>
#include <vector>

namespace controller::pn_driver {

struct Configuration {
  std::filesystem::path rema_path;
  std::vector<uint8_t> mac_address;
  std::string interface;
};

}  // namespace controller::pn_driver
