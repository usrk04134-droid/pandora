#pragma once

#include "common/geometric_primitives/src/plane3d.h"
#include "common/geometric_primitives/src/point3d.h"
namespace weld_motion_prediction {

using geometric_primitives::Plane3d;
using geometric_primitives::Point3d;

class Trajectory {
 public:
  virtual ~Trajectory()                                                            = default;
  virtual auto Intersect(const Plane3d& plane) const -> std::pair<Point3d, double> = 0;
  virtual auto AttachToPoint(Point3d point_on_trajectory) -> void                  = 0;
};

}  // namespace weld_motion_prediction
