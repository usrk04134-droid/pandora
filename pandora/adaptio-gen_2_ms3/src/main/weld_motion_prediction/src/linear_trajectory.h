#pragma once

#include "common/types/vector_3d.h"
#include "weld_motion_prediction/configurable_linear_trajectory.h"
namespace weld_motion_prediction {

class LinearTrajectory : public ConfigurableLinearTrajectory {
 public:
  LinearTrajectory() = default;

  // Trajectory interface
  auto Intersect(const Plane3d& plane) const -> std::pair<Point3d, double> override;
  auto AttachToPoint(Point3d point_on_trajectory) -> void override;

  // ConfigurableCircleTrajectory
  auto Set(const common::Vector3D& direction_of_motion) -> void override;

 private:
  common::Vector3D direction_of_motion_;
  Point3d attachment_point_macs_;
};

}  // namespace weld_motion_prediction
