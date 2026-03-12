#pragma once

#include "slice_translator/model_activator.h"
#include "slice_translator/slice_translator_service_v2.h"
#include "slice_translator/translation-model.h"

namespace slice_translator {

class SliceTranslatorServiceImpl : public SliceTranslatorServiceV2, public ModelActivator {
 public:
  SliceTranslatorServiceImpl() = default;
  // SliceTranslatorServiceImpl
  auto LPCSToMCS(const std::vector<lpcs::Point>& lpcs_points, const common::Point& slide_position) const
      -> std::optional<std::vector<common::Point>> override;
  auto MCSToLPCS(const std::vector<common::Point>& macs_points, const common::Point& slide_position) const
      -> std::optional<std::vector<lpcs::Point>> override;
  auto DistanceFromTorchToScanner(const std::vector<lpcs::Point>& lpcs_points, const common::Point& axis_position) const
      -> std::optional<double> override;
  auto Available() const -> bool override;

  // Model activator
  void SetActiveModel(TranslationModel* active_model) override;

 private:
  TranslationModel* active_model_{};
};

}  // namespace slice_translator
