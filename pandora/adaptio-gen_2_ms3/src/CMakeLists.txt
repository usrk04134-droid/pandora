set(ADAPTIO_APPLICATION adaptio)

# Uncomment line below to build a debug Adaptio using PN Driver debug lib
#set(ADAPTIO_DEBUG_MODE "On")

add_executable(${ADAPTIO_APPLICATION} main.cc)
if (CMAKE_BUILD_TYPE STREQUAL "Debug")
  target_compile_options(${ADAPTIO_APPLICATION} PRIVATE -Wall -Werror -pedantic -gdwarf-4 -fsanitize=address,undefined)
  if (ADAPTIO_DEBUG_MODE STREQUAL "On")
    target_compile_options(${ADAPTIO_APPLICATION} PRIVATE -Wall -O0 -pedantic -gdwarf-4
          -ferror-limit=0)
  else ()
      target_compile_options(${ADAPTIO_APPLICATION} PRIVATE -Wall -Werror -pedantic -gdwarf-4
            -ferror-limit=0)
  endif ()
  target_link_options(${ADAPTIO_APPLICATION} PRIVATE -v -fsanitize=address,undefined)
  target_link_options(${ADAPTIO_APPLICATION} PRIVATE -v -rdynamic)
else ()
  #Override CMake's default Release -O3 with -O2 to reduce optimization, preserving more debuggable stack traces and visibility in coredumps.
  target_compile_options(${ADAPTIO_APPLICATION} PRIVATE -Wall -Werror -pedantic -gdwarf-4 -O2)
  target_link_options(${ADAPTIO_APPLICATION} PRIVATE -v -rdynamic)
endif ()
target_compile_features(${ADAPTIO_APPLICATION} PRIVATE cxx_std_23)
add_compile_definitions(BUILD_TYPE="${CMAKE_BUILD_TYPE}")

target_sources(${ADAPTIO_APPLICATION}
        PRIVATE
        version.h
)

set(UNIT_TESTS_APPLICATION adaptio-unit-tests)
add_executable(${UNIT_TESTS_APPLICATION} test_utils/unit_tests.cc)
target_compile_options(${UNIT_TESTS_APPLICATION} PRIVATE -Wall -Werror -pedantic -gdwarf-4
        -ferror-limit=0 -fsanitize=address,undefined)
target_link_options(${UNIT_TESTS_APPLICATION} PRIVATE -v -fsanitize=address,undefined)
target_compile_features(${UNIT_TESTS_APPLICATION} PRIVATE cxx_std_23)

set(BLOCK_TESTS_APPLICATION adaptio-block-tests)
add_executable(${BLOCK_TESTS_APPLICATION} test_utils/block_tests.cc)
target_compile_options(${BLOCK_TESTS_APPLICATION} PRIVATE -Wall -Werror -pedantic -gdwarf-4
        -ferror-limit=0 -fsanitize=address,undefined)
target_link_options(${BLOCK_TESTS_APPLICATION} PRIVATE -v -fsanitize=address,undefined)
target_compile_features(${BLOCK_TESTS_APPLICATION} PRIVATE cxx_std_23)

set(TEST_IMAGES_APPLICATION test-images)
add_executable(${TEST_IMAGES_APPLICATION} scanner/tools/test_image_set.cc)
target_compile_options(${TEST_IMAGES_APPLICATION} PRIVATE -Wall -Werror -pedantic -gdwarf-4
        -ferror-limit=0)
target_link_options(${TEST_IMAGES_APPLICATION} PRIVATE -v)
target_compile_features(${TEST_IMAGES_APPLICATION} PRIVATE cxx_std_23)

# Shared object library for unit and block test executables.
# Both have identical compile flags, so production sources are compiled once
# and the resulting object files are linked into both test binaries.
# The target is created here (before add_subdirectory) so subdirectories can
# add include directories to it. Sources are added below after collection.
set(TEST_OBJECTS adaptio-test-objects)
add_library(${TEST_OBJECTS} OBJECT)
target_compile_options(${TEST_OBJECTS} PRIVATE -Wall -Werror -pedantic -gdwarf-4
        -ferror-limit=0 -fsanitize=address,undefined)
target_compile_features(${TEST_OBJECTS} PRIVATE cxx_std_23)
target_include_directories(${TEST_OBJECTS} PRIVATE ${CMAKE_BINARY_DIR}/generated/)

