#pragma once

#include <optional>

#include "common/geometric_primitives/src/point3d.h"
#include "common/groove/point.h"
#include "lpcs/lpcs_point.h"
#include "weld_motion_prediction/trajectory.h"
namespace weld_motion_prediction {

using geometric_primitives::Point3d;

class WeldMotionContext {
 public:
  virtual ~WeldMotionContext()                                                                          = default;
  virtual auto IntersectTorchPlane(const lpcs::Point& point) const -> common::Point                     = 0;
  virtual auto IntersectLaserPlane(const common::Point& point) const -> lpcs::Point                     = 0;
  virtual auto DistanceFromTorchToScanner(const lpcs::Point& lpcs_point) const -> std::optional<double> = 0;
  virtual void SetActiveTrajectory(Trajectory* trajectory)                                              = 0;
};

}  // namespace weld_motion_prediction
