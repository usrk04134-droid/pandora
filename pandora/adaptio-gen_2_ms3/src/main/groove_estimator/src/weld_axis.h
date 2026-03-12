#pragma once

#include <cstdint>
#include <functional>
#include <optional>

namespace groove_estimator {

enum class WeldAxisType {
  UNDEF,
  CW,
  LW,
};

enum class WeldAxisState {
  UNDEF,
  NOT_INITIALIZED,
  INITIALIZED,  // HOMED in CW case
};

using OnGetWeldAxisData =
    std::function<void(WeldAxisType type, WeldAxisState state, std::uint64_t time_stamp, std::optional<double> position,
                       double velocity, double length, double linear_object_distance)>;

class WeldAxis {
 public:
  virtual ~WeldAxis() = default;

  virtual void GetData(std::uint64_t time_stamp, OnGetWeldAxisData on_response) = 0;
};

}  // namespace groove_estimator
