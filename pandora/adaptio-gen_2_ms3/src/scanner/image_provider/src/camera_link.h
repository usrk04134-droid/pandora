#pragma once

#include <string>

namespace scanner::image_provider {

const std::string CAMERA_IF_NAME = "camera1";

class CameraLink {
 public:
  static void Bounce();

 private:
  static auto IsUp() -> bool;
  static void SetLinkUp(bool up);
};
}  // namespace scanner::image_provider
