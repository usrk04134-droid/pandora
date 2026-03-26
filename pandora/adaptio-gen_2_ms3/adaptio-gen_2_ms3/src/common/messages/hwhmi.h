#pragma once

#include <cstdint>

namespace common::msg::hwhmi {

const uint32_t HWHMI_BASE_ID = 0x08000000;

struct OnButtonStateChange {
  enum class Metadata : uint32_t { MESSAGE_ID = HWHMI_BASE_ID + 1 };

  enum class ButtonState : uint32_t {
    INVALID = 0,
    NONE    = 1,
    START   = 2,
    STOP    = 3,
  } button_state{ButtonState::INVALID};
};

struct OnJoystickStateChange {
  enum class Metadata : uint32_t { MESSAGE_ID = HWHMI_BASE_ID + 2 };

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
  } joystick_state{JoystickState::INVALID};
};

enum class JoystickControlMode : uint32_t {
  INVALID         = 0,
  NO_CONTROL      = 1,
  SLIDE_CROSS     = 2,
  ROLLERBED       = 3,
  COLUMN_AND_BOOM = 4,
};

struct SetJoystickControlMode {
  enum class Metadata : uint32_t { MESSAGE_ID = HWHMI_BASE_ID + 3 };

  JoystickControlMode control_mode{JoystickControlMode::INVALID};
};

}  // namespace common::msg::hwhmi
