add_subdirectory(test)

target_sources(${ADAPTIO_APPLICATION}
    PRIVATE
    image_provider.h
    image_provider_configuration.h
    src/camera_simulation.h
    src/buffered_channel.h
    src/camera_link.h
    src/camera_link.cc

    src/camera_simulation.cc
)

if(ENABLE_PYLON)
  target_sources(${ADAPTIO_APPLICATION}
      PRIVATE
      src/basler_camera.h
      ../../../build/basler_camera_with_pfs.cc
  )
endif()
