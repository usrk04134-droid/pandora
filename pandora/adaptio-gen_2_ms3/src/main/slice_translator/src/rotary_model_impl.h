#pragma once

#include <Eigen/Core>

#include "common/geometric_primitives/src/circle3d.h"
#include "common/geometric_primitives/src/plane3d.h"
#include "common/geometric_primitives/src/point3d.h"
#include "common/groove/point.h"
#include "common/types/vector_3d.h"
#include "lpcs/lpcs_point.h"
#include "slice_translator/model_activator.h"
#include "slice_translator/optimizable_model.h"
#include "slice_translator/rotary_model_config.h"
#include "slice_translator/translation-model.h"
#include "weld_motion_prediction/configurable_circle_trajectory.h"
#include "weld_motion_prediction/configurable_transform.h"
#include "weld_motion_prediction/weld_motion_context.h"

namespace slice_translator {

using geometric_primitives::Circle3d;
using geometric_primitives::Plane3d;
using geometric_primitives::Point3d;
using weld_motion_prediction::ConfigurableCircleTrajectory;
using weld_motion_prediction::ConfigurableTransform;
using weld_motion_prediction::WeldMotionContext;

class RotaryModelImpl : public TranslationModel, public RotaryModelConfig, public OptimizableModel {
 public:
  RotaryModelImpl(WeldMotionContext* intersector, ConfigurableCircleTrajectory* trajectory,
                  ConfigurableTransform* transform_config, ModelActivator* model_activator);

  /*SliceTranslatorServiceV2*/
  auto LPCSToMCS(const std::vector<lpcs::Point>& lpcs_points, const common::Point& slide_position) const
      -> std::optional<std::vector<common::Point>> override;
  auto MCSToLPCS(const std::vector<common::Point>& mcs_points, const common::Point& slide_position) const
      -> std::optional<std::vector<lpcs::Point>> override;
  auto DistanceFromTorchToScanner(const std::vector<lpcs::Point>& lpcs_points, const common::Point& axis_position) const
      -> std::optional<double> override;
  auto Available() const -> bool override;

  /*RotaryModelConfig*/
  void ActivateWithConfig(const common::Vector3D& rot_center, std::array<double, 3> scanner_angles,
                          const common::Vector3D& weld_object_rotation_axis,
                          const common::Vector3D& torch_to_laser_translation) override;
  void Reset() override;

  /*OptimizableModel*/
  auto StageConfig(const common::Vector3D& rot_center, std::array<double, 3> scanner_angles,
                   const common::Vector3D& weld_object_rotation_axis,
                   const common::Vector3D& torch_to_laser_translation) -> void override;
  auto TransformAndProjectToTorchPlane(lpcs::Point point_lpcs, common::Point slide_position) const
      -> common::Point override;

  auto ComputeLpcsOrientation(double scanner_mount_angle, double delta_rot_y, double delta_rot_z) const
      -> Eigen::Matrix3d override;

 private:
  bool available_ = false;
  ConfigurableCircleTrajectory* trajectory_;
  ConfigurableTransform* transformer_;
  WeldMotionContext* intersector_;
  ModelActivator* activator_;
};

}  // namespace slice_translator
