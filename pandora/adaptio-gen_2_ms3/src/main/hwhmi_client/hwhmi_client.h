#pragma once

#include <cstdint>
#include <functional>

namespace hwhmi_client {

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

using ButtonStateChangeCb   = std::function<void(ButtonState button_state)>;
using JoystickStateChangeCb = std::function<void(JoystickState joystick_state)>;

class HwHmiClient {
 public:
  virtual ~HwHmiClient() = default;

  virtual void SetButtonStateCallback(ButtonStateChangeCb on_button_state_change)       = 0;
  virtual void SetJoystickStateCallback(JoystickStateChangeCb on_joystick_state_change) = 0;
  virtual void SetJoystickControlMode(JoystickControlMode control_mode)                 = 0;
};

}  // namespace hwhmi_client