# On x86_64-linux both default ON; on aarch64 -DENABLE_PNDRIVER=OFF / -DENABLE_PYLON=OFF
# is passed via flake.nix cmakeFlags and takes precedence over these defaults.
option(ENABLE_PNDRIVER "Build with PROFINET driver" ON)
option(ENABLE_PYLON "Build with Basler Pylon camera SDK" ON)

add_subdirectory(benchmarks)
add_subdirectory(block_tests)
add_subdirectory(common)
add_subdirectory(configuration)
add_subdirectory(controller)
add_subdirectory(main)
add_subdirectory(scanner)
add_subdirectory(test_utils)

get_target_property(ADAPTIO_APPLICATION_SOURCES ${ADAPTIO_APPLICATION} SOURCES)
string(REPLACE "main.cc" "" ADAPTIO_APPLICATION_SOURCES "${ADAPTIO_APPLICATION_SOURCES}")
string(REPLACE "controller_factory.cc" "" ADAPTIO_APPLICATION_SOURCES "${ADAPTIO_APPLICATION_SOURCES}")
# pn_driver sources are not needed in tests.
# Excluding them also avoids pulling in the generated pn_driver_data.h as a test dependency.
list(FILTER ADAPTIO_APPLICATION_SOURCES EXCLUDE REGEX ".*/pn_driver/.*")

target_sources(${TEST_OBJECTS} PRIVATE "${ADAPTIO_APPLICATION_SOURCES}")

target_link_libraries(${UNIT_TESTS_APPLICATION} PRIVATE ${TEST_OBJECTS})
target_link_libraries(${BLOCK_TESTS_APPLICATION} PRIVATE ${TEST_OBJECTS})

target_sources(${TEST_IMAGES_APPLICATION} PRIVATE "${ADAPTIO_APPLICATION_SOURCES}")
target_include_directories(${TEST_IMAGES_APPLICATION} PRIVATE ${CMAKE_BINARY_DIR}/generated/)

if(ENABLE_PNDRIVER)
  find_package(PnDriver REQUIRED)
  target_include_directories(${ADAPTIO_APPLICATION} PRIVATE ${PnDriver_INCLUDE_DIR})
  target_include_directories(${TEST_IMAGES_APPLICATION} PRIVATE ${PnDriver_INCLUDE_DIR})
  target_link_libraries(${ADAPTIO_APPLICATION} PRIVATE ${PnDriver_LIBRARIES})
  target_link_libraries(${TEST_IMAGES_APPLICATION} PRIVATE ${PnDriver_LIBRARIES})
  target_compile_definitions(${ADAPTIO_APPLICATION} PRIVATE ENABLE_PNDRIVER)
  target_compile_definitions(${TEST_IMAGES_APPLICATION} PRIVATE ENABLE_PNDRIVER)
endif()

find_package(Eigen3 REQUIRED)
target_link_libraries(${ADAPTIO_APPLICATION} PRIVATE Eigen3::Eigen)
target_link_libraries(${TEST_OBJECTS} PUBLIC Eigen3::Eigen)
target_link_libraries(${TEST_IMAGES_APPLICATION} PRIVATE Eigen3::Eigen)

set(ADAPTIO_PCH
    <Eigen/Core>
    <Eigen/Geometry>
    <memory>
    <vector>
    <string>
    <optional>
    <functional>
)
target_precompile_headers(${TEST_OBJECTS} PRIVATE ${ADAPTIO_PCH})
target_precompile_headers(${ADAPTIO_APPLICATION} PRIVATE ${ADAPTIO_PCH})
target_precompile_headers(${TEST_IMAGES_APPLICATION} PRIVATE ${ADAPTIO_PCH})

# Extended PCH for test executables — adds heavy test-only headers on top of the base set.
# Uses its own PCH (not REUSE_FROM) so test-only headers don't pollute production targets.
# doctest/doctest.h is 7000 lines parsed by 75 test TUs; nlohmann/json.hpp by many more.
set(TEST_EXEC_PCH
    ${ADAPTIO_PCH}
    <doctest/doctest.h>
    <nlohmann/json.hpp>
    <fmt/format.h>
)
target_precompile_headers(${UNIT_TESTS_APPLICATION} PRIVATE ${TEST_EXEC_PCH})
target_precompile_headers(${BLOCK_TESTS_APPLICATION} PRIVATE ${TEST_EXEC_PCH})

