#include <doctest/doctest.h>

#include <array>
#include <vector>

#include "common/groove/point.h"
#include "common/types/vector_3d.h"
#include "lpcs/lpcs_point.h"
#include "weld_motion_prediction/src/circle_trajectory.h"
#include "weld_motion_prediction/src/lpcs_to_macs_transformer.h"
#include "weld_motion_prediction/src/weld_motion_context_impl.h"

namespace weld_motion_prediction {

TEST_SUITE("trajectory_calculations") {
  TEST_CASE("trajectory_does_not_intersect_plane") {
    // Test data taken from logs to replicate and fix observed error behaviour

    // Calibration data
    // NOLINTBEGIN(*-magic-numbers)
    common::Vector3D rotation_center = {.c1 = -149.91984786039848, .c2 = -88.59110043257607, .c3 = -2233.0745596575002};
    common::Vector3D rotation_axis   = {.c1 = 1.0, .c2 = 0.0, .c3 = 0.0};
    double scanner_mount_angle{0.44505895925855404};
    std::array<double, 3> scanner_angles       = {scanner_mount_angle, 0.0, 0.0};
    common::Vector3D torch_to_lpcs_translation = {
        .c1 = 49.97751239831232, .c2 = 181.44475860127773, .c3 = 37.11839456855785};

    // Slide data
    common::Point slide_position = {.horizontal = -163.86, .vertical = -1516.05};

    // Scanner data to be converted
    std::vector<lpcs::Point> laser_points{
        {.x = 8.83, .y = -800}
    };  // This point does not intersect torch plane

    // Setup converter classes
    CircleTrajectory trajectory;
    trajectory.Set(rotation_center, rotation_axis);

    LpcsToMacsTransformer transformer;
    transformer.SetTransform(scanner_angles, torch_to_lpcs_translation);
    transformer.UpdateMacsToTcsTranslation(slide_position);

    WeldMotionContextImpl weld_motion_context{&trajectory, &transformer};

    weld_motion_context.SetActiveTrajectory(&trajectory);
    common::Point intersection;

    for (const auto &point : laser_points) {
      intersection = weld_motion_context.IntersectTorchPlane(point);
      CHECK_LE(std::abs(intersection.horizontal - 0.0), 1e-6);
      CHECK_LE(std::abs(intersection.vertical - 0.0), 1e-6);
    }
  }
  // NOLINTEND(*-magic-numbers)
}
}  // namespace weld_motion_prediction
