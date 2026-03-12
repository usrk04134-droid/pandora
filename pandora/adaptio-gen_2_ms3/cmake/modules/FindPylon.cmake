if (EXISTS "$ENV{Pylon_LIB}")
  set(Pylon_FOUND TRUE)
  set(Pylon_INCLUDE_DIR "$ENV{Pylon_DEV}/include")
  set(PYLON_LIB_DIR "$ENV{Pylon_LIB}/lib")

  # Basic pylon libraries
  set(Pylon_LIBRARIES "pylonbase;pylonutility")

  # Try to find versioned GenApi/GCBase libraries (names vary between pylon versions)
  file(GLOB PYLON_GENAPI_CANDIDATES "${PYLON_LIB_DIR}/libGenApi*.so*")
  file(GLOB PYLON_GCBASE_CANDIDATES "${PYLON_LIB_DIR}/libGCBase*.so*")

  if (PYLON_GENAPI_CANDIDATES)
    list(GET PYLON_GENAPI_CANDIDATES 0 PYLON_GENAPI_PATH)
    list(APPEND Pylon_LIBRARIES ${PYLON_GENAPI_PATH})
  else()
    list(APPEND Pylon_LIBRARIES "GenApi_gcc_v3_1_Basler_pylon")
  endif()

  if (PYLON_GCBASE_CANDIDATES)
    list(GET PYLON_GCBASE_CANDIDATES 0 PYLON_GCBASE_PATH)
    list(APPEND Pylon_LIBRARIES ${PYLON_GCBASE_PATH})
  else()
    list(APPEND Pylon_LIBRARIES "GCBase_gcc_v3_1_Basler_pylon")
  endif()

  set(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)
  link_directories("${PYLON_LIB_DIR}")
else ()
  if (APPLE AND EXISTS /Library/Frameworks/pylon.framework)
    set(Pylon_FOUND TRUE)
    set(Pylon_INCLUDE_DIR /Library/Frameworks/pylon.framework/Headers/GenICam)
    set(Pylon_LIBRARIES "pylonbase;pylonutility;GenApi_gcc_v3_1_Basler_pylon;GCBase_gcc_v3_1_Basler_pylon")

    list(APPEND CMAKE_BUILD_RPATH /Library/Frameworks/pylon.framework/Libraries)
  else ()
    set(Pylon_FOUND FALSE)
  endif ()
endif ()
