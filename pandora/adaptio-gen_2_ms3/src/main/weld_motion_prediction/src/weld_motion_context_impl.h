#pragma once

#include "common/groove/point.h"
#include "lpcs/lpcs_point.h"
#include "weld_motion_prediction/trajectory.h"
#include "weld_motion_prediction/transformer.h"
#include "weld_motion_prediction/weld_motion_context.h"

namespace weld_motion_prediction {

class WeldMotionContextImpl : public WeldMotionContext {
 public:
  explicit WeldMotionContextImpl(Trajectory* trajectory, Transformer* transformer);
  auto IntersectTorchPlane(const lpcs::Point& point) const -> common::Point override;
  auto IntersectLaserPlane(const common::Point& point) const -> lpcs::Point override;
  auto DistanceFromTorchToScanner(const lpcs::Point& lpcs_point) const -> std::optional<double> override;
  void SetActiveTrajectory(Trajectory* trajectory) override;

 private:
  Transformer* transformer_;
  Trajectory* trajectory_;

  auto GetTorchPlaneIntersectionAndDistance(const lpcs::Point& point) const -> std::pair<Point3d, double>;
  auto GetLaserPlaneIntersectionAndDistance(const common::Point& point) const -> std::pair<Point3d, double>;
};

}  // namespace weld_motion_prediction
