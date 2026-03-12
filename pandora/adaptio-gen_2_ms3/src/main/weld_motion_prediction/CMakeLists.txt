add_subdirectory(test)

target_sources(${ADAPTIO_APPLICATION}
  PRIVATE
  #Interfaces
  trajectory.h 
  configurable_linear_trajectory.h 
  configurable_circle_trajectory.h 
  configurable_transform.h 
  weld_motion_context.h 
  transformer.h

  #Implementations
  src/linear_trajectory.h 
  src/linear_trajectory.cc
  src/circle_trajectory.h
  src/circle_trajectory.cc 
  src/weld_motion_context_impl.h 
  src/weld_motion_context_impl.cc 
  src/lpcs_to_macs_transformer.h 
  src/lpcs_to_macs_transformer.cc
)
