#include "scanner/image_provider/src/camera_link.h"

#include <linux/netlink.h>
#include <linux/rtnetlink.h>
#include <net/if.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <unistd.h>

#include <cstring>
#include <stdexcept>
#include <string>

#include "common/logging/application_log.h"

namespace scanner::image_provider {

void CameraLink::Bounce() {
  if (IsUp()) {
    SetLinkUp(false);
    ::usleep(200 * 1000);  // 200ms; adjust if needed
    SetLinkUp(true);
  } else {
    LOG_INFO("Interface is not UP");
  }
}

auto CameraLink::IsUp() -> bool {
  int fd = ::socket(AF_INET, SOCK_DGRAM, 0);
  if (fd < 0) {
    throw std::runtime_error("socket(AF_INET) failed");
  }

  struct ifreq ifr{};
  std::strncpy(ifr.ifr_name, CAMERA_IF_NAME.c_str(), IFNAMSIZ - 1);

  if (::ioctl(fd, SIOCGIFFLAGS, &ifr) < 0) {
    ::close(fd);
    throw std::runtime_error("SIOCGIFFLAGS failed for " + CAMERA_IF_NAME);
  }

  ::close(fd);
  return (ifr.ifr_flags & IFF_UP) != 0;
}

void CameraLink::SetLinkUp(bool up) {
  int ifindex = if_nametoindex(CAMERA_IF_NAME.c_str());
  if (ifindex == 0) {
    throw std::runtime_error("Unknown interface: " + CAMERA_IF_NAME);
  }

  int fd = ::socket(AF_NETLINK, SOCK_RAW, NETLINK_ROUTE);
  if (fd < 0) {
    throw std::runtime_error("NETLINK_ROUTE socket failed");
  }

  struct {
    nlmsghdr nh;
    ifinfomsg ifi;
  } req{};

  req.nh.nlmsg_len   = NLMSG_LENGTH(sizeof(ifinfomsg));
  req.nh.nlmsg_type  = RTM_NEWLINK;
  req.nh.nlmsg_flags = NLM_F_REQUEST | NLM_F_ACK;
  req.ifi.ifi_family = AF_UNSPEC;
  req.ifi.ifi_index  = ifindex;
  req.ifi.ifi_change = IFF_UP;
  req.ifi.ifi_flags  = up ? IFF_UP : 0;

  sockaddr_nl nladdr{};
  nladdr.nl_family = AF_NETLINK;

  if (::sendto(fd, &req, req.nh.nlmsg_len, 0, (sockaddr*)&nladdr, sizeof(nladdr)) < 0) {
    ::close(fd);
    throw std::runtime_error("netlink sendto failed");
  }

  char buf[4096];
  int len = ::recv(fd, buf, sizeof(buf), 0);
  if (len < 0) {
    ::close(fd);
    throw std::runtime_error("netlink recv failed");
  }

  auto* nh = reinterpret_cast<nlmsghdr*>(buf);
  if (nh->nlmsg_type == NLMSG_ERROR) {
    auto* err = reinterpret_cast<nlmsgerr*>(NLMSG_DATA(nh));
    if (err->error != 0) {
      ::close(fd);
      throw std::runtime_error("netlink error: " + std::to_string(-err->error));
    }
  }

  ::close(fd);
}
}  // namespace scanner::image_provider
