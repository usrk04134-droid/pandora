#pragma once

#include <nlohmann/json.hpp>

#include "common/groove/point.h"
#include "macs/macs_slice.h"
#include "web_hmi/web_hmi.h"

namespace weld_control {

class WeldObservability {
 public:
  WeldObservability(const common::Point& slides_actual, const macs::Slice& cached_mcs, const double& vertical_offset,
                    web_hmi::WebHmi* web_hmi);

 private:
  void RegisterHandlers();

  void OnMcsProfileGet();
  void OnSlidesPositionGet();
  void OnVerticalOffsetGet();

 private:
  const common::Point& slides_actual_;
  const macs::Slice& cached_mcs_;
  const double& vertical_offset_;
  web_hmi::WebHmi* web_hmi_;
};

}  // namespace weld_control
