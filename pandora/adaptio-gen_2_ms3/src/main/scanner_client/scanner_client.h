#pragma once

#include <fmt/core.h>

#include <chrono>

#include "common/groove/point.h"
#include "common/logging/application_log.h"
#include "joint_geometry/joint_geometry.h"
#include "lpcs/lpcs_slice.h"
#include "main/lpcs/lpcs_point.h"

namespace scanner_client {

auto const DEFAULT_INPUT_INTERVAL = std::chrono::milliseconds(50);

enum class ScannerSensitivity {
  NORMAL = 0,
  HIGH   = 1,
};

class ScannerClient {
 public:
  virtual ~ScannerClient() = default;

  using OnGeometryApplied   = std::function<void(bool success)>;
  using OnScannerDataUpdate = std::function<void(const lpcs::Slice& data, const common::Point& axis_position)>;

  struct Config {
    ScannerSensitivity sensitivity{ScannerSensitivity::NORMAL};
    std::chrono::milliseconds interval{DEFAULT_INPUT_INTERVAL};
  };

  struct UpdateData {
    double upper_width{0.0};
    double left_wall_angle{0.0};
    double right_wall_angle{0.0};
    struct {
      double upper_width{0.0};
      double wall_angle{0.0};
    } tolerance;

    double abw0_horizontal;
    double abw6_horizontal;
  };

  virtual void SetJointGeometry(const joint_geometry::JointGeometry& joint_geometry) = 0;
  virtual void Update(const UpdateData& data)                                        = 0;

  struct ImageLoggingData {
    enum class Mode {
      OFF,
      DIRECT,
      BUFFERED,
      ON_ERROR,
    };

    Mode mode{Mode::OFF};
    uint32_t sample_rate{1};
    uint32_t buffer_size{1};
    std::chrono::milliseconds on_error_interval;
    std::filesystem::path path;
  };

  virtual void ImageLoggingUpdate(const ImageLoggingData& data) = 0;
  virtual void FlushImageBuffer()                               = 0;

  virtual auto SubscribeScanner(OnGeometryApplied on_geometry_applied, OnScannerDataUpdate on_data_update)
      -> uint32_t                              = 0;
  virtual void UnsubscribeScanner(uint32_t id) = 0;
};

}  // namespace scanner_client
