#include "circle_trajectory.h"

#include <Eigen/src/Core/Matrix.h>

#include <Eigen/Core>
#include <numbers>

#include "common/geometric_primitives/src/coordinate-systems.h"
#include "common/geometric_primitives/src/plane3d.h"
#include "common/types/vector_3d_helpers.h"

namespace weld_motion_prediction {

using Eigen::Vector3d;
using geometric_primitives::MACS;
using geometric_primitives::Point3d;

auto CircleTrajectory::Set(const common::Vector3D& rot_center, const common::Vector3D& weld_object_rotation_axis)
    -> void {
  rot_center_                = rot_center;
  weld_object_rotation_axis_ = weld_object_rotation_axis;
}
auto CircleTrajectory::Intersect(const Plane3d& plane_macs) const -> std::pair<Point3d, double> {
  // The projection circle (MACS)
  Circle3d projection_circle_macs = CreateProjectionCircle(attachment_point_macs_);

  auto intersection_points = projection_circle_macs.Intersect(plane_macs);

  if (intersection_points.empty()) {
    return {
        {0, 0, 0, MACS},
        NAN
    };
  }

  return FindPointWithShortestTrajectory(intersection_points, projection_circle_macs);
}

auto CircleTrajectory::AttachToPoint(Point3d point_on_trajectory) -> void {
  attachment_point_macs_ = point_on_trajectory;
}

auto CircleTrajectory::CreateProjectionCircle(const Point3d& point_to_project) const -> Circle3d {
  // Projection/rotation entities
  Vector3d calib_rot_center_1 = CommonVector2EigenVector(rot_center_);
  Vector3d n_circle_1         = CommonVector2EigenVector(weld_object_rotation_axis_);
  const double axis_norm      = n_circle_1.norm();
  if (!std::isnormal(axis_norm)) {
    // Fallback to X-axis if rotation axis is invalid to avoid NaNs downstream
    n_circle_1 = Vector3d(1.0, 0.0, 0.0);
  } else {
    n_circle_1.normalize();
  }
  Vector3d p_macs = point_to_project.ToVec();

  // Adjusted projection circle center
  Vector3d from_center_to_point = p_macs - calib_rot_center_1;
  double shift_along_rotax      = from_center_to_point.dot(n_circle_1);
  Vector3d p_circle_1           = calib_rot_center_1 + shift_along_rotax * n_circle_1;
  Point3d circle_center{p_circle_1(0), p_circle_1(1), p_circle_1(2), MACS};

  // Rotate/project to torch plane by computing intersection between ABW circle and torch plane
  double dist_to_center = (p_macs - p_circle_1).norm();  // Projection circle radius
  Circle3d projection_circle{n_circle_1, dist_to_center, circle_center};

  return projection_circle;
}

auto CircleTrajectory::FindPointWithShortestTrajectory(std::vector<Point3d>& points, Circle3d& projection_circle) const
    -> std::pair<Point3d, double> {
  int min_idx          = -1;
  double cos_angle     = 0.0;
  double max_cos_angle = -1.0;
  int count            = 0;

  Vector3d center_point = projection_circle.GetCenter().ToVec();
  Vector3d ref_vector   = attachment_point_macs_.ToVec() - center_point;
  Vector3d tmp_vector;

  for (const auto& p : points) {
    tmp_vector = p.ToVec() - center_point;
    cos_angle  = tmp_vector.normalized().eval().dot(ref_vector.normalized().eval());

    if (cos_angle > max_cos_angle) {
      min_idx       = count;
      max_cos_angle = cos_angle;
    }

    count++;
  }

  if (min_idx == -1) {
    return {{Point3d(0.0, 0.0, 0.0, MACS)}, NAN};
  }

  // Handle numerical issues around +/-1
  double min_angle = NAN;
  if (max_cos_angle > 1.0) {
    min_angle = 0.0;
  } else if (max_cos_angle < -1.0) {
    min_angle = std::numbers::pi;
  } else {
    min_angle = std::acos(max_cos_angle);
  }

  double min_trajectory_length = min_angle * ref_vector.norm();
  return {points.at(min_idx), min_trajectory_length};
}

}  // namespace weld_motion_prediction
