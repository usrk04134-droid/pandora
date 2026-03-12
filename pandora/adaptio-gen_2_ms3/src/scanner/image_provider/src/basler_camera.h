#pragma once

#include <prometheus/gauge.h>
#include <prometheus/registry.h>
#include <pylon/BaslerUniversalInstantCamera.h>
#include <pylon/PylonIncludes.h>

#include <boost/outcome.hpp>
#include <condition_variable>
#include <map>
#include <thread>

#include "scanner/image/image.h"
#include "scanner/image_provider/image_provider.h"
#include "scanner/image_provider/image_provider_configuration.h"
#include "scanner/image_provider/src/buffered_channel.h"

namespace scanner::image_provider {

// Thread summary:
// main thread: calls Init(), GetSerialNumber()
// Scanner thread: calls all other public methods
// Pylon thread: calls BaslerCameraUpstreamImageEventHandler::OnImageGrabbed()
//                     BaslerCameraUpstreamImageEventHandler::OnImagesSkipped()
//                     CameraEvents::OnCameraDeviceRemoved()
// worker_ thread: owns ReconnectLoop(), calls TryReconnect()

// Synchronization:
// offline_, shutdown_: atomic flags for cross-thread signaling
// cam_m_: serializes all camera_ operations

enum class BaslerCameraErrorCode : uint32_t {
  NO_ERROR                    = 0,
  NO_CAMERA_FOUND             = 1,
  FAILED_TO_ACQUIRE_CAMERA    = 2,
  FAILED_TO_SET_CONFIG        = 3,
  FAILED_TO_OPEN_CAMERA       = 4,
  IMAGE_EVENT_HANDLER_NOT_SET = 5,
};

// NOLINTNEXTLINE(*-identifier-naming)
[[maybe_unused]] auto make_error_code(BaslerCameraErrorCode) -> std::error_code;

class BaslerCamera : public ImageProvider {
 public:
  explicit BaslerCamera(const BaslerConfig &config, const Fov &fov, prometheus::Registry *registry);

  BaslerCamera(BaslerCamera &)                      = delete;
  auto operator=(BaslerCamera &) -> BaslerCamera &  = delete;
  BaslerCamera(BaslerCamera &&)                     = delete;
  auto operator=(BaslerCamera &&) -> BaslerCamera & = delete;

  ~BaslerCamera() override = default;

  auto Init() -> boost::outcome_v2::result<void> override;

  auto Start() -> boost::outcome_v2::result<void> override;
  void Stop() override;
  auto Started() const -> bool override;
  void ResetFOVAndGain() override;
  void SetVerticalFOV(int offset_from_top, int height) override;
  void AdjustGain(double factor) override;
  auto GetVerticalFOVOffset() -> int override;
  auto GetVerticalFOVHeight() -> int override;
  auto GetSerialNumber() -> std::string override;
  void Terminate() override;
  void SetOnImage(OnImage on_image) override { on_image_ = on_image; };
  void OnRemoved();

 private:
  auto InitializeCamera(float gain, float exposure_time) -> boost::outcome_v2::result<void>;
  auto StartCamera() -> boost::outcome_v2::result<void>;
  void SetupMetrics(prometheus::Registry *registry);
  void UpdateMetrics();
  void StopGrabbing();
  void StartGrabbing();
  void ReconnectLoop();
  void TryReconnect();
  auto IsOpen() const -> bool;
  void OpenStart(const Pylon::CDeviceInfo &di);
  void StopClose();
  void DetachCamera();

  std::unique_ptr<Pylon::CBaslerUniversalInstantCamera> camera_;
  BufferedChannel<image::ImagePtr>::WriterPtr channel_;
  std::thread grabbing_thread_;
  BaslerConfig config_;
  Fov fov_;
  OnImage on_image_;

  double initial_gain_ = 0.0;
  std::string serial_number_;
  struct {
    std::map<std::string, prometheus::Gauge &> temperature_status_gauges;
    prometheus::Gauge *temperature_status_error{};
    prometheus::Gauge *temperature{};
    prometheus::Gauge *max_temperature{};
  } metrics_;
  std::chrono::steady_clock::time_point last_get_scanner_metrics_;

  std::thread worker_;

  std::atomic<bool> offline_{false};
  std::atomic<bool> shutdown_{false};

  std::mutex cam_m_;
};

class BaslerCameraUpstreamImageEventHandler : public Pylon::CImageEventHandler {
 public:
  using Timestamp = std::chrono::time_point<std::chrono::steady_clock>;

  BaslerCameraUpstreamImageEventHandler(ImageProvider::OnImage on_image, Timestamp start_time, int64_t start_tick,
                                        int original_offset);

  void OnImageGrabbed(Pylon::CInstantCamera &camera, const Pylon::CGrabResultPtr &) override;
  void OnImagesSkipped(Pylon::CInstantCamera &camera, size_t) override;

 private:
  Timestamp base_timestamp;
  int original_offset_;
  ImageProvider::OnImage on_image_;
};

class CameraEvents : public Pylon::CConfigurationEventHandler {
 public:
  explicit CameraEvents(BaslerCamera *owner) : owner_(owner) {}

  void OnCameraDeviceRemoved(Pylon::CInstantCamera & /*camera*/) override { owner_->OnRemoved(); };

 private:
  BaslerCamera *owner_;
};

}  // namespace scanner::image_provider

namespace std {
template <>
struct is_error_code_enum<scanner::image_provider::BaslerCameraErrorCode> : true_type {};
}  // namespace std
