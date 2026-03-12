#pragma once

#include "common/clock_functions.h"
#include "common/messages/kinematics.h"
#include "common/zevs/zevs_socket.h"
#include "controller/controller_data.h"
#include "kinematics_server.h"
#include "slide_position_buffer.h"
#include "weld_axis_buffer.h"

namespace controller {

using OnTargetPathPositionUpdate = std::function<void(double target_path_position)>;

class KinematicsServerImpl : public KinematicsServer {
 public:
  explicit KinematicsServerImpl(zevs::Socket* socket, KinematicsServerObserver* observer,
                                SlidePositionBuffer* horizontal_position_buffer,
                                SlidePositionBuffer* vertical_position_buffer, WeldAxisBuffer* weld_axis_buffer,
                                clock_functions::SystemClockNowFunc system_clock_now_func,
                                OnTargetPathPositionUpdate on_target_path_position_update);

  void OnWeldAxisInput(WeldAxis_PlcToAdaptio data) override;
  void OnWeldHeadManipulatorInput(WeldHeadManipulator_PlcToAdaptio data) override;
  void OnTorchAtEntryPosition(bool status) override;

 private:
  void OnGetSlidesPosition(common::msg::kinematics::GetSlidesPosition data);
  void OnSetSlidesPosition(common::msg::kinematics::SetSlidesPosition data);
  void OnGetSlidesStatus(common::msg::kinematics::GetSlidesStatus data);
  void OnRelease(common::msg::kinematics::Release data);
  void OnGetWeldAxisData(common::msg::kinematics::GetWeldAxisData data);
  void OnSetWeldAxisData(common::msg::kinematics::SetWeldAxisData data);
  void OnSubscribeStateChanges(common::msg::kinematics::SubscribeStateChanges data);
  void OnUnSubscribeStateChanges(common::msg::kinematics::UnSubscribeStateChanges data);
  void OnGetEdgePosition(common::msg::kinematics::GetEdgePosition data);
  void OnSetTargetPathPosition(common::msg::kinematics::SetTargetPathPosition data);

  // TriState enum type only because optional<bool> is very error prone
  enum class TriState {
    UNKNOWN,
    TRUE,
    FALSE,
  };

  zevs::Socket* socket_;
  KinematicsServerObserver* observer_ = nullptr;
  SlidePositionBuffer* horizontal_position_buffer_;
  SlidePositionBuffer* vertical_position_buffer_;
  WeldAxisBuffer* weld_axis_buffer_;
  bool horizontal_in_position_{false};
  bool vertical_in_position_{false};
  double weld_object_radius_{0.};
  double linear_object_distance_{};
  clock_functions::SystemClockNowFunc system_clock_now_func_;
  TriState weld_axis_homed_{TriState::UNKNOWN};
  bool send_state_changes_ = false;
  TriState torch_at_entry_position_{TriState::UNKNOWN};
  OnTargetPathPositionUpdate on_target_path_position_update_;

  static constexpr bool EDGE_SENSOR_AVAILABLE      = false;
  static constexpr double EDGE_POSITION            = 0.0;
  static constexpr float RADIUS_TO_PLC             = 0.0F;
  static constexpr uint32_t MOVEMENT_TYPE_SPEED    = 1;
  static constexpr uint32_t MOVEMENT_MODE_POSITIVE = 1;
  static constexpr uint32_t AXIS_TYPE_ROTATIONAL   = 0;
};

}  // namespace controller
