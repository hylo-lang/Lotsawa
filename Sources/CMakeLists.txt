include(HyloUtilities)

add_hylo_library(Lotsawa
)

add_hylo_library(LotsawaC
  DEPENDENCIES Lotsawa
)

target_compile_options(
  LotsawaC PRIVATE
  -import-objc-header ${CMAKE_CURRENT_SOURCE_DIR}/LotsawaC/include/LotsawaC.h)