# unit_tests.cc and block_tests.cc define DOCTEST_CONFIG_IMPLEMENT before including
# doctest/doctest.h to register the test runner's main(). If the PCH provides doctest
# without that macro, #pragma once would suppress the re-include and main() would not be
# generated, causing a link error. Exclude them from PCH.
set_source_files_properties(
    test_utils/unit_tests.cc
    test_utils/block_tests.cc
    PROPERTIES SKIP_PRECOMPILE_HEADERS ON
)

# pnd_trace_util.c is a C source — skip PCH since Eigen/Core and STL headers are C++ only
if(ENABLE_PNDRIVER)
  set_source_files_properties(
      controller/pn_driver/shared_src/pnd_trace_util.c
      PROPERTIES SKIP_PRECOMPILE_HEADERS ON
  )
endif()

find_package(Boost 1.81 COMPONENTS program_options log REQUIRED)
target_link_libraries(${ADAPTIO_APPLICATION} PRIVATE ${Boost_LIBRARIES})
target_link_libraries(${TEST_OBJECTS} PUBLIC ${Boost_LIBRARIES})
target_link_libraries(${TEST_IMAGES_APPLICATION} PRIVATE ${Boost_LIBRARIES})

find_package(cppzmq REQUIRED)
target_link_libraries(${ADAPTIO_APPLICATION} PRIVATE cppzmq)
target_link_libraries(${TEST_OBJECTS} PUBLIC cppzmq)
target_link_libraries(${TEST_IMAGES_APPLICATION} PRIVATE cppzmq)

find_package(OpenSSL REQUIRED)
target_link_libraries(${ADAPTIO_APPLICATION} PRIVATE ssl crypto)
target_link_libraries(${TEST_OBJECTS} PUBLIC ssl crypto)
target_link_libraries(${TEST_IMAGES_APPLICATION} PRIVATE ssl crypto)

find_package(fmt REQUIRED)
target_link_libraries(${ADAPTIO_APPLICATION} PRIVATE fmt::fmt)
target_link_libraries(${TEST_OBJECTS} PUBLIC fmt::fmt)
target_link_libraries(${TEST_IMAGES_APPLICATION} PRIVATE fmt::fmt)

find_package(prometheus-cpp REQUIRED)
target_link_libraries(${ADAPTIO_APPLICATION} PRIVATE prometheus-cpp::pull)
target_link_libraries(${TEST_OBJECTS} PUBLIC prometheus-cpp::pull)
target_link_libraries(${TEST_IMAGES_APPLICATION} PRIVATE prometheus-cpp::pull)

find_package(yaml-cpp 0.7.0 REQUIRED)
target_link_libraries(${ADAPTIO_APPLICATION} PRIVATE yaml-cpp)
target_link_libraries(${TEST_OBJECTS} PUBLIC yaml-cpp)
target_link_libraries(${TEST_IMAGES_APPLICATION} PRIVATE yaml-cpp)

find_package(SQLiteCpp REQUIRED)
target_link_libraries(${ADAPTIO_APPLICATION} PRIVATE SQLiteCpp)
target_link_libraries(${TEST_OBJECTS} PUBLIC SQLiteCpp)
target_link_libraries(${TEST_IMAGES_APPLICATION} PRIVATE SQLiteCpp)

find_package(TIFF REQUIRED)
target_link_libraries(${ADAPTIO_APPLICATION} PRIVATE TIFF::TIFF)
target_link_libraries(${TEST_OBJECTS} PUBLIC TIFF::TIFF)
target_link_libraries(${TEST_IMAGES_APPLICATION} PRIVATE TIFF::TIFF)

find_package(doctest REQUIRED)
target_include_directories(${UNIT_TESTS_APPLICATION} PUBLIC ${DOCTEST_INCLUDE_DIR})
target_link_libraries(${UNIT_TESTS_APPLICATION} PRIVATE doctest::doctest)
target_include_directories(${BLOCK_TESTS_APPLICATION} PUBLIC ${DOCTEST_INCLUDE_DIR})
target_link_libraries(${BLOCK_TESTS_APPLICATION} PRIVATE doctest::doctest)
target_include_directories(${TEST_IMAGES_APPLICATION} PUBLIC ${DOCTEST_INCLUDE_DIR})
target_link_libraries(${TEST_IMAGES_APPLICATION} PRIVATE doctest::doctest)

