cmake_minimum_required (VERSION 3.0)

project (cmake-resource-compiler VERSION 1.0 LANGUAGES CXX ASM)

set (CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

add_subdirectory (tests)
add_subdirectory (examples)

