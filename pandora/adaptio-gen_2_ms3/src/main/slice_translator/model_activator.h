#pragma once

#include "slice_translator/translation-model.h"
namespace slice_translator {

class ModelActivator {
 public:
  virtual ~ModelActivator()                                   = default;
  virtual void SetActiveModel(TranslationModel* active_model) = 0;
};

}  // namespace slice_translator
