#include "kinematics_server_impl.h"

#include <chrono>
#include <cstdint>

#include "common/clock_functions.h"
#include "common/logging/application_log.h"
#include "common/messages/kinematics.h"
#include "common/zevs/zevs_socket.h"
#include "controller/controller_data.h"
#include "controller/kinematics_server.h"
#include "controller/slide_position_buffer.h"
#include "controller/weld_axis_buffer.h"

using controller::KinematicsServerImpl;
using std::chrono::milliseconds;

namespace controller {

enum class AxisId : uint32_t {
  INVALID,
  SLIDE_CROSS_HORIZONTAL,
  SLIDE_CROSS_VERTICAL,
  WELD_AXIS,
  SIZE,
};
}  // namespace controller

KinematicsServerImpl::KinematicsServerImpl(zevs::Socket* socket, KinematicsServerObserver* observer,
                                           SlidePositionBuffer* horizontal_position_buffer,
                                           SlidePositionBuffer* vertical_position_buffer,
                                           WeldAxisBuffer* weld_axis_buffer,
                                           clock_functions::SystemClockNowFunc system_clock_now_func,
                                           OnTargetPathPositionUpdate on_target_path_position_update)
    : socket_(socket),
      observer_(observer),
      horizontal_position_buffer_(horizontal_position_buffer),
      vertical_position_buffer_(vertical_position_buffer),
      weld_axis_buffer_(weld_axis_buffer),
      system_clock_now_func_(system_clock_now_func),
      on_target_path_position_update_(on_target_path_position_update) {
  socket_->Serve(&KinematicsServerImpl::OnSetSlidesPosition, this);
  socket_->Serve(&KinematicsServerImpl::OnGetSlidesPosition, this);
  socket_->Serve(&KinematicsServerImpl::OnGetSlidesStatus, this);
  socket_->Serve(&KinematicsServerImpl::OnGetWeldAxisData, this);
  socket_->Serve(&KinematicsServerImpl::OnSetWeldAxisData, this);
  socket_->Serve(&KinematicsServerImpl::OnRelease, this);
  socket_->Serve(&KinematicsServerImpl::OnSubscribeStateChanges, this);
  socket_->Serve(&KinematicsServerImpl::OnUnSubscribeStateChanges, this);
  socket_->Serve(&KinematicsServerImpl::OnGetEdgePosition, this);
  socket_->Serve(&KinematicsServerImpl::OnSetTargetPathPosition, this);
}

void KinematicsServerImpl::OnWeldAxisInput(WeldAxis_PlcToAdaptio data) {
  uint64_t time_since_epoch = system_clock_now_func_().time_since_epoch().count();

  weld_axis_buffer_->StorePosition(data.get_position(), data.get_velocity(), time_since_epoch);

  weld_object_radius_     = static_cast<double>(data.get_radius());
  linear_object_distance_ = static_cast<double>(data.get_linear_object_distance());

  auto const weld_axis_homed = data.get_status_reference_valid() ? TriState::TRUE : TriState::FALSE;
  if (weld_axis_homed_ == TriState::UNKNOWN || weld_axis_homed != weld_axis_homed_) {
    LOG_INFO("WeldAxis PLC data: status_reference_valid={} (raw status bits: in_position={}, state={})",
             data.get_status_reference_valid(), data.get_status_in_position(), data.get_state());
    weld_axis_homed_ = weld_axis_homed;

    if (send_state_changes_) {
      socket_->Send(common::msg::kinematics::StateChange{
          .weld_axis_state = weld_axis_homed_ == TriState::TRUE ? common::msg::kinematics::StateChange::State::HOMED
                                                                : common::msg::kinematics::StateChange::State::INIT,
      });
    }
  }
}

void KinematicsServerImpl::OnWeldHeadManipulatorInput(WeldHeadManipulator_PlcToAdaptio data) {
  uint64_t time_since_epoch = system_clock_now_func_().time_since_epoch().count();

  horizontal_position_buffer_->StorePosition(data.get_x_position(), time_since_epoch);
  vertical_position_buffer_->StorePosition(data.get_y_position(), time_since_epoch);

  bool combined_in_position = data.get_status_in_position();
  horizontal_in_position_   = combined_in_position;
  vertical_in_position_     = combined_in_position;
}

void KinematicsServerImpl::OnTorchAtEntryPosition(bool status) {
  const auto new_state = status ? TriState::TRUE : TriState::FALSE;

  const bool is_transition_to_true = new_state == TriState::TRUE && torch_at_entry_position_ != TriState::TRUE;

  if (send_state_changes_ && is_transition_to_true) {
    socket_->Send(common::msg::kinematics::TorchAtEntryPosition{});
  }

  torch_at_entry_position_ = new_state;
}

