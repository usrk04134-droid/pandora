#include "joint_geometry/joint_geometry.h"

#include <fmt/core.h>

#include <string>

auto joint_geometry::JointGeometry::ToString() const -> std::string {
  return fmt::format(
      "width: {:.1f} depth: {:.1f} left_angle(rad) {:.3f} right_angle(rad) {:.3f} left_max_surface_angle(rad) {:.3f} "
      "right_max_surface_angle(rad) {:.3f} type: {}",
      upper_joint_width_mm, groove_depth_mm, left_joint_angle_rad, right_joint_angle_rad, left_max_surface_angle_rad,
      right_max_surface_angle_rad, joint_geometry::TypeToString(type));
}

auto joint_geometry::TypeToString(Type type) -> std::string {
  switch (type) {
    case Type::CW:
      return "cw";
    case Type::LW:
      return "lw";
    default:
      return "invalid";
  }
}

auto joint_geometry::StringToType(const std::string& s) -> Type {
  if (s == "cw") return Type::CW;
  if (s == "lw") return Type::LW;
  return Type::INVALID;
}