find_package(trompeloeil REQUIRED)
target_link_libraries(${UNIT_TESTS_APPLICATION} PRIVATE trompeloeil::trompeloeil)
target_link_libraries(${BLOCK_TESTS_APPLICATION} PRIVATE trompeloeil::trompeloeil)
target_link_libraries(${TEST_OBJECTS} PUBLIC depsim)
target_include_directories(${TEST_OBJECTS} PUBLIC common/deposition_simulator)
target_link_libraries(${ADAPTIO_APPLICATION} PRIVATE depsim)
target_include_directories(${ADAPTIO_APPLICATION} PUBLIC common/deposition_simulator)
target_link_libraries(${TEST_IMAGES_APPLICATION} PRIVATE depsim)
target_include_directories(${TEST_IMAGES_APPLICATION} PUBLIC common/deposition_simulator)

if(ENABLE_PYLON)
  find_package(Pylon REQUIRED)
  target_include_directories(${ADAPTIO_APPLICATION} SYSTEM PRIVATE ${Pylon_INCLUDE_DIR})
  target_include_directories(${TEST_OBJECTS} SYSTEM PRIVATE ${Pylon_INCLUDE_DIR})
  target_include_directories(${TEST_IMAGES_APPLICATION} SYSTEM PRIVATE ${Pylon_INCLUDE_DIR})
  target_link_libraries(${TEST_IMAGES_APPLICATION} PRIVATE ${Pylon_LIBRARIES})
  target_link_libraries(${ADAPTIO_APPLICATION} PRIVATE ${Pylon_LIBRARIES})
  target_link_libraries(${TEST_OBJECTS} PUBLIC ${Pylon_LIBRARIES})
  target_compile_definitions(${ADAPTIO_APPLICATION} PRIVATE ENABLE_PYLON)
  target_compile_definitions(${TEST_OBJECTS} PRIVATE ENABLE_PYLON)
  target_compile_definitions(${TEST_IMAGES_APPLICATION} PRIVATE ENABLE_PYLON)
endif()

find_package(OpenCV 4.7 REQUIRED)
target_link_libraries(${ADAPTIO_APPLICATION} PRIVATE ${OpenCV_LIBRARIES})
target_link_libraries(${TEST_OBJECTS} PUBLIC ${OpenCV_LIBRARIES})
target_link_libraries(${TEST_IMAGES_APPLICATION} PRIVATE ${OpenCV_LIBRARIES})
add_definitions(${OPENCV_DEFINITIONS})

find_package(Ceres REQUIRED)
target_link_libraries(${ADAPTIO_APPLICATION} PRIVATE Ceres::ceres)
target_link_libraries(${TEST_OBJECTS} PUBLIC Ceres::ceres)
target_link_libraries(${TEST_IMAGES_APPLICATION} PRIVATE Ceres::ceres)

find_package(PCL 1.13 COMPONENTS sample_consensus REQUIRED)
target_link_libraries(${ADAPTIO_APPLICATION} PRIVATE ${PCL_LIBRARIES})
target_link_libraries(${TEST_OBJECTS} PUBLIC ${PCL_LIBRARIES})
target_link_libraries(${TEST_IMAGES_APPLICATION} PRIVATE ${PCL_LIBRARIES})
add_definitions(${PCL_DEFINITIONS})

file(READ ${CMAKE_CURRENT_SOURCE_DIR}/../assets/basler/a2A4096-9gmPRO_40297732.pfs PFS_FILE_CONTENT)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/scanner/image_provider/src/basler_camera.cc ${CMAKE_CURRENT_SOURCE_DIR}/../build/basler_camera_with_pfs.cc)

configure_file(${PROJECT_SOURCE_DIR}/src/version.h.in ${PROJECT_BINARY_DIR}/src/version.h)

install(TARGETS ${ADAPTIO_APPLICATION} DESTINATION bin)
install(DIRECTORY ${CMAKE_BINARY_DIR}/generated/assets/ DESTINATION assets)
install(DIRECTORY ../assets/configuration DESTINATION assets)
install(DIRECTORY ../assets/events DESTINATION assets)
install(DIRECTORY ../assets/scanner_calibration DESTINATION assets)
