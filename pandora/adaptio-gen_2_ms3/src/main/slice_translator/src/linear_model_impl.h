
#pragma once

#include <Eigen/Core>

#include "common/geometric_primitives/src/circle3d.h"
#include "common/geometric_primitives/src/plane3d.h"
#include "common/geometric_primitives/src/point3d.h"
#include "common/groove/point.h"
#include "common/types/vector_3d.h"
#include "lpcs/lpcs_point.h"
#include "slice_translator/linear_model_config.h"
#include "slice_translator/model_activator.h"
#include "slice_translator/translation-model.h"
#include "weld_motion_prediction/configurable_linear_trajectory.h"
#include "weld_motion_prediction/configurable_transform.h"
#include "weld_motion_prediction/weld_motion_context.h"

namespace slice_translator {

using geometric_primitives::Circle3d;
using geometric_primitives::Plane3d;
using geometric_primitives::Point3d;
using weld_motion_prediction::ConfigurableLinearTrajectory;
using weld_motion_prediction::ConfigurableTransform;
using weld_motion_prediction::WeldMotionContext;

class LinearModelImpl : public TranslationModel, public LinearModelConfig {
 public:
  LinearModelImpl(WeldMotionContext* intersector, ConfigurableLinearTrajectory* trajectory,
                  ConfigurableTransform* transformer, ModelActivator* model_activator);

  /*SliceTranslatorServiceV2*/
  auto LPCSToMCS(const std::vector<lpcs::Point>& lpcs_points, const common::Point& slide_position) const
      -> std::optional<std::vector<common::Point>> override;
  auto MCSToLPCS(const std::vector<common::Point>& mcs_points, const common::Point& slide_position) const
      -> std::optional<std::vector<lpcs::Point>> override;
  auto DistanceFromTorchToScanner(const std::vector<lpcs::Point>& lpcs_points, const common::Point& axis_position) const
      -> std::optional<double> override;
  auto Available() const -> bool override;

  /*LinearModelConfig*/
  void ActivateWithConfig(const common::Vector3D& movement_direction, std::array<double, 3> scanner_angles,
                          const common::Vector3D& torch_to_laser_translation) override;
  void Reset() override;

 private:
  bool available_ = false;
  ConfigurableLinearTrajectory* trajectory_;
  ConfigurableTransform* transformer_;
  WeldMotionContext* intersector_;
  ModelActivator* activator_;

  void StageConfig(const common::Vector3D& movement_direction, std::array<double, 3> scanner_angles,
                   const common::Vector3D& torch_to_laser_translation);
};

}  // namespace slice_translator