void KinematicsServerImpl::OnSetSlidesPosition(common::msg::kinematics::SetSlidesPosition data) {
  LOG_TRACE("SetSlidesPosition - Horizontal:{:.2f}, Vertical:{:.2f}", data.horizontal, data.vertical);

  WeldHeadManipulator_AdaptioToPlc weld_head_manipulator{};

  weld_head_manipulator.set_commands_enable_motion(true);
  weld_head_manipulator.set_commands_interpolate(false);

  weld_head_manipulator.set_x_position(static_cast<float>(data.horizontal));
  weld_head_manipulator.set_y_position(static_cast<float>(data.vertical));

  weld_head_manipulator.set_x_speed(static_cast<float>(data.horizontal_lin_velocity));
  weld_head_manipulator.set_y_speed(static_cast<float>(data.vertical_velocity));

  weld_head_manipulator.set_interpolated_speed(0.0F);

  observer_->OnWeldHeadManipulatorOutput(weld_head_manipulator);
}

void KinematicsServerImpl::OnGetSlidesPosition(common::msg::kinematics::GetSlidesPosition data) {
  uint64_t const time_stamp =
      data.time_stamp != 0 ? data.time_stamp : system_clock_now_func_().time_since_epoch().count();
  auto horizontal_position = horizontal_position_buffer_->GetPosition(time_stamp);
  auto vertical_position   = vertical_position_buffer_->GetPosition(time_stamp);

  socket_->Send(common::msg::kinematics::GetSlidesPositionRsp{.client_id  = data.client_id,
                                                              .time_stamp = data.time_stamp,
                                                              .horizontal = horizontal_position,
                                                              .vertical   = vertical_position});
}

void KinematicsServerImpl::OnGetSlidesStatus(common::msg::kinematics::GetSlidesStatus data) {
  socket_->Send(common::msg::kinematics::GetSlidesStatusRsp{.client_id              = data.client_id,
                                                            .horizontal_in_position = horizontal_in_position_,
                                                            .vertical_in_position   = vertical_in_position_});
}

void KinematicsServerImpl::OnRelease(common::msg::kinematics::Release /*data*/) {
  LOG_INFO("Release");
  observer_->Release();
}

void KinematicsServerImpl::OnGetWeldAxisData(common::msg::kinematics::GetWeldAxisData data) {
  uint64_t const time_stamp =
      data.time_stamp != 0 ? data.time_stamp : system_clock_now_func_().time_since_epoch().count();
  auto axis_data = weld_axis_buffer_->GetPosition(time_stamp);

  common::msg::kinematics::GetWeldAxisDataRsp const rsp{.client_id   = data.client_id,
                                                        .time_stamp  = data.time_stamp,
                                                        .position    = axis_data.position,
                                                        .velocity    = axis_data.velocity,
                                                        .path_length = 2.0 * std::numbers::pi * weld_object_radius_,
                                                        .linear_object_distance = linear_object_distance_};
  socket_->Send(rsp);
}

void KinematicsServerImpl::OnSetWeldAxisData(common::msg::kinematics::SetWeldAxisData data) {
  LOG_TRACE("SetWeldAxisData - velocity:{:.2f}", data.velocity);
  WeldAxis_AdaptioToPlc weld_axis_output{};

  weld_axis_output.set_commands_enable_motion(true);
  weld_axis_output.set_commands_reset(false);
  weld_axis_output.set_commands_invalidate_reference(false);
  weld_axis_output.set_commands_reset_linear_object_distance(false);

  weld_axis_output.set_movement_type(MOVEMENT_TYPE_SPEED);
  weld_axis_output.set_movement_mode(MOVEMENT_MODE_POSITIVE);

  weld_axis_output.set_radius(RADIUS_TO_PLC);

  weld_axis_output.set_velocity(static_cast<float>(data.velocity));

  observer_->OnWeldAxisOutput(weld_axis_output);
}

void KinematicsServerImpl::OnSubscribeStateChanges(common::msg::kinematics::SubscribeStateChanges /*data*/) {
  send_state_changes_ = true;

  if (send_state_changes_) {
    if (weld_axis_homed_ != TriState::UNKNOWN) {
      /* send current states to new subscribers */
      socket_->Send(common::msg::kinematics::StateChange{
          .weld_axis_state = weld_axis_homed_ == TriState::TRUE ? common::msg::kinematics::StateChange::State::HOMED
                                                                : common::msg::kinematics::StateChange::State::INIT,
      });
    }

    socket_->Send(common::msg::kinematics::EdgeStateChange{
        .edge_state = EDGE_SENSOR_AVAILABLE ? common::msg::kinematics::EdgeStateChange::State::AVAILABLE
                                            : common::msg::kinematics::EdgeStateChange::State::NOT_AVAILABLE});
  }
}

void KinematicsServerImpl::OnUnSubscribeStateChanges(common::msg::kinematics::UnSubscribeStateChanges /*data*/) {
  send_state_changes_ = false;
}

void KinematicsServerImpl::OnGetEdgePosition(common::msg::kinematics::GetEdgePosition data) {
  socket_->Send(common::msg::kinematics::GetEdgePositionRsp{.client_id = data.client_id, .position = EDGE_POSITION});
}

void KinematicsServerImpl::OnSetTargetPathPosition(common::msg::kinematics::SetTargetPathPosition data) {
  on_target_path_position_update_(data.position);
}
