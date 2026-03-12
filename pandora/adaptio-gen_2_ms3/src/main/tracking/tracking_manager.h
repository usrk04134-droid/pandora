#pragma once

#include <cstdint>
#include <optional>
#include <string>
#include <unordered_map>

#include "common/groove/groove.h"

namespace tracking {

enum class TrackingMode : uint32_t {
  TRACKING_LEFT_HEIGHT   = 0,
  TRACKING_RIGHT_HEIGHT  = 1,
  TRACKING_CENTER_HEIGHT = 2,
  TRACKING_HEIGHT        = 3,
};

inline auto TrackingModeToString(const TrackingMode& mode) {
  switch (mode) {
    case TrackingMode::TRACKING_LEFT_HEIGHT:
      return "left";
    case TrackingMode::TRACKING_RIGHT_HEIGHT:
      return "right";
    case TrackingMode::TRACKING_CENTER_HEIGHT:
      return "center";
    case TrackingMode::TRACKING_HEIGHT:
      return "height";
    default:
      break;
  }

  return "invalid";
}

inline auto StringToTrackingMode(const std::string& str) -> std::optional<TrackingMode> {
  static const std::unordered_map<std::string, TrackingMode> MAP = {
      {"left",   TrackingMode::TRACKING_LEFT_HEIGHT  },
      {"right",  TrackingMode::TRACKING_RIGHT_HEIGHT },
      {"center", TrackingMode::TRACKING_CENTER_HEIGHT},
      {"height", TrackingMode::TRACKING_HEIGHT       }
  };

  auto it = MAP.find(str);
  return it != MAP.end() ? std::make_optional(it->second) : std::nullopt;
}

enum class TrackingReference {
  BOTTOM,
  TOP,
};

inline auto TrackingReferenceToString(const TrackingReference& reference) {
  switch (reference) {
    case TrackingReference::BOTTOM:
      return "bottom";
    case TrackingReference::TOP:
      return "top";
  }

  return "invalid";
}

class TrackingManager {
 public:
  virtual ~TrackingManager() = default;

  struct Input {
    TrackingMode mode{TrackingMode::TRACKING_LEFT_HEIGHT};
    TrackingReference reference{TrackingReference::BOTTOM};
    double horizontal_offset{0.};
    double vertical_offset{0.};
    common::Groove groove;
    common::Point axis_position{.horizontal = 0., .vertical = 0.};
    bool smooth_vertical_motion{};
  };

  struct Output {
    double horizontal_pos{0.};
    double vertical_pos{0.};
  };
  virtual auto Update(const Input& data) -> std::optional<Output> = 0;

  virtual void Reset() = 0;
};

}  // namespace tracking
