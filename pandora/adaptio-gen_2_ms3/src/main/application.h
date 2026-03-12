#pragma once

#include <prometheus/registry.h>
#include <SQLiteCpp/Database.h>

#include <filesystem>
#include <memory>
#include <string>

#include "abw_simulation/src/abw_simulation_impl.h"
#include "bead_control/bead_control.h"
#include "calibration/src/calibration_manager_impl.h"
#include "calibration/src/calibration_metrics.h"
#include "calibration/src/calibration_solver.h"
#include "common/clock_functions.h"
#include "common/zevs/zevs_core.h"
#include "common/zevs/zevs_socket.h"
#include "configuration/config_manager.h"
#include "coordination/activity_status.h"
#include "event_handler/src/event_handler_impl.h"
#include "hwhmi_client/src/hwhmi_client_impl.h"
#include "image_logging/image_logging_manager.h"
#include "joint_geometry/src/joint_geometry_provider_impl.h"
#include "management/src/management_server.h"
#include "plc_oam_client/src/plc_oam_client_impl.h"
#include "scanner_client/src/scanner_client_impl.h"
#include "slice_translator/src/coordinates_translator.h"
#include "slice_translator/src/linear_model_impl.h"
#include "slice_translator/src/rotary_model_impl.h"
#include "slice_translator/src/slice_translator_service_impl.h"
#include "tracking/tracking_manager.h"
#include "web_hmi/src/web_hmi_server.h"
#include "weld_control/src/delay_buffer.h"
#include "weld_control/src/manual_weld.h"
#include "weld_control/src/settings_provider.h"
#include "weld_control/src/weld_control_impl.h"
#include "weld_control/src/weld_control_metrics_impl.h"
#include "weld_control/src/weld_sequence_config_impl.h"
#include "weld_motion_prediction/src/circle_trajectory.h"
#include "weld_motion_prediction/src/linear_trajectory.h"
#include "weld_motion_prediction/src/lpcs_to_macs_transformer.h"
#include "weld_motion_prediction/weld_motion_context.h"
#include "weld_system_client/weld_system_client.h"

class Application {
 public:
  explicit Application(configuration::ConfigManager* configuration, std::filesystem::path const& path_events,
                       SQLite::Database* database, std::filesystem::path const& path_logs,
                       clock_functions::SystemClockNowFunc system_clock_now_func,
                       clock_functions::SteadyClockNowFunc steady_clock_now_func, prometheus::Registry* registry,
                       int log_level);

  auto Run(const std::string& event_loop_name, const std::string& endpoint_base_url) -> bool;
  auto InShutdown() const -> bool;
  void Exit();

 private:
  void OnTimeout();

  std::string event_loop_name_;
  zevs::EventLoopPtr event_loop_;
  zevs::TimerPtr timer_;
  zevs::SocketPtr kinematics_socket_;
  zevs::SocketPtr scanner_client_socket_;
  zevs::SocketPtr weld_system_client_socket_;
  zevs::SocketPtr plc_oam_client_socket_;
  zevs::SocketPtr hwhmi_client_socket_;
  std::string web_hmi_in_endpoint_url_  = "tcp://0.0.0.0:5555";
  std::string web_hmi_out_endpoint_url_ = "tcp://0.0.0.0:5556";
  zevs::CoreSocketPtr web_hmi_in_socket_;
  zevs::CoreSocketPtr web_hmi_out_socket_;
  SQLite::Database* database_;

  std::unique_ptr<event::EventHandlerImpl> event_handler_;
  std::unique_ptr<kinematics::KinematicsClient> kinematics_client_;
  std::unique_ptr<scanner_client::ScannerClientImpl> scanner_client_;
  std::unique_ptr<weld_motion_prediction::LpcsToMacsTransformer> transformer_;
  std::unique_ptr<weld_motion_prediction::CircleTrajectory> cw_trajectory_;
  std::unique_ptr<weld_motion_prediction::LinearTrajectory> lw_trajectory_;
  std::unique_ptr<weld_motion_prediction::WeldMotionContext> weld_motion_context_;
  std::unique_ptr<slice_translator::SliceTranslatorServiceImpl> slice_translator_;
  std::unique_ptr<slice_translator::RotaryModelImpl> cw_model_impl_;
  std::unique_ptr<slice_translator::LinearModelImpl> lw_model_impl_;
  std::unique_ptr<calibration::CalibrationSolver> calibration_solver_;
  std::unique_ptr<calibration::CalibrationMetrics> calibration_metrics_;
  std::unique_ptr<calibration::CalibrationManagerImpl> calibration_manager_;
  std::unique_ptr<tracking::TrackingManager> tracking_manager_;
  std::unique_ptr<slice_translator::CoordinatesTranslator> coordinates_translator_;
  std::unique_ptr<management::ManagementServer> management_server_;
  std::unique_ptr<web_hmi::WebHmiServer> web_hmi_server_;
  std::unique_ptr<coordination::ActivityStatus> activity_status_;
  std::unique_ptr<bead_control::BeadControl> bead_control_;
  std::unique_ptr<weld_control::DelayBuffer> delay_buffer_;
  std::unique_ptr<weld_control::WeldSequenceConfigImpl> weld_sequence_config_;
  std::unique_ptr<weld_control::SettingsProvider> settings_provider_;
  std::unique_ptr<weld_control::WeldControlImpl> weld_control_;
  std::unique_ptr<weld_system::WeldSystemClient> weld_system_client_;
  std::unique_ptr<plc_oam_client::PlcOamClientImpl> plc_oam_client_;
  std::unique_ptr<hwhmi_client::HwHmiClientImpl> hwhmi_client_;
  std::unique_ptr<weld_control::ManualWeld> manual_weld_;
  std::unique_ptr<joint_geometry::JointGeometryProviderImpl> joint_geometry_provider_;
  std::unique_ptr<image_logging::ImageLoggingManager> image_logging_manager_;
  std::unique_ptr<weld_control::WeldControlMetricsImpl> metrics_;
  std::unique_ptr<abw_simulation::AbwSimulation> abw_simulation_;

  configuration::ConfigManager* configuration_;
  std::filesystem::path path_logs_;
  std::filesystem::path path_events_;
  clock_functions::SystemClockNowFunc system_clock_now_func_;
  clock_functions::SteadyClockNowFunc steady_clock_now_func_;
  prometheus::Registry* registry_;
  bool in_shutdown_ = false;
  int log_level_;
};
