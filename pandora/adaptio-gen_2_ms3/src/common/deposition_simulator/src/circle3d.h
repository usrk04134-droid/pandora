#pragma once

#include <Eigen/Core>

#include "../point3d.h"
#include "line3d.h"
#include "plane3d.h"

namespace deposition_simulator {

class Circle3d {
 private:
  Plane3d circle_plane_;
  Point3d center_;
  double radius_;
  auto CreateCircleBasis(Line3d &line_in_plane) const -> Eigen::Matrix3d;

 public:
  Circle3d(const Eigen::Vector3d &plane_normal, double radius, Point3d &center);
  auto Intersect(const Plane3d &plane) const -> std::vector<Point3d>;
  auto SetRadius(double radius) -> void;
  auto SetCenter(double x, double y, double z) -> void;
};

}  // Namespace deposition_simulator
