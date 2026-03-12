#include "abw_simulation_json_helpers.h"

#include <nlohmann/json.hpp>
#include <optional>
#include <tuple>

#include "common/deposition_simulator/sim-config.h"

namespace abw_simulation {

namespace {

auto JointDefToJson(const deposition_simulator::JointDef& joint_def) -> nlohmann::json {
  return nlohmann::json{
      {"basemetalThickness", joint_def.basemetal_thickness},
      {"grooveAng",          joint_def.groove_ang         },
      {"chamferAng",         joint_def.chamfer_ang        },
      {"chamferLen",         joint_def.chamfer_len        },
      {"rootFace",           joint_def.root_face          },
      {"outerDiameter",      joint_def.outer_diameter     },
      {"radialOffset",       joint_def.radial_offset      }
  };
}

auto JointDefFromJson(const nlohmann::json& json) -> std::optional<deposition_simulator::JointDef> {
  try {
    deposition_simulator::JointDef joint_def;
    joint_def.basemetal_thickness = json.at("basemetalThickness").get<double>();
    joint_def.groove_ang          = json.at("grooveAng").get<double>();
    joint_def.chamfer_ang         = json.at("chamferAng").get<double>();
    joint_def.chamfer_len         = json.at("chamferLen").get<double>();
    joint_def.root_face           = json.at("rootFace").get<double>();
    joint_def.outer_diameter      = json.at("outerDiameter").get<double>();
    joint_def.radial_offset       = json.at("radialOffset").get<double>();
    return joint_def;
  } catch (...) {
    return std::nullopt;
  }
}

auto LpcsConfigToJson(const deposition_simulator::LpcsConfig& lpcs_config) -> nlohmann::json {
  return nlohmann::json{
      {"alpha", lpcs_config.alpha},
      {"x",     lpcs_config.x    },
      {"y",     lpcs_config.y    },
      {"z",     lpcs_config.z    }
  };
}

auto LpcsConfigFromJson(const nlohmann::json& json) -> std::optional<deposition_simulator::LpcsConfig> {
  try {
    deposition_simulator::LpcsConfig lpcs_config;
    lpcs_config.alpha = json.at("alpha").get<double>();
    lpcs_config.x     = json.at("x").get<double>();
    lpcs_config.y     = json.at("y").get<double>();
    lpcs_config.z     = json.at("z").get<double>();
    return lpcs_config;
  } catch (...) {
    return std::nullopt;
  }
}

auto OpcsConfigToJson(const deposition_simulator::OpcsConfig& opcs_config) -> nlohmann::json {
  return nlohmann::json{
      {"x", opcs_config.x},
      {"y", opcs_config.y},
      {"z", opcs_config.z}
  };
}

auto OpcsConfigFromJson(const nlohmann::json& json) -> std::optional<deposition_simulator::OpcsConfig> {
  try {
    deposition_simulator::OpcsConfig opcs_config;
    opcs_config.x = json.at("x").get<double>();
    opcs_config.y = json.at("y").get<double>();
    opcs_config.z = json.at("z").get<double>();
    return opcs_config;
  } catch (...) {
    return std::nullopt;
  }
}

auto WeldMovementTypeToString(deposition_simulator::WeldMovementType type) -> std::string {
  switch (type) {
    case deposition_simulator::WeldMovementType::CIRCUMFERENTIAL:
      return "circumferential";
    case deposition_simulator::WeldMovementType::LONGITUDINAL:
      return "longitudinal";
    default:
      return "circumferential";
  }
}

auto WeldMovementTypeFromString(const std::string& str) -> deposition_simulator::WeldMovementType {
  if (str == "longitudinal") {
    return deposition_simulator::WeldMovementType::LONGITUDINAL;
  }
  return deposition_simulator::WeldMovementType::CIRCUMFERENTIAL;
}

}  // namespace

auto AbwSimConfigToJson(const deposition_simulator::SimConfig& config) -> nlohmann::json {
  return nlohmann::json{
      {"weldMovementType",      WeldMovementTypeToString(config.weld_movement_type)},
      {"targetStickout",        config.target_stickout                             },
      {"nbrAbwPoints",          config.nbr_abw_points                              },
      {"travelSpeed",           config.travel_speed                                },
      {"rootGap",               config.root_gap                                    },
      {"totalWidth",            config.total_width                                 },
      {"jointBottomCurvRadius", config.joint_bottom_curv_radius                    },
      {"jointDepthPercentage",  config.joint_depth_percentage                      },
      {"nbrJointBottomPoints",  config.nbr_joint_bottom_points                     },
      {"nbrSlicesPerRev",       config.nbr_slices_per_rev                          },
      {"driftSpeed",            config.drift_speed                                 },
      {"ignoreCollisions",      config.ignore_collisions                           },
      {"jointDefLeft",          JointDefToJson(config.joint_def_left)              },
      {"jointDefRight",         JointDefToJson(config.joint_def_right)             },
      {"lpcsConfig",            LpcsConfigToJson(config.lpcs_config)               },
      {"opcsConfig",            OpcsConfigToJson(config.opcs_config)               }
  };
}

auto AbwSimConfigFromJson(const nlohmann::json& payload) -> std::optional<deposition_simulator::SimConfig> {
  try {
    deposition_simulator::SimConfig config;

    if (payload.contains("weldMovementType")) {
      config.weld_movement_type = WeldMovementTypeFromString(payload.at("weldMovementType").get<std::string>());
    }
    if (payload.contains("targetStickout")) {
      config.target_stickout = payload.at("targetStickout").get<double>();
    }
    if (payload.contains("nbrAbwPoints")) {
      config.nbr_abw_points = payload.at("nbrAbwPoints").get<int>();
    }
    if (payload.contains("travelSpeed")) {
      config.travel_speed = payload.at("travelSpeed").get<double>();
    }
    if (payload.contains("rootGap")) {
      config.root_gap = payload.at("rootGap").get<double>();
    }
    if (payload.contains("totalWidth")) {
      config.total_width = payload.at("totalWidth").get<double>();
    }
    if (payload.contains("jointBottomCurvRadius")) {
      config.joint_bottom_curv_radius = payload.at("jointBottomCurvRadius").get<double>();
    }
    if (payload.contains("jointDepthPercentage")) {
      config.joint_depth_percentage = payload.at("jointDepthPercentage").get<int>();
    }
    if (payload.contains("nbrJointBottomPoints")) {
      config.nbr_joint_bottom_points = payload.at("nbrJointBottomPoints").get<int>();
    }
    if (payload.contains("nbrSlicesPerRev")) {
      config.nbr_slices_per_rev = payload.at("nbrSlicesPerRev").get<int>();
    }
    if (payload.contains("driftSpeed")) {
      config.drift_speed = payload.at("driftSpeed").get<double>();
    }
    if (payload.contains("ignoreCollisions")) {
      config.ignore_collisions = payload.at("ignoreCollisions").get<bool>();
    }
    if (payload.contains("jointDefLeft")) {
      auto joint_def_left = JointDefFromJson(payload.at("jointDefLeft"));
      if (joint_def_left.has_value()) {
        config.joint_def_left = joint_def_left.value();
      }
    }
    if (payload.contains("jointDefRight")) {
      auto joint_def_right = JointDefFromJson(payload.at("jointDefRight"));
      if (joint_def_right.has_value()) {
        config.joint_def_right = joint_def_right.value();
      }
    }
    if (payload.contains("lpcsConfig")) {
      auto lpcs_config = LpcsConfigFromJson(payload.at("lpcsConfig"));
      if (lpcs_config.has_value()) {
        config.lpcs_config = lpcs_config.value();
      }
    }
    if (payload.contains("opcsConfig")) {
      auto opcs_config = OpcsConfigFromJson(payload.at("opcsConfig"));
      if (opcs_config.has_value()) {
        config.opcs_config = opcs_config.value();
      }
    }

    return config;
  } catch (...) {
    return std::nullopt;
  }
}

auto AbwSimStartFromJson(const nlohmann::json& payload) -> std::optional<uint32_t> {
  try {
    if (payload.contains("timeoutMs")) {
      return payload.at("timeoutMs").get<uint32_t>();
    }
    // Default timeout if not specified
    return 500;
  } catch (...) {
    return std::nullopt;
  }
}

auto AbwSimTorchPosToJson(double torch_x, double torch_y, double torch_z) -> nlohmann::json {
  return nlohmann::json{
      {"x", torch_x},
      {"y", torch_y},
      {"z", torch_z}
  };
}

auto AbwSimTorchPosFromJson(const nlohmann::json& payload) -> std::optional<std::tuple<double, double, double>> {
  try {
    double x = payload.at("x").get<double>();
    double y = payload.at("y").get<double>();
    double z = payload.at("z").get<double>();
    return std::make_tuple(x, y, z);
  } catch (...) {
    return std::nullopt;
  }
}

}  // namespace abw_simulation