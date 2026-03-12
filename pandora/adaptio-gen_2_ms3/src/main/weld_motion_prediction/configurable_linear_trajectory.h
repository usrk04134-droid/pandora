
#pragma once

#include "common/types/vector_3d.h"
#include "weld_motion_prediction/trajectory.h"
namespace weld_motion_prediction {

class ConfigurableLinearTrajectory : public Trajectory {
 public:
  virtual ~ConfigurableLinearTrajectory()                              = default;
  virtual auto Set(const common::Vector3D& movement_direction) -> void = 0;
};

}  // namespace weld_motion_prediction
