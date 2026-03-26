#pragma once

#include <optional>
#include <vector>

#include "common/groove/groove.h"
#include "common/groove/point.h"
#include "groove_estimator/src/weld_axis.h"
#include "slice_translator/slice_observer.h"

namespace groove_estimator {

class GrooveEstimatorImpl : public slice_translator::SliceObserver {
 public:
  explicit GrooveEstimatorImpl(WeldAxis* weld_axis);

  /* SliceObserver */
  void Receive(const macs::Slice& machine_data, const lpcs::Slice& scanner_data, const common::Point& slides_actual,
               double distance_from_torch_to_scanner) override;

 private:
  void OnWeldAxisResponse(WeldAxisType type, WeldAxisState state, std::uint64_t time_stamp,
                          std::optional<double> position, double velocity, double length,
                          double linear_object_distance);
  void StoreData(double position, const common::Groove& groove, const std::vector<common::Point>& profile,
                 common::Point slider_position) {};
  auto GetData(double position)
      -> std::optional<std::tuple<std::vector<common::Point>, common::Groove, common::Point>> {
    return std::nullopt;
  };

  auto EstimateGroove(double drift, std::vector<common::Point> profile, common::Groove groove) -> common::Groove;
  WeldAxis* weld_axis_;
  WeldAxisState weld_axis_state_{WeldAxisState::UNDEF};
  WeldAxisType weld_axis_type_{WeldAxisType::UNDEF};

  std::optional<common::Groove> current_groove_;
  common::Groove last_groove_;
  std::vector<common::Point> current_profile_;
  common::Point current_slider_position_;
};

}  // namespace groove_estimator
