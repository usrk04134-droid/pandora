#include "weld_motion_prediction/src/lpcs_to_macs_transformer.h"

#include <Eigen/Core>

#include "common/geometric_primitives/src/point3d.h"
#include "common/types/vector_3d_helpers.h"

using Eigen::Matrix3d;
using Eigen::Vector3d;
using geometric_primitives::LPCS;
using geometric_primitives::MACS;
using geometric_primitives::Point3d;

namespace weld_motion_prediction {

auto LpcsToMacsTransformer::SetTransform(std::array<double, 3>& scanner_angles,
                                         const common::Vector3D& tcs_to_lpcs_translation) -> void {
  tcs_to_lpcs_translation_ = tcs_to_lpcs_translation;
  scanner_angles_          = scanner_angles;
}

auto LpcsToMacsTransformer::Reset() -> void { tcs_to_lpcs_translation_ = {}; }

auto LpcsToMacsTransformer::UpdateMacsToTcsTranslation(const common::Point& slide_position) -> void {
  macs_to_tcs_translation_ = {.c1 = slide_position.horizontal, .c2 = 0.0, .c3 = slide_position.vertical};
}

auto LpcsToMacsTransformer::LpcsToMacs(const Point3d& point_lpcs, bool use_translation) const -> Point3d {
  // Orientation matrices
  Matrix3d R_1to4 = ComputeLpcsOrientation(scanner_angles_);

  // Translation vectors
  Vector3d t_3to4 = CommonVector2EigenVector(tcs_to_lpcs_translation_);
  Vector3d t_1to3 = common::CommonVector2EigenVector(macs_to_tcs_translation_);
  Vector3d t_1to4 = t_1to3 + t_3to4;

  // Transform
  Vector3d vec_lpcs          = point_lpcs.ToVec();
  Vector3d transformed_point = use_translation ? (R_1to4 * vec_lpcs + t_1to4).eval() : (R_1to4 * vec_lpcs).eval();

  return {transformed_point(0), transformed_point(1), transformed_point(2), MACS};
}

auto LpcsToMacsTransformer::MacsToLpcs(const Point3d& point_macs, bool use_translation) const -> Point3d {
  // Orientation matrices
  Matrix3d R_1to4 = ComputeLpcsOrientation(scanner_angles_);

  // Translation vectors
  Vector3d t_3to4 = CommonVector2EigenVector(tcs_to_lpcs_translation_);
  Vector3d t_1to3 = CommonVector2EigenVector(macs_to_tcs_translation_);
  Vector3d t_1to4 = t_1to3 + t_3to4;

  // Transform
  Vector3d vec_macs = point_macs.ToVec();
  Vector3d transformed_point;  //= R_1to4.transpose() * (vec_macs - t_1to4);

  transformed_point =
      use_translation ? (R_1to4.transpose() * (vec_macs - t_1to4)).eval() : (R_1to4.transpose() * vec_macs).eval();

  return {transformed_point(0), transformed_point(1), transformed_point(2), LPCS};
}

auto LpcsToMacsTransformer::ComputeLpcsOrientation(const std::array<double, 3>& scanner_angles) const
    -> Eigen::Matrix3d {
  Vector3d rot_axis(0.0, 0.0, 1.0);
  const Matrix3d rot_z  = CreateRotationMatrix(std::numbers::pi, rot_axis);
  rot_axis              = {1.0, 0.0, 0.0};
  const Matrix3d rot_x  = CreateRotationMatrix((3 * std::numbers::pi / 2) - scanner_angles.at(0), rot_axis);
  rot_axis              = {0.0, 1.0, 0.0};
  const Matrix3d rot_ey = CreateRotationMatrix(scanner_angles.at(1), rot_axis);
  rot_axis              = {0.0, 0.0, 1.0};
  const Matrix3d rot_ez = CreateRotationMatrix(scanner_angles.at(2), rot_axis);

  return rot_ez * (rot_x * rot_z) * rot_ey;
}

auto LpcsToMacsTransformer::CreateRotationMatrix(double angle, Eigen::Vector3d& rot_axis) -> Eigen::Matrix3d {
  rot_axis.normalize();
  Eigen::Matrix3d transform;
  transform = Eigen::Matrix3d::Zero();

  double factor = 0.0;
  if (!std::isnan(angle)) {
    factor = 1.0 - std::cos(angle);

    // This can be initilized much easier in Eigen. Doing this way to ensure that definitions are exactly the same as
    // in Scilab simulator. This definition of the transformation is equivalent to T = Trans4D * Rotation4D.
    transform(0, 0) = factor * std::pow(rot_axis(0), 2) + std::cos(angle);
    transform(0, 1) = factor * rot_axis(0) * rot_axis(1) - rot_axis(2) * std::sin(angle);
    transform(0, 2) = factor * rot_axis(0) * rot_axis(2) + rot_axis(1) * std::sin(angle);
    transform(1, 0) = factor * rot_axis(0) * rot_axis(1) + rot_axis(2) * std::sin(angle);
    transform(1, 1) = factor * std::pow(rot_axis(1), 2) + std::cos(angle);
    transform(1, 2) = factor * rot_axis(1) * rot_axis(2) - rot_axis(0) * std::sin(angle);
    transform(2, 0) = factor * rot_axis(2) * rot_axis(0) - rot_axis(1) * std::sin(angle);
    transform(2, 1) = factor * rot_axis(2) * rot_axis(1) + rot_axis(0) * std::sin(angle);
    transform(2, 2) = factor * std::pow(rot_axis(2), 2) + std::cos(angle);
  } else {
    transform = Eigen::Matrix3d::Identity();
  }

  return transform;
}

}  // namespace weld_motion_prediction
