
#include "weld_motion_prediction/src/weld_motion_context_impl.h"

#include <Eigen/Core>

#include "common/geometric_primitives/src/circle3d.h"
#include "common/geometric_primitives/src/coordinate-systems.h"
#include "common/geometric_primitives/src/plane3d.h"
#include "common/geometric_primitives/src/point3d.h"
#include "common/groove/point.h"
#include "lpcs/lpcs_point.h"
#include "weld_motion_prediction/trajectory.h"
#include "weld_motion_prediction/transformer.h"

namespace weld_motion_prediction {

using Eigen::Vector3d;
using geometric_primitives::Circle3d;
using geometric_primitives::LPCS;
using geometric_primitives::MACS;
using geometric_primitives::Plane3d;
using geometric_primitives::Point3d;

// Plane definitions
const Plane3d laser_plane_lpcs{
    {0, 0, 1},
    {0, 0, 0, LPCS}
};
const Plane3d torch_plane_macs{
    {0, 1, 0},
    {0, 0, 0, MACS}
};

WeldMotionContextImpl::WeldMotionContextImpl(Trajectory* trajectory, Transformer* transformer)
    : transformer_(transformer), trajectory_(trajectory) {}

auto WeldMotionContextImpl::IntersectTorchPlane(const lpcs::Point& point) const -> common::Point {
  auto point_and_distance = GetTorchPlaneIntersectionAndDistance(point);
  Point3d mcs_point       = point_and_distance.first;

  return {.horizontal = mcs_point.GetX(), .vertical = mcs_point.GetZ()};
}

auto WeldMotionContextImpl::IntersectLaserPlane(const common::Point& point) const -> lpcs::Point {
  auto point_and_distance = GetLaserPlaneIntersectionAndDistance(point);
  return {.x = point_and_distance.first.GetX(), .y = point_and_distance.first.GetY()};
}

auto WeldMotionContextImpl::DistanceFromTorchToScanner(const lpcs::Point& lpcs_point) const -> std::optional<double> {
  auto point_and_distance = GetTorchPlaneIntersectionAndDistance(lpcs_point);
  return point_and_distance.second;
}

auto WeldMotionContextImpl::GetTorchPlaneIntersectionAndDistance(const lpcs::Point& point) const
    -> std::pair<Point3d, double> {
  Point3d point_to_project_lpcs{point.x, point.y, 0.0, LPCS};
  Point3d point_to_project_macs = transformer_->LpcsToMacs(point_to_project_lpcs, true);

  trajectory_->AttachToPoint(point_to_project_macs);
  return trajectory_->Intersect(torch_plane_macs);
}

auto WeldMotionContextImpl::GetLaserPlaneIntersectionAndDistance(const common::Point& point) const
    -> std::pair<Point3d, double> {
  // TODO: Make these static constants and add transformer method to transform planes as well
  Point3d laser_plane_point_macs  = transformer_->LpcsToMacs(laser_plane_lpcs.GetPointInPlane(), true);
  Point3d laser_plane_normal_macs = transformer_->LpcsToMacs({0.0, 0.0, 1.0, LPCS}, false);
  Plane3d laser_plane_macs{laser_plane_normal_macs.ToVec(), laser_plane_point_macs};

  Point3d point_to_project_macs{point.horizontal, 0.0, point.vertical, MACS};
  trajectory_->AttachToPoint(point_to_project_macs);
  auto point_and_distance = trajectory_->Intersect(laser_plane_macs);
  Point3d mcs_point       = point_and_distance.first;

  Point3d projected_point_lpcs = transformer_->MacsToLpcs(mcs_point, true);
  return {projected_point_lpcs, point_and_distance.second};
}

void WeldMotionContextImpl::SetActiveTrajectory(Trajectory* trajectory) { trajectory_ = trajectory; }

}  // namespace weld_motion_prediction
