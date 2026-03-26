#include "hwhmi_server_impl.h"

#include "common/messages/hwhmi.h"
#include "common/zevs/zevs_socket.h"
#include "controller/hwhmi_server.h"

namespace controller {

HwHmiServerImpl::HwHmiServerImpl(zevs::Socket* socket, HwHmiServerObserver* observer)
    : socket_(socket), observer_(observer) {
  socket_->Serve(&HwHmiServerImpl::OnSetJoystickControlMode, this);
}

void HwHmiServerImpl::OnButtonStateChange(ButtonState button_state) {
  current_button_state_ = button_state;
  SendButtonStateChange(button_state);
}

void HwHmiServerImpl::SendButtonStateChange(ButtonState button_state) {
  common::msg::hwhmi::OnButtonStateChange msg{
      .button_state = static_cast<common::msg::hwhmi::OnButtonStateChange::ButtonState>(button_state),
  };
  socket_->Send(msg);
}

void HwHmiServerImpl::OnJoystickStateChange(JoystickState joystick_state) {
  current_joystick_state_ = joystick_state;
  SendJoystickStateChange(joystick_state);
}

void HwHmiServerImpl::SendJoystickStateChange(JoystickState joystick_state) {
  common::msg::hwhmi::OnJoystickStateChange msg{
      .joystick_state = static_cast<common::msg::hwhmi::OnJoystickStateChange::JoystickState>(joystick_state),
  };
  socket_->Send(msg);
}

void HwHmiServerImpl::OnSetJoystickControlMode(common::msg::hwhmi::SetJoystickControlMode data) {
  observer_->OnJoystickControlModeOutput(static_cast<JoystickControlMode>(data.control_mode));
}

}  // namespace controller
