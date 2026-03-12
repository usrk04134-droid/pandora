#pragma once

#include <nlohmann/json_fwd.hpp>

#include "common/clock_functions.h"
#include "common/groove/point.h"
#include "common/logging/component_logger.h"
#include "coordination/activity_status.h"
#include "joint_geometry/joint_geometry_provider.h"
#include "kinematics/kinematics_client.h"
#include "lpcs/lpcs_slice.h"
#include "scanner_client/scanner_client.h"
#include "web_hmi/web_hmi.h"

namespace calibration {

struct DependencyContext {
  scanner_client::ScannerClient* scanner_client;
  coordination::ActivityStatus* activity_status;
  web_hmi::WebHmi* web_hmi;
  joint_geometry::JointGeometryProvider* joint_geometry_provider;
  kinematics::KinematicsClient* kinematics_client;
  clock_functions::SystemClockNowFunc system_clock_now_func;
  clock_functions::SteadyClockNowFunc steady_clock_now_func;
  common::logging::ComponentLogger* calibration_logger;
};

class CalibrationHandler {
 public:
  virtual ~CalibrationHandler() = default;

  virtual auto CanHandle(coordination::ActivityStatusE status) const -> bool                    = 0;
  virtual auto IsBusy() const -> bool                                                           = 0;
  virtual void OnScannerDataUpdate(const lpcs::Slice& data, const common::Point& axis_position) = 0;
  virtual void OnGeometryApplied(bool success)                                                  = 0;
  virtual void Cleanup()                                                                        = 0;
  virtual void SubscribeWebHmi()                                                                = 0;
  virtual void ApplyCalibration()                                                               = 0;
  virtual auto HasValidCalibration() const -> bool                                              = 0;
};

}  // namespace calibration
