#include "scanner/joint_model/src/big_snake.h"

#include <math.h>

#include <algorithm>
#include <boost/math/statistics/linear_regression.hpp>
#include <cmath>
#include <cstdint>
#include <ctime>
#include <Eigen/Core>
#include <expected>
#include <limits>
#include <optional>
#include <tuple>

#include "common/logging/application_log.h"
#include "common/math/lin_interp.h"
#include "scanner/image/camera_model.h"
#include "scanner/image/image.h"
#include "scanner/image/image_types.h"
#include "scanner/joint_model/joint_model.h"
#include "scanner/joint_model/src/slice.h"
#include "scanner/joint_model/src/snake.h"

namespace scanner::joint_model {
// #define VISUAL_DEBUG_OUTPUT 1

namespace {}  // namespace
const double MASK_OFFSET        = 0.002;
const int NUM_TRIANGLES_TO_MASK = 4;
const int START_SNAKE_OFFSET    = 600;

/*
 ____  _       ____              _
| __ )(_) __ _/ ___| _ __   __ _| | _____
|  _ \| |/ _` \___ \| '_ \ / _` | |/ / _ \
| |_) | | (_| |___) | | | | (_| |   <  __/
|____/|_|\__, |____/|_| |_|\__,_|_|\_\___|
         |___/
*/

auto BigSnake::ImageToProfiles(image::Image& image, std::optional<JointProfile> median_profile) -> std::expected<
    std::tuple<image::WorkspaceCoordinates, std::optional<std::array<common::Point, INTERPOLATED_SNAKE_SIZE>>, double,
               int, uint64_t>,
    JointModelErrorCode> {
  auto start = std::clock();

  CropImageHorizontal(image, median_profile);

  auto mask = GenerateMask(image, median_profile);

  auto maybe_snake = Snake::FromImage(image, mask, threshold_);
  if (!maybe_snake) {
    return std::unexpected(JointModelErrorCode::SURFACE_NOT_FOUND);
  }
  const auto& snake = maybe_snake.value();

  // Snake from image to LPCS
  const auto crop_start = image.GetVerticalCropStart();
  auto maybe_snake_lpcs = snake.ToLPCS(camera_model_.get(), crop_start);
  if (!maybe_snake_lpcs) {
    return std::unexpected(JointModelErrorCode::SURFACE_NOT_FOUND);
  }
  auto [snake_lpcs, min, max] = maybe_snake_lpcs.value();

  auto raw_profile = GetRawProfile(snake_lpcs);

  const auto min_pixel_value = static_cast<double>(snake.min_pixel_value);

  auto processing_time = (std::clock() - start) * 1000 / CLOCKS_PER_SEC;

  return std::make_tuple(snake_lpcs, raw_profile, min_pixel_value, crop_start, processing_time);
}

auto BigSnake::ParseProfile(const image::WorkspaceCoordinates& snake_lpcs, double min_pixel_value, int crop_start,
                            std::optional<JointProfile> median_profile, JointProperties properties,
                            bool properties_updated, bool use_approximation,
                            std::optional<std::tuple<double, double>> abw0_abw6_horizontal)
    -> std::expected<std::tuple<JointProfile, uint64_t, uint64_t>, JointModelErrorCode> {
  auto start = std::clock();

  // Snake to slice
  auto maybe_slice = Slice::FromSnake(snake_lpcs, properties, median_profile, found_out_of_spec_joint_width_,
                                      properties_updated, use_approximation, abw0_abw6_horizontal);

  if (!maybe_slice) {
    return std::unexpected(maybe_slice.error());
  }

  auto [points, num_walls, approximation_used] = maybe_slice.value();

  JointProfile profile = {.groove = points, .approximation_used = approximation_used};

  auto maybe_abw_points_in_image_coordinates =
      camera_model_->WorkspaceToImage(ABWPointsToMatrix(profile.groove), crop_start);

  if (maybe_abw_points_in_image_coordinates) {
    auto abw_points_in_image_coordinates = maybe_abw_points_in_image_coordinates.value();
    auto bottom_pixel                    = static_cast<int>(abw_points_in_image_coordinates.row(1).maxCoeff());
    auto top_pixel                       = static_cast<int>(abw_points_in_image_coordinates.row(1).minCoeff());
    profile.vertical_limits              = {top_pixel + crop_start, bottom_pixel + crop_start};
  }

  const auto min_value = static_cast<double>(min_pixel_value);
  const auto threshold = static_cast<double>(threshold_);

  if (min_value < threshold || min_value > 4.0 * threshold) {
    // Below 1.0, set target to 1.2
    profile.suggested_gain_change = {(1.5 * threshold) / min_value};
  }

  auto processing_time = (std::clock() - start) * 1000 / CLOCKS_PER_SEC;
  return std::make_tuple(profile, processing_time, num_walls);
}

auto BigSnake::GenerateMask(image::Image& image, std::optional<JointProfile> median_profile)
    -> std::optional<image::RawImageData> {
  // Is joint deep enough to apply a mask
  if (median_profile.has_value()) {
    auto profile = median_profile.value();
    if (profile.groove.LeftDepth() < HIGH_CONFIDENCE_WALL_HEIGHT ||
        profile.groove.RightDepth() < HIGH_CONFIDENCE_WALL_HEIGHT) {
      return std::nullopt;
    }
  }

  return median_profile.transform(
      [this, image](JointProfile profile) -> Eigen::Matrix<uint8_t, Eigen::Dynamic, Eigen::Dynamic, Eigen::RowMajor> {
        const auto p = profile.groove;

        Eigen::Matrix<uint8_t, Eigen::Dynamic, Eigen::Dynamic, Eigen::RowMajor> mask =
            Eigen::Matrix<uint8_t, Eigen::Dynamic, Eigen::Dynamic, Eigen::RowMajor>::Ones(image.Data().rows(),
                                                                                          image.Data().cols());

        image::WorkspaceCoordinates mask_points_wcs(3, NUM_TRIANGLES_TO_MASK * 3);
        mask_points_wcs <<
            // clang-format off
                p[0].horizontal + MASK_OFFSET, p[1].horizontal, p[6].horizontal - MASK_OFFSET,  // Triangle 1
                p[0].horizontal + MASK_OFFSET, p[5].horizontal, p[6].horizontal - MASK_OFFSET, 
                p[0].horizontal - MASK_OFFSET, p[0].horizontal, p[1].horizontal - MASK_OFFSET, 
                p[6].horizontal + MASK_OFFSET, p[5].horizontal + MASK_OFFSET, p[6].horizontal, 
                p[0].vertical, p[1].vertical + MASK_OFFSET * 2., p[6].vertical,  // Triangle 1
                p[0].vertical, p[5].vertical + MASK_OFFSET * 2., p[6].vertical, 
                p[0].vertical - MASK_OFFSET, p[1].vertical, p[1].vertical, 
                p[6].vertical - MASK_OFFSET, p[5].vertical, p[5].vertical, 
                0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0;
        // clang-format on

        auto maybe_img = camera_model_->WorkspaceToImage(mask_points_wcs, image.GetVerticalCropStart());

        if (maybe_img.has_value()) {
          const auto img   = maybe_img.value();
          const auto x_min = std::clamp(static_cast<long>(img.row(0).minCoeff()), 0l, mask.cols() - 1);
          const auto x_max = std::clamp(static_cast<long>(img.row(0).maxCoeff()), 0l, mask.cols() - 1);
          const auto y_min = std::clamp(static_cast<long>(img.row(1).minCoeff()), 0l, mask.rows() - 1);
          const auto y_max = std::clamp(static_cast<long>(img.row(1).maxCoeff()), 0l, mask.rows() - 1);

          auto sign = [](double p1x, double p1y, double p2x, double p2y, double p3x, double p3y) {
            return (p1x - p3x) * (p2y - p3y) - (p2x - p3x) * (p1y - p3y);
          };

          for (auto y = y_min; y <= y_max; y++) {
            const auto dy = static_cast<double>(y);
            for (auto x = x_min; x <= x_max; x++) {
              for (int triangle_index = 0; triangle_index < NUM_TRIANGLES_TO_MASK; triangle_index++) {
                const auto index_base = triangle_index * 3;
                const auto dx         = static_cast<double>(x);
                const auto v1x        = img(0, index_base);
                const auto v2x        = img(0, index_base + 1);
                const auto v3x        = img(0, index_base + 2);
                const auto v1y        = img(1, index_base);
                const auto v2y        = img(1, index_base + 1);
                const auto v3y        = img(1, index_base + 2);
                auto d1               = sign(dx, dy, v1x, v1y, v2x, v2y);
                auto d2               = sign(dx, dy, v2x, v2y, v3x, v3y);
                auto d3               = sign(dx, dy, v3x, v3y, v1x, v1y);
                if (!(((d1 < 0) || (d2 < 0) || (d3 < 0)) && ((d1 > 0) || (d2 > 0) || (d3 > 0)))) {
                  mask(y, x) = 0;
                }
              }
            }
          }
        }
        return mask;
      });
}

void BigSnake::CropImageHorizontal(image::Image& image, std::optional<JointProfile> median_profile) {
  if (median_profile.has_value()) {
    auto points =
        camera_model_->WorkspaceToImage(ABWPointsToMatrix(median_profile.value().groove), image.GetVerticalCropStart())
            .value();
    auto start = std::max(static_cast<int>(points.row(0)[0] - START_SNAKE_OFFSET), 0);
    auto stop =
        std::min(static_cast<int>(points.row(0)[6] + START_SNAKE_OFFSET), static_cast<int>(image.Data().cols() - 1));
    image.SetHorizontalCrop(start, stop);
  }
}
}  // namespace scanner::joint_model
