#pragma once

#include <cstdint>

namespace controller {

enum class ButtonState : uint32_t {
  INVALID = 0,
  NONE    = 1,
  START   = 2,
  STOP    = 3,
};

enum class JoystickState : uint32_t {
  INVALID          = 0,
  IDLE             = 1,
  CLICKED_UP       = 2,
  CLICKED_DOWN     = 3,
  CLICKED_SQUARE   = 4,
  CLICKED_TRIANGLE = 5,
  HELD_UP          = 6,
  HELD_DOWN        = 7,
  HELD_SQUARE      = 8,
  HELD_TRIANGLE    = 9,
};

enum class JoystickControlMode : uint32_t {
  INVALID         = 0,
  NO_CONTROL      = 1,
  SLIDE_CROSS     = 2,
  ROLLERBED       = 3,
  COLUMN_AND_BOOM = 4,
};

class HwHmiServerObserver {
 public:
  virtual ~HwHmiServerObserver() = default;

  virtual void OnJoystickControlModeOutput(JoystickControlMode control_mode) = 0;
};

class HwHmiServer {
 public:
  virtual ~HwHmiServer() = default;

  virtual void OnButtonStateChange(ButtonState button_state)       = 0;
  virtual void OnJoystickStateChange(JoystickState joystick_state) = 0;
};

}  // namespace controller
