#include "linear_trajectory.h"

#include <cmath>
#include <Eigen/Core>

#include "common/geometric_primitives/src/coordinate-systems.h"
#include "common/geometric_primitives/src/line3d.h"
#include "common/geometric_primitives/src/plane3d.h"
#include "common/geometric_primitives/src/point3d.h"
#include "common/types/vector_3d.h"

namespace weld_motion_prediction {

using geometric_primitives::Line3d;
using geometric_primitives::Plane3d;
using geometric_primitives::Point3d;

const double UNIT_LENGTH{1.0};

auto LinearTrajectory::Intersect(const Plane3d& plane) const -> std::pair<Point3d, double> {
  Line3d projection_line = {
      {direction_of_motion_.c1, direction_of_motion_.c2, direction_of_motion_.c3},
      attachment_point_macs_, UNIT_LENGTH
  };
  auto maybe_intersection = projection_line.Intersect(plane, false);

  if (maybe_intersection) {
    double distance = attachment_point_macs_.DistanceTo(maybe_intersection.value());
    return {maybe_intersection.value(), distance};
  }

  return {
      {0, 0, 0, geometric_primitives::MACS},
      NAN
  };
}

auto LinearTrajectory::AttachToPoint(Point3d point_on_trajectory) -> void {
  attachment_point_macs_ = point_on_trajectory;
}

auto LinearTrajectory::Set(const common::Vector3D& direction_of_motion) -> void {
  direction_of_motion_ = direction_of_motion;
}

}  // namespace weld_motion_prediction
