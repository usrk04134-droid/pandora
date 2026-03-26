#pragma once

#include <array>
#include <Eigen/Core>

#include "common/groove/point.h"
#include "common/types/vector_3d.h"
namespace weld_motion_prediction {

class ConfigurableTransform {
 public:
  virtual ~ConfigurableTransform() = default;
  virtual auto SetTransform(std::array<double, 3>& scanner_angles, const common::Vector3D& tcs_to_lpcs_translation)
      -> void                                                                                               = 0;
  virtual auto UpdateMacsToTcsTranslation(const common::Point& slide_position) -> void                      = 0;
  virtual auto ComputeLpcsOrientation(const std::array<double, 3>& scanner_angles) const -> Eigen::Matrix3d = 0;
  virtual auto Reset() -> void                                                                              = 0;
};

}  // namespace weld_motion_prediction
