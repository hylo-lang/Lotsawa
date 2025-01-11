include_guard(GLOBAL)

#  set_file_glob(<variable>
#       [<globbing-expressions>...])
#
# Generates a list of files (but not directories) that match the
# ``<globbing-expressions>`` and stores it into the ``<variable>``,
# following symlinks.
#
# This command will be re-run at build time; if the result changes, CMake will regenerate
# the build system.
function(set_file_glob variable)
  file(GLOB "${variable}"
    FOLLOW_SYMLINKS
    LIST_DIRECTORIES false
    CONFIGURE_DEPENDS ${ARGN})
  set("${variable}" "${${variable}}" PARENT_SCOPE)
endfunction()

#  set_recursive_file_glob(<variable>
#       [<globbing-expressions>...])
#
# Generates a list of files (but not directories) that match the
# ``<globbing-expressions>`` recursively, per file(GLOB_RECURSE), and
# stores it into the ``<variable>``, following symlinks.
#
# This command will be re-run at build time; if the result changes,
# CMake will regenerate the build system.
function(set_recursive_file_glob variable)
  file(GLOB_RECURSE "${variable}"
    FOLLOW_SYMLINKS
    LIST_DIRECTORIES false
    CONFIGURE_DEPENDS ${ARGN})
  set("${variable}" "${${variable}}" PARENT_SCOPE)
endfunction()

function(add_hylo_executable result_target)
  cmake_parse_arguments("" # <prefix>
    "" # <options>
    "PATH" # <one_value_keywords>
    "DEPENDENCIES" # <multi_value_keywords>
    ${ARGN})
  if(NOT _PATH)
    set(_PATH ${result_target})
  endif()
  set_recursive_file_glob(files ${_PATH}/*.swift)
  add_executable(${result_target} ${files})
  target_depends(${result_target} ${_DEPENDENCIES})
endfunction()

function(add_hylo_library result_target)
  cmake_parse_arguments("" # <prefix>
    "" # <options>
    "PATH" # <one_value_keywords>
    "DEPENDENCIES" # <multi_value_keywords>
    ${ARGN})
  if(NOT _PATH)
    set(_PATH ${result_target})
  endif()
  set_recursive_file_glob(files ${_PATH}/*.swift)
  add_library(${result_target} ${files})
  target_depends(${result_target} ${_DEPENDENCIES})
endfunction()

function(add_hylo_test_of testee)
  cmake_parse_arguments("" # <prefix>
    "" # <options>
    "PATH;NAMED" # <one_value_keywords>
    "DEPENDENCIES" # <multi_value_keywords>
    ${ARGN})

  set(result_target "${_NAMED}")
  if(NOT _PATH)
    set(_PATH ${result_target})
  endif()
  set_recursive_file_glob(files ${_PATH}/*.swift)
  add_swift_xctest(${result_target} ${testee} ${files})
  target_depends(${result_target} ${_DEPENDENCIES})
endfunction()
