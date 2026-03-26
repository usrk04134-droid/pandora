
#pragma once

#include "common/types/vector_3d.h"
#include "weld_motion_prediction/trajectory.h"
namespace weld_motion_prediction {

class ConfigurableCircleTrajectory : public Trajectory {
 public:
  virtual ~ConfigurableCircleTrajectory() = default;
  virtual auto Set(const common::Vector3D& rot_center, const common::Vector3D& weld_object_rotation_axis) -> void = 0;
};

}  // namespace weld_motion_prediction
