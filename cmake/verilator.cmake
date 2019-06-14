#
# Determines all verilator specific vars and caches them.
#
function(_verilator_determine_vars)
  # Skip further processing if all variables are already defined.
  if(VERILATOR_COMMAND AND VERILATOR_ROOT AND VERILATOR_VERSION)
    return()
  endif()

  find_program(VERILATOR_COMMAND verilator REQUIRED)
  if(NOT VERILATOR_COMMAND)
    message(FATAL_ERROR "verilator binary could not be found. Please set the VERILATOR_COMMAND variable as desired!")
  endif()

  # Determine the VERILATOR_ROOT by parsing the generated makefile when
  # verilator is run on an empty verilog file.
  set(HINT "")
  if(NOT VERILATOR_ROOT)
    # Create a temporary directory.
    set(TEST_DIR "${CMAKE_CURRENT_BINARY_DIR}/__find_verilator_root_dir")
    execute_process(COMMAND ${CMAKE_COMMAND} -E make_directory "${TEST_DIR}")

    # Create the empty verilog file and run verilator on it.
    file(WRITE "${TEST_DIR}/empty.v" "module empty();\nendmodule\n" )
    execute_process(COMMAND ${VERILATOR_COMMAND} --Mdir verilated -cc empty.v
                    WORKING_DIRECTORY "${TEST_DIR}")

    # Read the generated makefile, delete the directory, and search
    # for the VERILATOR_ROOT.
    file(READ "${TEST_DIR}/verilated/Vempty.mk" MAKEFILE_CONTENTS)
    execute_process(COMMAND ${CMAKE_COMMAND} -E  remove_directory "${TEST_DIR}")
    string(REGEX MATCH "VERILATOR_ROOT = ([^\n\r]+)" MATCH ${MAKEFILE_CONTENTS})
    if( MATCH )
      set(HINT "${CMAKE_MATCH_1}/include")
    endif()
  endif()
  find_path (VERILATOR_ROOT NAMES "include/verilated.h"
             HINTS "${HINT}"
             PATHS "share/verilator")
  if(NOT VERILATOR_ROOT)
    message(FATAL_ERROR "VERILATOR_ROOT could not be determined. Please set the variable as desired!")
  endif()

  # Determine the verilator version.
  if(NOT VERILATOR_VERSION)
    execute_process(COMMAND ${VERILATOR_COMMAND} --version
                    RESULT_VARIABLE exec_result
                    OUTPUT_VARIABLE exec_output)
    if(exec_result EQUAL 0)
      string(REGEX REPLACE "^Verilator ([0-9]+\.[0-9]+).*" "\\1" VERILATOR_VERSION "${exec_output}")
      set(VERILATOR_VERSION ${VERILATOR_VERSION} CACHE STRING "Version of the VERILATOR_COMMAND.")
    else()
      info_msg("Verilator version could not be determined.")
    endif()
  endif()

  mark_as_advanced(VERILATOR_COMMAND VERILATOR_ROOT VERILATOR_VERSION)
endfunction()

