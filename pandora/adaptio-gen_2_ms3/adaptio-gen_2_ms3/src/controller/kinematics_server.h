#pragma once

#include "controller/controller_data.h"

namespace controller {

// Implement by controller
class KinematicsServerObserver {
 public:
  virtual ~KinematicsServerObserver() = default;

  virtual void OnWeldAxisOutput(WeldAxis_AdaptioToPlc data)                       = 0;
  virtual void OnWeldHeadManipulatorOutput(WeldHeadManipulator_AdaptioToPlc data) = 0;
  virtual void Release()                                                          = 0;
};

// Use from controller
class KinematicsServer {
 public:
  virtual ~KinematicsServer() = default;

  virtual void OnWeldAxisInput(WeldAxis_PlcToAdaptio data)                       = 0;
  virtual void OnWeldHeadManipulatorInput(WeldHeadManipulator_PlcToAdaptio data) = 0;
  virtual void OnTorchAtEntryPosition(bool status)                               = 0;
};

}  // namespace controller
