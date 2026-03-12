
#pragma once

#include <common/types/vector_3d.h>

#include <array>

namespace slice_translator {

/*This interface is to be used to set model parameters as precondition for
  joint tracking or automatic welding.
  The interface should only be used by the "calibration::CalibrationManager" class*/

class LinearModelConfig {
 public:
  virtual ~LinearModelConfig()                                                                = default;
  virtual auto ActivateWithConfig(const common::Vector3D& movement_direction, std::array<double, 3> scanner_angles,
                                  const common::Vector3D& torch_to_laser_translation) -> void = 0;
  virtual void Reset()                                                                        = 0;
};

}  // namespace slice_translator
