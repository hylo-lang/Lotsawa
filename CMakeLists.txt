cmake_minimum_required(VERSION 3.30)

cmake_policy(SET CMP0157 NEW)

project(LotswaC
  VERSION 0.1.0
  DESCRIPTION "Lotsawa C API"
  HOMEPAGE_URL "https://github.com/hylo-lang/Lotsawa"
  LANGUAGES C Swift
)
enable_testing()
include(CTest)

set(CMAKE_Swift_COMPILATION_MODE
  "$<IF:$<CONFIG:Release>,wholemodule,incremental>")

set(CMAKE_OSX_DEPLOYMENT_TARGET "13.0")

list(PREPEND CMAKE_MODULE_PATH ${PROJECT_SOURCE_DIR}/cmake/modules)
set(CMAKE_Swift_LANGUAGE_VERSION 6)

set(CMAKE_POSITION_INDEPENDENT_CODE ${BUILD_SHARED_LIBS}) # Needed?
set(CMAKE_Swift_COMPILE_OPTIONS
  -warnings-as-errors "$<IF:$<CONFIG:Release>,-O,-Onone>")
if(BUILD_TESTING)
  list(APPEND CMAKE_Swift_COMPILE_OPTIONS -enable-testing)
endif()

if(BUILD_TESTING)
  # We need to work something out, probably a DYLD_LIBRARY_PATH
  # setting, before shared libs can be tested.
  set(BUILD_SHARED_LIBS NO CACHE BOOL "Build shared libraries by default" FORCE)
endif()

if (PROJECT_IS_TOP_LEVEL)
  include(cmake/TopLevelDefaults.cmake)
endif()

add_subdirectory(Sources)

if(BUILD_TESTING)
  add_subdirectory(Tests)
endif()
