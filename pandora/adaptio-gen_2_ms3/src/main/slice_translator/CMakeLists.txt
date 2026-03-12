target_sources(${ADAPTIO_APPLICATION}
    PRIVATE
    slice_translator_service_v2.h
    optimizable_model.h
    model_activator.h
    rotary_model_config.h
    linear_model_config.h
    translation-model.h
    slice_observer.h

    src/coordinates_translator.h
    src/linear_model_impl.h
    src/rotary_model_impl.h
    src/slice_translator_service_impl.h

    src/coordinates_translator.cc
    src/linear_model_impl.cc
    src/rotary_model_impl.cc
    src/slice_translator_service_impl.cc
)
