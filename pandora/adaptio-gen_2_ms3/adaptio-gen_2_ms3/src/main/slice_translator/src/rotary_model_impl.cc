
#include "slice_translator/src/rotary_model_impl.h"

#include <array>
#include <cmath>
#include <Eigen/Core>
#include <optional>
#include <vector>

#include "common/groove/point.h"
#include "common/logging/application_log.h"
#include "common/types/vector_3d.h"
#include "lpcs/lpcs_point.h"
#include "weld_motion_prediction/configurable_circle_trajectory.h"
#include "weld_motion_prediction/configurable_transform.h"
#include "weld_motion_prediction/weld_motion_context.h"

namespace slice_translator {

using Eigen::Matrix3d;
using Eigen::Vector3d;
using slice_translator::RotaryModelImpl;
using weld_motion_prediction::ConfigurableCircleTrajectory;
using weld_motion_prediction::ConfigurableTransform;
using weld_motion_prediction::WeldMotionContext;

RotaryModelImpl::RotaryModelImpl(WeldMotionContext* intersector, ConfigurableCircleTrajectory* trajectory,
                                 ConfigurableTransform* transform_config, ModelActivator* model_activator)
    : trajectory_(trajectory), transformer_(transform_config), intersector_(intersector), activator_(model_activator) {}

auto RotaryModelImpl::LPCSToMCS(const std::vector<lpcs::Point>& lpcs_points, const common::Point& slide_position) const
    -> std::optional<std::vector<common::Point>> {
  std::vector<common::Point> mcs_points;
  common::Point mcs_point;

  transformer_->UpdateMacsToTcsTranslation(slide_position);

  for (const auto& lpcs_point : lpcs_points) {
    mcs_point = intersector_->IntersectTorchPlane(lpcs_point);
    mcs_points.push_back(mcs_point);
  }

  return mcs_points;
}

auto RotaryModelImpl::MCSToLPCS(const std::vector<common::Point>& mcs_points, const common::Point& slide_position) const
    -> std::optional<std::vector<lpcs::Point>> {
  std::vector<lpcs::Point> lpcs_points;
  lpcs::Point lpcs_point;
  transformer_->UpdateMacsToTcsTranslation(slide_position);

  for (const auto& mcs_point : mcs_points) {
    lpcs_point = intersector_->IntersectLaserPlane(mcs_point);
    lpcs_points.push_back(lpcs_point);
  }

  return lpcs_points;
}

auto RotaryModelImpl::DistanceFromTorchToScanner(const std::vector<lpcs::Point>& lpcs_points,
                                                 const common::Point& axis_position) const -> std::optional<double> {
  transformer_->UpdateMacsToTcsTranslation(axis_position);
  return intersector_->DistanceFromTorchToScanner(lpcs_points.at(0));
}

auto RotaryModelImpl::Available() const -> bool { return available_; }

auto RotaryModelImpl::ActivateWithConfig(const common::Vector3D& rot_center, std::array<double, 3> scanner_angles,
                                         const common::Vector3D& weld_object_rotation_axis,
                                         const common::Vector3D& torch_to_laser_translation) -> void {
  StageConfig(rot_center, scanner_angles, weld_object_rotation_axis, torch_to_laser_translation);
  activator_->SetActiveModel(this);
  available_ = true;
  LOG_INFO("Model parameters set");
}

auto RotaryModelImpl::StageConfig(const common::Vector3D& rot_center, std::array<double, 3> scanner_angles,
                                  const common::Vector3D& weld_object_rotation_axis,
                                  const common::Vector3D& torch_to_laser_translation) -> void {
  trajectory_->Set(rot_center, weld_object_rotation_axis);
  transformer_->SetTransform(scanner_angles, torch_to_laser_translation);
  intersector_->SetActiveTrajectory(trajectory_);
}

void RotaryModelImpl::Reset() {
  transformer_->Reset();
  available_ = false;
  LOG_INFO("Model parameters reset ");
}

auto RotaryModelImpl::ComputeLpcsOrientation(double scanner_mount_angle, double delta_rot_y, double delta_rot_z) const
    -> Eigen::Matrix3d {
  return transformer_->ComputeLpcsOrientation({scanner_mount_angle, delta_rot_y, delta_rot_z});
}

auto RotaryModelImpl::TransformAndProjectToTorchPlane(lpcs::Point point_lpcs, common::Point slide_position) const
    -> common::Point {
  transformer_->UpdateMacsToTcsTranslation(slide_position);
  return intersector_->IntersectTorchPlane(point_lpcs);
}

}  // Namespace slice_translator
