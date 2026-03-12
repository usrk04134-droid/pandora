#include "hwhmi_client_impl.h"

#include "../hwhmi_client.h"
#include "common/messages/hwhmi.h"
#include "common/zevs/zevs_socket.h"

using hwhmi_client::HwHmiClientImpl;

HwHmiClientImpl::HwHmiClientImpl(zevs::Socket* socket) : socket_(socket) {
  socket_->Serve(&HwHmiClientImpl::OnButtonStateChange, this);
  socket_->Serve(&HwHmiClientImpl::OnJoystickStateChange, this);
}

void HwHmiClientImpl::OnButtonStateChange(common::msg::hwhmi::OnButtonStateChange data) {
  if (on_button_state_change_ != nullptr) {
    on_button_state_change_(static_cast<ButtonState>(data.button_state));
  }
}

void HwHmiClientImpl::OnJoystickStateChange(common::msg::hwhmi::OnJoystickStateChange data) {
  if (on_joystick_state_change_ != nullptr) {
    on_joystick_state_change_(static_cast<JoystickState>(data.joystick_state));
  }
}

void HwHmiClientImpl::SetButtonStateCallback(ButtonStateChangeCb on_button_state_change) {
  on_button_state_change_ = on_button_state_change;
}

void HwHmiClientImpl::SetJoystickStateCallback(JoystickStateChangeCb on_joystick_state_change) {
  on_joystick_state_change_ = on_joystick_state_change;
}

void HwHmiClientImpl::SetJoystickControlMode(JoystickControlMode control_mode) {
  common::msg::hwhmi::SetJoystickControlMode msg{
      .control_mode = static_cast<common::msg::hwhmi::JoystickControlMode>(control_mode),
  };
  socket_->Send(msg);
}
