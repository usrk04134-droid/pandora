

#include "slice_translator/src/linear_model_impl.h"

#include "common/logging/application_log.h"
#include "slice_translator/model_activator.h"
#include "weld_motion_prediction/configurable_linear_trajectory.h"
#include "weld_motion_prediction/configurable_transform.h"
#include "weld_motion_prediction/weld_motion_context.h"

namespace slice_translator {

using Eigen::Matrix3d;
using Eigen::Vector3d;
using slice_translator::LinearModelImpl;
using weld_motion_prediction::ConfigurableTransform;
using weld_motion_prediction::WeldMotionContext;

LinearModelImpl::LinearModelImpl(WeldMotionContext* intersector, ConfigurableLinearTrajectory* trajectory,
                                 ConfigurableTransform* transformer, ModelActivator* model_activator)
    : trajectory_(trajectory), transformer_(transformer), intersector_(intersector), activator_(model_activator) {}

auto LinearModelImpl::LPCSToMCS(const std::vector<lpcs::Point>& lpcs_points, const common::Point& slide_position) const
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

auto LinearModelImpl::MCSToLPCS(const std::vector<common::Point>& mcs_points, const common::Point& slide_position) const
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

auto LinearModelImpl::DistanceFromTorchToScanner(const std::vector<lpcs::Point>& lpcs_points,
                                                 const common::Point& axis_position) const -> std::optional<double> {
  transformer_->UpdateMacsToTcsTranslation(axis_position);
  return intersector_->DistanceFromTorchToScanner(lpcs_points.at(0));
}

auto LinearModelImpl::Available() const -> bool { return available_; }

auto LinearModelImpl::ActivateWithConfig(const common::Vector3D& movement_direction,
                                         std::array<double, 3> scanner_angles,
                                         const common::Vector3D& torch_to_laser_translation) -> void {
  StageConfig(movement_direction, scanner_angles, torch_to_laser_translation);
  activator_->SetActiveModel(this);
  available_ = true;
  LOG_INFO("Model parameters set");
}

void LinearModelImpl::StageConfig(const common::Vector3D& movement_direction, std::array<double, 3> scanner_angles,
                                  const common::Vector3D& torch_to_laser_translation) {
  trajectory_->Set(movement_direction);
  transformer_->SetTransform(scanner_angles, torch_to_laser_translation);
  intersector_->SetActiveTrajectory(trajectory_);
}

void LinearModelImpl::Reset() {
  transformer_->Reset();
  available_ = false;
  LOG_INFO("Model parameters reset ");
}

}  // namespace slice_translator
