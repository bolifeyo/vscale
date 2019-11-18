cmake_minimum_required(VERSION 3.10.0)

project(vscale)
set(VERSION_MAJOR "0")
set(VERSION_MINOR "1")
set(VERSION_PATCH "0")

set(CMAKE_CXX_STANDARD   14)
set(CMAKE_CXX_EXTENSIONS OFF)

set(DEFAULT_BUILD_TYPE Debug)

set(CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake" ${CMAKE_MODULE_PATH})

include(forceOutOfSourceBuild)       # prohibit in-source builds
include(setDefaultSettings)          # processes and applies the DEFAULT variables
include(messages)                    # helper functions for messages
include(versionSupport)              # build up version strings
include(testing)                     # enables ctest and generates suite and check
include(clangformat)                 # adds clang-format as format target

find_package(verilator REQUIRED HINTS $ENV{VERILATOR_ROOT})

add_subdirectory(external)

configure_file("src/test/cxx/config.h.in" "config.h" @ONLY)
file(GLOB_RECURSE CPP_SOURCES "src/test/cxx/*.cpp")
add_executable(vscale ${CPP_SOURCES})
target_include_directories(vscale PRIVATE "${CMAKE_CURRENT_BINARY_DIR}")
target_link_libraries(vscale PRIVATE cxxopts elfio fmt spdlog)

# define verilog source files, the top module, and add them to the executable
file(GLOB_RECURSE VERILOG_SOURCES "src/*.v" "src/*.vh")
list(REMOVE_ITEM VERILOG_SOURCES "${PROJECT_SOURCE_DIR}/src/test/verilog/vscale_hex_tb.v")
verilate(vscale TRACE
         TOP_MODULE vscale_sim_top
         PREFIX Vvscale_sim_top
         SOURCES ${VERILOG_SOURCES}
         INCLUDE_DIRS "src/main/verilog"
         VERILATOR_ARGS -Wno-fatal
)

# register c++ files for reformatting
file(GLOB H_SOURCES "src/test/cxx/*.h")
add_file_to_format(${CPP_SOURCES} ${H_SOURCES})

# register all hex files for automatic testing
add_to_suite( vscale )
set(MAX_CYCLES 10000 CACHE STRING "Maximum number of cycles for one test case.")
file(GLOB HEX_SOURCES "src/test/inputs/*.hex")
foreach(testfile ${HEX_SOURCES} )
  get_filename_component(name "${testfile}" NAME_WE)
  add_test(NAME "${name}" COMMAND vscale --loadmem ${testfile} --max-cycles=${MAX_CYCLES})
endforeach()

#------------------------------------------------------------------------------
# Print help dialog (assuming make based build system)
#------------------------------------------------------------------------------
help_msg("---------------------------------------------------------------------")
help_msg("Configuration for ${CMAKE_PROJECT_NAME} ${VERSION_FULL} done.")
help_msg("INSTALL PREFIX:    ${CMAKE_INSTALL_PREFIX}")
help_msg("BUILD TYPE:        ${CMAKE_BUILD_TYPE}")
help_msg("")
help_msg("Available targets:")
help_target(check          "Build vscale and execute the tests.")
help_target(format         "Format the source files using clang-format.")
help_msg("---------------------------------------------------------------------")
