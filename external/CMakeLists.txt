add_library(cxxopts INTERFACE)
target_include_directories(cxxopts INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/cxxopts/include")

add_library(elfio INTERFACE)
target_include_directories(elfio INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/elfio")

add_subdirectory(fmt)

find_package(Threads)
add_library(spdlog INTERFACE)
target_include_directories(spdlog INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/spdlog/include")
target_compile_definitions(spdlog INTERFACE SPDLOG_FMT_EXTERNAL)
target_link_libraries(spdlog INTERFACE ${CMAKE_THREAD_LIBS_INIT})
