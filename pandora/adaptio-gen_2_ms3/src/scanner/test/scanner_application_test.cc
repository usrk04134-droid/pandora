
#include "../scanner_application.h"

#include <doctest/doctest.h>
#include <prometheus/registry.h>

#include <boost/outcome.hpp>
#include <memory>
#include <optional>
#include <trompeloeil.hpp>  // IWYU pragma: keep
#include <trompeloeil/mock.hpp>
#include <utility>

#include "common/groove/groove.h"
#include "common/groove/point.h"
#include "common/messages/scanner.h"
#include "common/zevs/zevs_core.h"
#include "common/zevs/zevs_socket.h"
#include "common/zevs/zevs_test_support.h"
#include "joint_geometry/joint_geometry.h"
#include "mock/core_scanner_mock.h"
#include "mock/image_logger_mock.h"
#include "mock/stub_core_factory.h"
#include "scanner/core/scanner_calibration_configuration.h"
#include "scanner/core/scanner_configuration.h"
#include "scanner/core/src/scanner.h"
#include "scanner/core/src/scanner_metrics_impl.h"
#include "scanner/image_provider/image_provider_configuration.h"
#include "scanner/joint_model/joint_model.h"
#include "scanner/scanner_factory.h"
#include "scanner/slice_provider/slice_provider.h"

using trompeloeil::_;

// NOLINTBEGIN(*-magic-numbers, misc-include-cleaner)
namespace scanner {

TEST_SUITE("Test Scanner Adapter Scanner") {
  TEST_CASE("Test normal flow") {
    zevs::MocketFactory mocket_factory;

    auto event_loop     = zevs::GetCoreFactory()->CreateEventLoop("mock");
    auto scanner_socket = zevs::GetFactory()->CreatePairSocket(*event_loop);
    scanner_socket->Connect("inproc://mock/scanner");

    auto image_logger_mock_unique_ptr = std::make_unique<ImageLoggerMock>();
    auto* image_logger_mock           = image_logger_mock_unique_ptr.get();

    auto scanner_mock_unique_ptr = std::make_unique<CoreScannerMock>();
    auto* scanner_mock           = scanner_mock_unique_ptr.get();
    StubCoreScannerFactory factory(std::move(scanner_mock_unique_ptr), std::move(image_logger_mock_unique_ptr));

    auto mock = [&]() { return &factory; };
    scanner::SetFactoryGenerator(mock);

    auto registry        = std::make_shared<prometheus::Registry>();
    auto scanner_metrics = std::make_unique<scanner::ScannerMetricsImpl>(registry.get());
    scanner::ScannerApplication scanner_application(ScannerConfigurationData{}, ScannerCalibrationData{},
                                                    image_provider::Fov{}, nullptr, "mock", std::nullopt,
                                                    image_logger_mock, scanner_metrics.get());

    scanner_application.ThreadEntry("Scanner");
    auto scanner_mocket = mocket_factory.GetMocket(zevs::Endpoint::BIND, "inproc://mock/scanner");
    CHECK_NE(scanner_mocket, nullptr);

    // Start
    REQUIRE_CALL(*image_logger_mock, AddMetaData(_, _));
    REQUIRE_CALL(*scanner_mock, SetJointGeometry(_));

    scanner_mocket->Dispatch(common::msg::scanner::SetJointGeometry{
        .joint_geometry =
            {
                             57.58,   // upper_joint_width_mm
                19.6,    // groove_depth_mm
                0.5236,  // left_joint_angle_rad
                0.5236,  // right_joint_angle_rad
                0.3491,  // left_max_surface_angle_rad
                0.3491,  // right_max_surface_angle_rad
            },
    });

    auto input_msg = scanner_mocket->Receive<common::msg::scanner::SetJointGeometryRsp>();
    CHECK_EQ(input_msg.value().success, true);

    // FlushImageBuffer
    REQUIRE_CALL(*image_logger_mock, FlushBuffer());
    scanner_mocket->Dispatch(common::msg::scanner::FlushImageBuffer{});

    common::Groove groove;

    factory.GetScannerOutput()->ScannerOutput(groove, std::array<common::Point, joint_model::INTERPOLATED_SNAKE_SIZE>(),
                                              1, slice_provider::SliceConfidence::HIGH);

    auto output_msg = scanner_mocket->Receive<common::msg::scanner::SliceData>();

    CHECK(output_msg.has_value());
  }
}
}  // namespace scanner

// NOLINTEND(*-magic-numbers, misc-include-cleaner)