function(write_cache_init_file INIT_FILE)
  set(CM_STATE_INIT "")
  set(variableNames
    CMAKE_AR
    CMAKE_BUILD_TYPE
    CMAKE_CXX_COMPILER CMAKE_CXX_COMPILER_AR CMAKE_CXX_COMPILER_RANLIB
    CMAKE_CXX_EXTENSIONS
    CMAKE_CXX_FLAGS CMAKE_CXX_FLAGS_DEBUG CMAKE_CXX_FLAGS_MINSIZEREL CMAKE_CXX_FLAGS_RELEASE CMAKE_CXX_FLAGS_RELWITHDEBINFO
    CMAKE_CXX_STANDARD
    CMAKE_C_COMPILER CMAKE_C_COMPILER_AR CMAKE_C_COMPILER_RANLIB
    CMAKE_C_EXTENSIONS
    CMAKE_C_FLAGS CMAKE_C_FLAGS_DEBUG CMAKE_C_FLAGS_MINSIZEREL CMAKE_C_FLAGS_RELEASE CMAKE_C_FLAGS_RELWITHDEBINFO
    CMAKE_C_STANDARD
    CMAKE_EXE_LINKER_FLAGS CMAKE_EXE_LINKER_FLAGS_DEBUG CMAKE_EXE_LINKER_FLAGS_MINSIZEREL CMAKE_EXE_LINKER_FLAGS_RELEASE CMAKE_EXE_LINKER_FLAGS_RELWITHDEBINFO
    CMAKE_GENERATOR
    CMAKE_LINKER
    CMAKE_MAKE_PROGRAM
    CMAKE_NM
    CMAKE_OBJCOPY
    CMAKE_OBJDUMP
    CMAKE_RANLIB
    CMAKE_SHARED_LINKER_FLAGS CMAKE_SHARED_LINKER_FLAGS_DEBUG CMAKE_SHARED_LINKER_FLAGS_MINSIZEREL CMAKE_SHARED_LINKER_FLAGS_RELEASE CMAKE_SHARED_LINKER_FLAGS_RELWITHDEBINFO
    CMAKE_STATIC_LINKER_FLAGS CMAKE_STATIC_LINKER_FLAGS_DEBUG CMAKE_STATIC_LINKER_FLAGS_MINSIZEREL CMAKE_STATIC_LINKER_FLAGS_RELEASE CMAKE_STATIC_LINKER_FLAGS_RELWITHDEBINFO
    CMAKE_STRIP
    CMAKE_TOOLCHAIN_FILE
  )
  set(CM_STATE_ADVANCED)
  foreach (variableName IN LISTS variableNames )
    get_property(VALID CACHE "${variableName}" PROPERTY VALUE SET)
    if(NOT VALID)
      if(${variableName})
        string(REPLACE "\"" "\\\"" VALUE "${${variableName}}")
        list(APPEND CM_STATE_INIT "set(${variableName} \"${VALUE}\" CACHE STRING \"\")\n")
      endif()
      continue()
    endif()
    get_property(ADVANCED CACHE "${variableName}" PROPERTY ADVANCED)
    if(ADVANCED)
      list(APPEND CM_STATE_ADVANCED "${variableName}")
    endif()
    get_property(VALUE CACHE "${variableName}" PROPERTY VALUE)
    string(REPLACE "\"" "\\\"" VALUE "${VALUE}")
    get_property(TYPE CACHE "${variableName}" PROPERTY TYPE)
    get_property(HELPSTRING CACHE "${variableName}" PROPERTY HELPSTRING)
    string(REPLACE "\"" "\\\"" HELPSTRING "${HELPSTRING}")
    list(APPEND CM_STATE_INIT "set(${variableName} \"${VALUE}\" CACHE ${TYPE} \"${HELPSTRING}\")\n")
  endforeach()
  list(LENGTH CM_STATE_ADVANCED LENGTH)
  if(LENGTH GREATER 0)
    string(REPLACE ";" " " CM_STATE_ADVANCED "${CM_STATE_ADVANCED}")
    list(APPEND CM_STATE_INIT "mark_as_advanced(${CM_STATE_ADVANCED})\n")
  endif()
  file(WRITE "${INIT_FILE}" ${CM_STATE_INIT})
