#pragma once

#include <nlohmann/json.hpp>

// NOLINTBEGIN(*-magic-numbers)

namespace weld_parameters_test_data {

// Default weld process parameters for testing
inline const nlohmann::json WPP_DEFAULT_WS1 = {
    {"name",           "ManualWS1"},
    {"method",         "dc"       },
    {"regulationType", "cc"       },
    {"startAdjust",    10         },
    {"startType",      "scratch"  },
    {"voltage",        25.0       },
    {"current",        200.0      },
    {"wireSpeed",      15.0       },
    {"iceWireSpeed",   0.0        },
    {"acFrequency",    60.0       },
    {"acOffset",       1.2        },
    {"acPhaseShift",   0.5        },
    {"craterFillTime", 2.0        },
    {"burnBackTime",   1.0        }
};

inline const nlohmann::json WPP_DEFAULT_WS2 = {
    {"name",           "ManualWS2"},
    {"method",         "dc"       },
    {"regulationType", "cc"       },
    {"startAdjust",    10         },
    {"startType",      "direct"   },
    {"voltage",        28.0       },
    {"current",        180.0      },
    {"wireSpeed",      14.0       },
    {"iceWireSpeed",   0.0        },
    {"acFrequency",    60.0       },
    {"acOffset",       1.2        },
    {"acPhaseShift",   0.5        },
    {"craterFillTime", 2.0        },
    {"burnBackTime",   1.0        }
};

}  // namespace weld_parameters_test_data

// NOLINTEND(*-magic-numbers)
