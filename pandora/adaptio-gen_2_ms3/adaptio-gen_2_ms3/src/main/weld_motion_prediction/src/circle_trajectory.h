
#pragma once

#include "common/geometric_primitives/src/circle3d.h"
#include "common/geometric_primitives/src/plane3d.h"
#include "common/geometric_primitives/src/point3d.h"
#include "common/types/vector_3d.h"
#include "weld_motion_prediction/configurable_circle_trajectory.h"

namespace weld_motion_prediction {

using geometric_primitives::Circle3d;
using geometric_primitives::Plane3d;
using geometric_primitives::Point3d;

class CircleTrajectory : public ConfigurableCircleTrajectory {
 public:
  CircleTrajectory() = default;

  // Trajectory interface
  auto Intersect(const Plane3d& plane) const -> std::pair<Point3d, double> override;
  auto AttachToPoint(Point3d point_on_trajectory) -> void override;

  // ConfigurableCircleTrajectory
  auto Set(const common::Vector3D& rot_center, const common::Vector3D& weld_object_rotation_axis) -> void override;

 private:
  common::Vector3D rot_center_;
  common::Vector3D weld_object_rotation_axis_;
  Point3d attachment_point_macs_;

  auto CreateProjectionCircle(const Point3d& point_to_project) const -> Circle3d;
  auto FindPointWithShortestTrajectory(std::vector<Point3d>& points, Circle3d& projection_circle) const
      -> std::pair<Point3d, double>;
};

}  // Namespace weld_motion_prediction
