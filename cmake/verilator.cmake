find_program(VERILATOR_COMMAND verilator)

# Determine the VERILATOR_INCLUDE_DIR by parsing the generated makefile when
# verilator is run on an empty verilog file.
set(HINT "")
if(VERILATOR_COMMAND AND NOT VERILATOR_INCLUDE_DIR)
  # create a temporary directory
  set(TEST_DIR "${CMAKE_CURRENT_BINARY_DIR}/__find_verilator_include_dir")
  execute_process(COMMAND ${CMAKE_COMMAND} -E  make_directory "${TEST_DIR}")

  # create the empty verilog file and run verilator on it
  file(WRITE "${TEST_DIR}/empty.v" "module empty();\nendmodule\n" )
  execute_process(COMMAND ${VERILATOR_COMMAND} --Mdir verilated -cc empty.v
                  WORKING_DIRECTORY "${TEST_DIR}")

  # read the generated makefile, delete the directory, and search
  # for the VERILATOR_ROOT
  file(READ "${TEST_DIR}/verilated/Vempty.mk" MAKEFILE_CONTENTS)
  execute_process(COMMAND ${CMAKE_COMMAND} -E  remove_directory "${TEST_DIR}")
  string(REGEX MATCH "VERILATOR_ROOT = ([^\n\r]+)" MATCH ${MAKEFILE_CONTENTS})
  if( MATCH )
    set(HINT "${CMAKE_MATCH_1}/include")
  endif()
endif()
find_path (VERILATOR_INCLUDE_DIR NAMES verilated.h
           HINTS "${HINT}"
           PATHS "share/verilator/include")

# determine the verilator version
if(VERILATOR_COMMAND AND NOT VERILATOR_VERSION)
  execute_process(COMMAND ${VERILATOR_COMMAND} --version
                  RESULT_VARIABLE exec_result
                  OUTPUT_VARIABLE exec_output)
  message(STATUS "exec_result: ${exec_result}")
  if(exec_result EQUAL 0)
    string(REGEX REPLACE "^Verilator ([0-9]+\.[0-9]+).*" "\\1" VERILATOR_VERSION "${exec_output}")
    set(VERILATOR_VERSION ${VERILATOR_VERSION} CACHE STRING "Version of the VERILATOR_COMMAND.")
  else()
    info_msg("Verilator version could not be determined.")
  endif()
endif()

mark_as_advanced(VERILATOR_COMMAND VERILATOR_INCLUDE_DIR VERILATOR_VERSION)