endfunction()

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

  _verilator_determine_vars()

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
  add_library(verilator_${ARG_LIBRARY_NAME} STATIC EXCLUDE_FROM_ALL "${VERILATOR_ROOT}/include/verilated.cpp" "${VERILATOR_ROOT}/include/verilated_dpi.cpp")
  target_include_directories(verilator_${ARG_LIBRARY_NAME} PUBLIC "${VERILATOR_ROOT}/include" "${VERILATOR_ROOT}/include/vltstd")
  target_compile_definitions(verilator_${ARG_LIBRARY_NAME} PUBLIC "VM_TRACE=$<BOOL:${ARG_TRACE}>" "VM_COVERAGE=$<BOOL:${ARG_COVERAGE}>")
  if(ARG_TRACE)
    list(APPEND VERILATOR_CLI_ARGUMENTS "--trace")
    if(ARG_MODE STREQUAL "cc")
      target_sources(verilator_${ARG_LIBRARY_NAME} PRIVATE "${VERILATOR_ROOT}/include/verilated_vcd_c.cpp")
    elseif(ARG_TRACE AND ARG_MODE STREQUAL "sc")
      # TODO ADD dependency on systemc?
      target_sources(verilator_${ARG_LIBRARY_NAME} "${VERILATOR_ROOT}/include/verilated_vcd_sc.cpp")
    endif()
  endif()
  if(ARG_COVERAGE)
    list(APPEND VERILATOR_CLI_ARGUMENTS "--coverage")
    target_sources(verilator_${ARG_LIBRARY_NAME} PRIVATE "${VERILATOR_ROOT}/include/verilated_cov.cpp")
  endif()
  if(ARG_VPI)
    list(APPEND VERILATOR_CLI_ARGUMENTS "--vpi")
    target_sources(verilator_${ARG_LIBRARY_NAME} PRIVATE "${VERILATOR_ROOT}/include/verilated_vpi.cpp")
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
                    COMMAND "${VERILATOR_COMMAND}" ${ARG_OPTS} ${VERILATOR_CLI_ARGUMENTS} "--${ARG_MODE}" ${ARG_SOURCES}
                    DEPENDS ${ARG_SOURCES})

  set(CM_TEMPLATE_FILE "${PROJECT_SOURCE_DIR}/cmake/templates/verilator_CMakeLists.txt")
  add_custom_command(OUTPUT "${VERILATOR_OUTPUT_DIR}/CMakeLists.txt"
                    COMMAND "${CMAKE_COMMAND}" -E copy "${CM_TEMPLATE_FILE}" CMakeLists.txt
                    DEPENDS "${CM_TEMPLATE_FILE}" "${VERILATOR_OUTPUT_DIR}/${ARG_PREFIX}.mk"
                    WORKING_DIRECTORY "${VERILATOR_OUTPUT_DIR}")

  # Dump the most important cmake cache state into an state initialization file.
  set(INIT_FILE "${CMAKE_CURRENT_BINARY_DIR}/${ARG_LIBRARY_NAME}_state_init.cmake")
  write_cache_init_file("${INIT_FILE}")

  # Build the verilated model (either with CMake or with the generated Makefile).
  add_custom_command(OUTPUT "${VERILATOR_OUTPUT_DIR}/lib${ARG_TOP_MODULE}__ALL${CMAKE_STATIC_LIBRARY_SUFFIX}"
                    COMMAND ${CMAKE_COMMAND} . "-C${INIT_FILE}"
                                               "-DVERILATOR_LIBNAME=${ARG_TOP_MODULE}__ALL"
                                               "-DVERILATOR_ROOT=${VERILATOR_ROOT}"
                                               "-DVERILATOR_TRACE=${ARG_TRACE}"
                                               "-DVERILATOR_COVERAGE=${ARG_COVERAGE}"
                                               "-DVERILATOR_MODE=${ARG_MODE}"
                    COMMAND ${CMAKE_COMMAND} --build .
                    # COMMAND make -f "${ARG_PREFIX}.mk" "lib${ARG_TOP_MODULE}__ALL.a" "VERILATOR_ROOT=${VERILATOR_ROOT}" "VM_PREFIX=lib${ARG_TOP_MODULE}"
                    DEPENDS "${VERILATOR_OUTPUT_DIR}/CMakeLists.txt" "${VERILATOR_OUTPUT_DIR}/${ARG_PREFIX}.mk"
                    WORKING_DIRECTORY "${VERILATOR_OUTPUT_DIR}"
                    )
  add_custom_target(verilate_${ARG_LIBRARY_NAME} DEPENDS "${VERILATOR_OUTPUT_DIR}/lib${ARG_TOP_MODULE}__ALL${CMAKE_STATIC_LIBRARY_SUFFIX}")

  # make sure that the build directory gets cleaned up
  set(CLEAN_PROPERTY "ADDITIONAL_MAKE_CLEAN_FILES")
  if(CMAKE_VERSION VERSION_GREATER 3.15.0 OR CMAKE_VERSION VERSION_EQUAL 3.15.0)
    set(CLEAN_PROPERTY "ADDITIONAL_CLEAN_FILES")
  endif()
  set_property(
    DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    APPEND PROPERTY "${CLEAN_PROPERTY}" "${VERILATOR_OUTPUT_DIR}"
  )

  # define the actual library with the needed dependencies
  add_library(${ARG_LIBRARY_NAME} INTERFACE)
  target_include_directories(${ARG_LIBRARY_NAME} INTERFACE "$<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/${VERILATOR_OUTPUT_DIR}>")
  target_link_libraries(${ARG_LIBRARY_NAME} INTERFACE verilator_${ARG_LIBRARY_NAME} "${CMAKE_CURRENT_BINARY_DIR}/${VERILATOR_OUTPUT_DIR}/lib${ARG_TOP_MODULE}__ALL${CMAKE_STATIC_LIBRARY_SUFFIX}")
  add_dependencies(${ARG_LIBRARY_NAME} verilate_${ARG_LIBRARY_NAME})
endfunction()
