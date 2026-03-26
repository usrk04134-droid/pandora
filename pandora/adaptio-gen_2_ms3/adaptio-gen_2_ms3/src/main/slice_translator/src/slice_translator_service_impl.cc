
#include "slice_translator/src/slice_translator_service_impl.h"

#include <optional>
#include <vector>

#include "common/groove/point.h"
#include "lpcs/lpcs_point.h"
#include "slice_translator/translation-model.h"
namespace slice_translator {

// SliceTranslatorServiceImpl
auto SliceTranslatorServiceImpl::LPCSToMCS(const std::vector<lpcs::Point>& lpcs_points,
                                           const common::Point& slide_position) const
    -> std::optional<std::vector<common::Point>> {
  if (active_model_ == nullptr) {
    return std::nullopt;
  }
  return active_model_->LPCSToMCS(lpcs_points, slide_position);
}

auto SliceTranslatorServiceImpl::MCSToLPCS(const std::vector<common::Point>& macs_points,
                                           const common::Point& slide_position) const
    -> std::optional<std::vector<lpcs::Point>> {
  if (active_model_ == nullptr) {
    return std::nullopt;
  }
  return active_model_->MCSToLPCS(macs_points, slide_position);
}

auto SliceTranslatorServiceImpl::DistanceFromTorchToScanner(const std::vector<lpcs::Point>& lpcs_points,
                                                            const common::Point& axis_position) const
    -> std::optional<double> {
  if (active_model_ == nullptr) {
    return std::nullopt;
  }
  return active_model_->DistanceFromTorchToScanner(lpcs_points, axis_position);
}

auto SliceTranslatorServiceImpl::Available() const -> bool {
  if (active_model_ == nullptr) {
    return false;
  }
  return active_model_->Available();
}

// Model activator
void SliceTranslatorServiceImpl::SetActiveModel(TranslationModel* active_model) { active_model_ = active_model; }

}  // namespace slice_translator
