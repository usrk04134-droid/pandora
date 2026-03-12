#pragma once

#include <string>

namespace joint_geometry {

enum class Type { INVALID = 0, CW, LW };
auto TypeToString(Type type) -> std::string;
auto StringToType(const std::string& s) -> Type;

struct JointGeometry {
  double upper_joint_width_mm;
  double groove_depth_mm;
  double left_joint_angle_rad;
  double right_joint_angle_rad;
  double left_max_surface_angle_rad;
  double right_max_surface_angle_rad;
  Type type;
  auto ToString() const -> std::string;
};

}  // namespace joint_geometry
