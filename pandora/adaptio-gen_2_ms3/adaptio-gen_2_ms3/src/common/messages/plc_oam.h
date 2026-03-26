#pragma once

#include <cstdint>

namespace common::msg::plc_oam {

const uint32_t PLC_OAM_BASE_ID = 0x09000000;

struct Shutdown {
  enum class Metadata : uint32_t { MESSAGE_ID = PLC_OAM_BASE_ID + 1 };
};

struct HeartbeatLost {
  enum class Metadata : uint32_t { MESSAGE_ID = PLC_OAM_BASE_ID + 2 };
};

struct GetPlcSwVersion {
  enum class Metadata : uint32_t { MESSAGE_ID = PLC_OAM_BASE_ID + 3 };
};

struct GetPlcSwVersionRsp {
  enum class Metadata : uint32_t { MESSAGE_ID = PLC_OAM_BASE_ID + 4 };

  uint32_t aws_major{0};
  uint32_t aws_minor{0};
  uint32_t aws_patch{0};
};

}  // namespace common::msg::plc_oam
