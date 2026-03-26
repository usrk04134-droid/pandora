#include "groove_estimator_impl.h"

#include <optional>

#include "groove_estimator/src/weld_axis.h"
#include "lpcs/lpcs_slice.h"

namespace groove_estimator {

GrooveEstimatorImpl::GrooveEstimatorImpl(WeldAxis* weld_axis) : weld_axis_(weld_axis) {}

void GrooveEstimatorImpl::Receive(const macs::Slice& machine_data, const lpcs::Slice& scanner_data,
                                  const common::Point& slides_actual, const double distance_from_torch_to_scanner) {
  // Cache data
  current_groove_  = scanner_data.confidence == lpcs::SliceConfidence::HIGH ? machine_data.groove : std::nullopt;
  current_profile_ = machine_data.profile;
  current_slider_position_ = slides_actual;

  weld_axis_->GetData(
      machine_data.time_stamp,
      [this](WeldAxisType type, WeldAxisState state, std::uint64_t time_stamp, std::optional<double> position,
             double velocity, double length, double linear_object_distance) -> void {
        OnWeldAxisResponse(type, state, time_stamp, position, velocity, length, linear_object_distance);
      });
}

void GrooveEstimatorImpl::OnWeldAxisResponse(WeldAxisType type, WeldAxisState state, std::uint64_t time_stamp,
                                             std::optional<double> position, double velocity, double length,
                                             double linear_object_distance) {
  if (weld_axis_type_ != type) {
    // Reset data
    weld_axis_type_ = type;
  }

  if (weld_axis_state_ != state) {
    // Reset data
    weld_axis_state_ = state;
  }

  // Default to forwarding the last known groove unless we can improve it below.
  common::Groove groove_to_forward = last_groove_;

  // Process only when we have a normalized position in [0.0, 1.0].
  if (position && *position >= 0.0 && *position <= 1.0) {
    const double pos = *position;

    if (current_groove_) {
      // We have an active/current groove: store the latest sample and forward it.
      StoreData(pos, *current_groove_, current_profile_, current_slider_position_);
      groove_to_forward = *current_groove_;
    } else if (auto data = GetData(pos)) {
      // No current groove available: try to recover from stored data at this position.
      auto& [previous_profile, previous_groove, previous_slider] = *data;

      // TODO: compute actual drift from tracker when available.
      auto drift = 0.0;
      // e.g. IDriftTracker::GetDriftSinceLastTimeAtThisPosition(
      //          current_profile_, "previous_slider", previous_profile, previous_groove);

      // Estimate a groove from prior knowledge + current profile.
      groove_to_forward = EstimateGroove(drift, current_profile_, previous_groove);

      // Store the newly estimated groove for this position.
      StoreData(pos, groove_to_forward, current_profile_, current_slider_position_);
    }
  }

  // Forward(groove_to_forward, type, state, time_stamp, position, current_slider_position_, velocity, length,
  // linear_object_distance);

  // Remember what we forwarded for continuity on the next call.
  last_groove_ = groove_to_forward;
}
}  // namespace groove_estimator
