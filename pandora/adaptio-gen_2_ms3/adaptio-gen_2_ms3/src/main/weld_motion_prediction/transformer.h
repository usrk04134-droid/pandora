#pragma once

#include "common/geometric_primitives/src/point3d.h"

namespace weld_motion_prediction {

using geometric_primitives::Point3d;

class Transformer {
 public:
  virtual ~Transformer()                                                                    = default;
  virtual auto LpcsToMacs(const Point3d& point_lpcs, bool use_translation) const -> Point3d = 0;
  virtual auto MacsToLpcs(const Point3d& point_lpcs, bool use_translation) const -> Point3d = 0;
};

}  // namespace weld_motion_prediction