#
# verilator_add_library( <name> <top_module> [OPTIONS] SOURCES <verilog_files>...)
#
# Options:
#  COVERAGE ........... Enable coverage support
#  INCLUDES <dirs...>.. Include Paths
#  MODE <sc, cc> ...... Use verilator in SystemC or standard C++ mode (default: cc)
#  OPTS <options...> .. Verilator options (default: -Wall -Wno-fatal -O3)
#  PREFIX <name> ...... Name of the top level include (default: V<top_module>)
#  TRACE .............. Enable trace support
#  VPI ................ Enable VPI support
function(verilator_add_library ARG_LIBRARY_NAME ARG_TOP_MODULE)
  set(options TRACE COVERAGE VPI)
  set(oneValueArgs MODE PREFIX)
  set(multiValueArgs INCLUDES SOURCES)
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN} )

  # set defaults when not specified
  if(NOT ARG_MODE)
    set(ARG_MODE "cc")
  endif()
  if(NOT ARG_PREFIX)
    set(ARG_PREFIX "V${ARG_TOP_MODULE}")
  endif()
  if(NOT ARG_OPTS)
    set(ARG_OPTS -Wall -Wno-fatal -O3)
  endif()

  # use the unparsed arguments as sources too (permits to omit SOURCES in some cases)
  list(APPEND ARG_SOURCES ${ARG_UNPARSED_ARGUMENTS})


  set(VERILATOR_OUTPUT_DIR "_verilator_${ARG_LIBRARY_NAME}")
  set(VERILATOR_CLI_ARGUMENTS --Mdir "${VERILATOR_OUTPUT_DIR}" --prefix "${ARG_PREFIX}" --top-module "${ARG_TOP_MODULE}")

  # append the include directories to the argument list
  foreach(include ${ARG_INCLUDES} )
    get_filename_component(abs_include ${include} ABSOLUTE)
    list(APPEND VERILATOR_CLI_ARGUMENTS "-I${abs_include}")
  endforeach()

  # build a version of the verilator support library specifically for this library
  add_library(verilator_${ARG_LIBRARY_NAME} STATIC EXCLUDE_FROM_ALL "${VERILATOR_INCLUDE_DIR}/verilated.cpp" "${VERILATOR_INCLUDE_DIR}/verilated_dpi.cpp")
  target_include_directories(verilator_${ARG_LIBRARY_NAME} PUBLIC "${VERILATOR_INCLUDE_DIR}" "${VERILATOR_INCLUDE_DIR}/vltstd")
  target_compile_definitions(verilator_${ARG_LIBRARY_NAME} PUBLIC "VM_TRACE=$<BOOL:${ARG_TRACE}>" "VM_COVERAGE=$<BOOL:${ARG_COVERAGE}>")
  if(ARG_TRACE)
    list(APPEND VERILATOR_CLI_ARGUMENTS "--trace")
    if(ARG_MODE STREQUAL "cc")
      target_sources(verilator_${ARG_LIBRARY_NAME} PRIVATE "${VERILATOR_INCLUDE_DIR}/verilated_vcd_c.cpp")
    elseif(ARG_TRACE AND ARG_MODE STREQUAL "sc")
      # TODO ADD dependency on systemc?
      target_sources(verilator_${ARG_LIBRARY_NAME} "${VERILATOR_INCLUDE_DIR}/verilated_vcd_sc.cpp")
    endif()
  endif()
  if(ARG_COVERAGE)
    list(APPEND VERILATOR_CLI_ARGUMENTS "--coverage")
    target_sources(verilator_${ARG_LIBRARY_NAME} PRIVATE "${VERILATOR_INCLUDE_DIR}/verilated_cov.cpp")
  endif()
  if(ARG_VPI)
    list(APPEND VERILATOR_CLI_ARGUMENTS "--vpi")
    target_sources(verilator_${ARG_LIBRARY_NAME} PRIVATE "${VERILATOR_INCLUDE_DIR}/verilated_vpi.cpp")
  endif()

  # forward the global CXX flags to makefile based build system
  set(LANGUAGE_STANDARD "")
  if((CMAKE_COMPILER_IS_GNUCC OR MINGW OR CLANG) AND CMAKE_CXX_STANDARD)
    set(LANGUAGE_STANDARD "-std=c++${CMAKE_CXX_STANDARD}")
  endif()
  string(TOUPPER "${CMAKE_BUILD_TYPE}" UPPER_BUILD_TYPE)
  list(APPEND VERILATOR_CLI_ARGUMENTS -CFLAGS "${CMAKE_CXX_FLAGS_${UPPER_BUILD_TYPE}} ${CMAKE_CXX_FLAGS} ${LANGUAGE_STANDARD}")

  # run verilator to generate the c++ source files (incl. makefile)
  add_custom_command(OUTPUT "${VERILATOR_OUTPUT_DIR}/${ARG_PREFIX}.mk"
                    COMMAND ${VERILATOR_COMMAND} ${ARG_OPTS} ${VERILATOR_CLI_ARGUMENTS} --${ARG_MODE} ${ARG_SOURCES}
                    DEPENDS ${ARG_SOURCES})

  # build the source files using the generate makefile
  # TODO Building this library potentially with other flags than the verilator library and the main application is probably not the best idea...
  #      Think about adding a cmake build here too.
  add_custom_command(OUTPUT "${VERILATOR_OUTPUT_DIR}/${ARG_PREFIX}__ALL${CMAKE_STATIC_LIBRARY_SUFFIX}"
                    COMMAND make -f "${ARG_PREFIX}.mk"
                    DEPENDS "${VERILATOR_OUTPUT_DIR}/${ARG_PREFIX}.mk"
                    WORKING_DIRECTORY ${VERILATOR_OUTPUT_DIR}
                    )
  add_custom_target(verilate_${ARG_LIBRARY_NAME} DEPENDS "${VERILATOR_OUTPUT_DIR}/${ARG_PREFIX}__ALL${CMAKE_STATIC_LIBRARY_SUFFIX}")

  # make sure that the build directory gets cleaned up
  set_property(
    DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    APPEND PROPERTY ADDITIONAL_MAKE_CLEAN_FILES "${VERILATOR_OUTPUT_DIR}"
  )

  # define the actual library with the needed dependencies
  add_library(${ARG_LIBRARY_NAME} INTERFACE)
  target_include_directories(${ARG_LIBRARY_NAME} INTERFACE "$<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/${VERILATOR_OUTPUT_DIR}>")
  target_link_libraries(${ARG_LIBRARY_NAME} INTERFACE verilator_${ARG_LIBRARY_NAME} "${CMAKE_CURRENT_BINARY_DIR}/${VERILATOR_OUTPUT_DIR}/${ARG_PREFIX}__ALL${CMAKE_STATIC_LIBRARY_SUFFIX}")
  add_dependencies(${ARG_LIBRARY_NAME} verilate_${ARG_LIBRARY_NAME})
endfunction()
