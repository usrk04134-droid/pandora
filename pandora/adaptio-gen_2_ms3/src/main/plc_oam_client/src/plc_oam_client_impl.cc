#include "plc_oam_client_impl.h"

#include "../plc_oam_client.h"
#include "common/messages/plc_oam.h"
#include "common/zevs/zevs_socket.h"

using plc_oam_client::PlcOamClientImpl;

PlcOamClientImpl::PlcOamClientImpl(zevs::Socket* socket) : socket_(socket) {
  socket_->Serve(&PlcOamClientImpl::OnGetPlcSwVersionRsp, this);
  socket_->Serve(&PlcOamClientImpl::OnHeartbeatLost, this);
  socket_->Serve(&PlcOamClientImpl::OnShutdown, this);
}

void PlcOamClientImpl::OnGetPlcSwVersionRsp(common::msg::plc_oam::GetPlcSwVersionRsp data) {
  if (on_get_version_ == nullptr) {
    return;
  }

  auto const version = PlcSwVersion{
      .aws_major = data.aws_major,
      .aws_minor = data.aws_minor,
      .aws_patch = data.aws_patch,
  };

  on_get_version_(version);
}

void PlcOamClientImpl::OnHeartbeatLost(common::msg::plc_oam::HeartbeatLost /*data*/) {
  if (on_heartbeat_lost_ != nullptr) {
    on_heartbeat_lost_();
  }
}

void PlcOamClientImpl::OnShutdown(common::msg::plc_oam::Shutdown /*data*/) {
  if (on_shutdown_ != nullptr) {
    on_shutdown_();
  }
}

void PlcOamClientImpl::GetPlcSwVersion(GetPlcSwVersionCb on_response) {
  on_get_version_ = on_response;
  common::msg::plc_oam::GetPlcSwVersion msg{};
  socket_->Send(msg);
}

void PlcOamClientImpl::SetHeartbeatLostCallback(HeartbeatLostCb on_heartbeat_lost) {
  on_heartbeat_lost_ = on_heartbeat_lost;
}

void PlcOamClientImpl::SetShutdownCallback(ShutdownCb on_shutdown) { on_shutdown_ = on_shutdown; }
