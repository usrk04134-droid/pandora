#pragma once

#include <doctest/doctest.h>

#include "common/messages/kinematics.h"
#include "helpers.h"

inline auto CheckAndDispatchGetWeldAxis(TestFixture& fixture, double position, double distance, double velocity,
                                        double path_length) {
  auto const req = fixture.Kinematics()->Receive<common::msg::kinematics::GetWeldAxisData>();
  CHECK(req);

  fixture.Kinematics()->Dispatch(common::msg::kinematics::GetWeldAxisDataRsp{
      .client_id              = req->client_id,
      .position               = position,
      .velocity               = velocity,
      .path_length            = path_length,
      .linear_object_distance = distance,
  });
}

inline auto DispatchKinematicsStateChange(TestFixture& fixture,
                                          common::msg::kinematics::StateChange::State weld_axis_state) {
  fixture.Kinematics()->Dispatch(common::msg::kinematics::StateChange{
      .weld_axis_state = weld_axis_state,
  });
}

inline auto DispatchKinematicsEdgeStateChange(TestFixture& fixture,
                                              common::msg::kinematics::EdgeStateChange::State edge_state) {
  fixture.Kinematics()->Dispatch(common::msg::kinematics::EdgeStateChange{
      .edge_state = edge_state,
  });
}

inline auto CheckAndDispatchEdgePosition(TestFixture& fixture, double position) {
  auto const req = fixture.Kinematics()->Receive<common::msg::kinematics::GetEdgePosition>();
  CHECK(req);

  fixture.Kinematics()->Dispatch(common::msg::kinematics::GetEdgePositionRsp{
      .client_id = req->client_id,
      .position  = position,
  });
}

inline auto DispatchKinematicsTorchAtEntry(TestFixture& fixture,
                                           common::msg::kinematics::TorchAtEntryPosition::State torch_at_entry_state) {
  fixture.Kinematics()->Dispatch(common::msg::kinematics::TorchAtEntryPosition{
      .torch_at_entry_state = torch_at_entry_state,
  });
}
