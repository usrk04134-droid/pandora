#pragma once

#include <array>
#include <Eigen/Core>

#include "common/geometric_primitives/src/point3d.h"
#include "common/groove/point.h"
#include "common/types/vector_3d.h"
#include "lpcs/lpcs_point.h"
#include "weld_motion_prediction/configurable_transform.h"
#include "weld_motion_prediction/transformer.h"

namespace weld_motion_prediction {

using geometric_primitives::Point3d;

class LpcsToMacsTransformer : public Transformer, public ConfigurableTransform {
 public:
  LpcsToMacsTransformer() = default;
  // Configurable transform interface
  auto SetTransform(std::array<double, 3>& scanner_angles, const common::Vector3D& tcs_to_lpcs_translation)
      -> void override;
  auto UpdateMacsToTcsTranslation(const common::Point& slide_position) -> void override;
  auto ComputeLpcsOrientation(const std::array<double, 3>& scanner_angles) const -> Eigen::Matrix3d override;
  auto Reset() -> void override;

  // Transformer interface
  auto LpcsToMacs(const Point3d& point_lpcs, bool use_translation) const -> Point3d override;
  auto MacsToLpcs(const Point3d& point_macs, bool use_translation) const -> Point3d override;

 private:
  // double scanner_mount_angle_{0.0};
  // double delta_rot_y_{0.0};
  // double delta_rot_z_{0.0};
  std::array<double, 3> scanner_angles_{};
  common::Vector3D tcs_to_lpcs_translation_{};
  common::Vector3D macs_to_tcs_translation_{};

  auto static CreateRotationMatrix(double angle, Eigen::Vector3d& rot_axis) -> Eigen::Matrix3d;
};

}  // namespace weld_motion_prediction
