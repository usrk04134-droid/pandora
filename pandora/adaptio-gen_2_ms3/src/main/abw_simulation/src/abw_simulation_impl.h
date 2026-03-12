#pragma once

#include <functional>
#include <memory>

#include "common/deposition_simulator/sim-config.h"
#include "common/deposition_simulator/simulator_interface.h"
#include "common/zevs/zevs_socket.h"
#include "kinematics/kinematics_client.h"
#include "lpcs/lpcs_slice.h"
#include "web_hmi/web_hmi.h"

namespace abw_simulation {

class AbwSimulation {
 public:
  AbwSimulation(zevs::Timer* timer, web_hmi::WebHmi* web_hmi, kinematics::KinematicsClient* kinematics_client,
                std::function<void(lpcs::Slice)> on_slice_data, std::size_t profile_array_size,
                std::size_t groove_array_size);

 private:
  void SubscribeWebHmi();
  void OnTimeout();

  void OnAbwSimConfigSet(const nlohmann::json& payload);
  void OnAbwSimConfigGet(const nlohmann::json& payload);
  void OnAbwSimStart(const nlohmann::json& payload);
  void OnAbwSimStop(const nlohmann::json& payload);
  void OnAbwSimTorchPosInit(const nlohmann::json& payload);
  void OnAbwSimTorchPosGet(const nlohmann::json& payload);
  void OnAbwSimTorchPosSet(const nlohmann::json& payload);

  zevs::Timer* timer_;
  web_hmi::WebHmi* web_hmi_;
  kinematics::KinematicsClient* kinematics_client_;
  std::function<void(lpcs::Slice)> on_slice_data_;
  const std::size_t profile_array_size_;
  const std::size_t groove_array_size_;
  std::unique_ptr<deposition_simulator::ISimulator> simulator_;
  std::optional<uint32_t> timer_task_id_;
  std::optional<deposition_simulator::SimConfig> sim_config_;
  bool torch_added_{false};
};

}  // namespace abw_simulation
