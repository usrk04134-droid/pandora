#include "plc_oam_server_impl.h"

#include "common/messages/plc_oam.h"
#include "common/zevs/zevs_socket.h"

namespace controller {

PlcOamServerImpl::PlcOamServerImpl(zevs::Socket* socket) : socket_(socket) {
  socket_->Serve(&PlcOamServerImpl::OnGetPlcSwVersion, this);
}

void PlcOamServerImpl::OnShutdownRequestInput() {
  if (!shutdown_sent_) {
    common::msg::plc_oam::Shutdown msg{};
    socket_->Send(msg);
    shutdown_sent_ = true;
  }
}

void PlcOamServerImpl::OnHeartbeatLostInput() {
  common::msg::plc_oam::HeartbeatLost msg{};
  socket_->Send(msg);
}

void PlcOamServerImpl::OnSystemVersionsInput(uint32_t aws_major, uint32_t aws_minor, uint32_t aws_patch) {
  aws_major_ = aws_major;
  aws_minor_ = aws_minor;
  aws_patch_ = aws_patch;
}

void PlcOamServerImpl::OnGetPlcSwVersion(common::msg::plc_oam::GetPlcSwVersion /*data*/) {
  common::msg::plc_oam::GetPlcSwVersionRsp rsp{
      .aws_major = aws_major_,
      .aws_minor = aws_minor_,
      .aws_patch = aws_patch_,
  };
  socket_->Send(rsp);
}

}  // namespace controller
