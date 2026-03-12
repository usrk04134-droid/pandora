#pragma once

#include "common/messages/hwhmi.h"
#include "common/zevs/zevs_socket.h"
#include "hwhmi_server.h"

namespace controller {

class HwHmiServerImpl : public HwHmiServer {
 public:
  explicit HwHmiServerImpl(zevs::Socket* socket, HwHmiServerObserver* observer);

  void OnButtonStateChange(ButtonState button_state) override;
  void OnJoystickStateChange(JoystickState joystick_state) override;

 private:
  zevs::Socket* socket_;
  HwHmiServerObserver* observer_;
  ButtonState current_button_state_{ButtonState::INVALID};
  JoystickState current_joystick_state_{JoystickState::INVALID};

  void SendButtonStateChange(ButtonState button_state);
  void SendJoystickStateChange(JoystickState joystick_state);
  void OnSetJoystickControlMode(common::msg::hwhmi::SetJoystickControlMode data);
};

}  // namespace controller
