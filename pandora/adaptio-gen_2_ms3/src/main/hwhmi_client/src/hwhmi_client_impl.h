#pragma once

#include "common/messages/hwhmi.h"
#include "common/zevs/zevs_socket.h"
#include "hwhmi_client/hwhmi_client.h"

namespace hwhmi_client {

class HwHmiClientImpl : public HwHmiClient {
 public:
  explicit HwHmiClientImpl(zevs::Socket* socket);

  void SetButtonStateCallback(ButtonStateChangeCb on_button_state_change) override;
  void SetJoystickStateCallback(JoystickStateChangeCb on_joystick_state_change) override;
  void SetJoystickControlMode(JoystickControlMode control_mode) override;

 private:
  void OnButtonStateChange(common::msg::hwhmi::OnButtonStateChange data);
  void OnJoystickStateChange(common::msg::hwhmi::OnJoystickStateChange data);

  zevs::Socket* socket_;
  ButtonStateChangeCb on_button_state_change_;
  JoystickStateChangeCb on_joystick_state_change_;
};

}  // namespace hwhmi_client
