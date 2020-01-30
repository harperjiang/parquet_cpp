cmake_minimum_required(VERSION 3.15)
project(parquet_cpp)

set(CMAKE_CXX_STANDARD 14)

if(NOT PARQUET_BUILD_STATIC)
    set(BUILD_STATIC OFF)
else()
    set(BUILD_STATIC ON)
endif()
if(NOT PARQUET_BUILD_SHARED)
    set(BUILD_SHARED OFF)
else()
    set(BUILD_SHARED ON)
endif()

if(NOT PARQUET_BUILD_TESTS)
    set(NO_TESTS 1)
else()
    add_custom_target(all-tests)
    add_custom_target(unittest
            ctest
            -j4
            -L
            unittest
            --output-on-failure)
    add_dependencies(unittest all-tests)
endif()

if(NOT PARQUET_BUILD_BENCHMARKS)
    set(NO_BENCHMARKS 1)
else()
    add_custom_target(all-benchmarks)
    add_custom_target(benchmark ctest -L benchmark)
    add_dependencies(benchmark all-benchmarks)
endif()

find_package(PkgConfig REQUIRED)
include(ExternalProject)

string(TOLOWER ${CMAKE_BUILD_TYPE} LOWERCASE_BUILD_TYPE)
string(TOUPPER ${CMAKE_BUILD_TYPE} UPPERCASE_BUILD_TYPE)


# Thirdparty Libraries
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_CURRENT_SOURCE_DIR}/cmake_modules")

include(ThirdpartyLibraries)
set(THRIFT_SOURCE_URL FROM-APACHE-MIRROR)
set(THRIFT_BUILD_VERSION "0.13.0")
set(THRIFT_BUILD_MD5_CHECKSUM "38a27d391a2b03214b444cb13d5664f1")
build_thrift()

set(ARROW_SOURCE_URL FROM-APACHE-MIRROR)
set(ARROW_BUILD_VERSION "0.15.1")
set(ARROW_BUILD_SHA256_CHECKSUM "9a2c58c72310eafebb4997244cbeeb8c26696320d0ae3eb3e8512f75ef856fc9")
build_arrow()
include_directories(${ARROW_INCLUDE_DIR})

include(BuildUtils)

include_directories(src)
include_directories(${CMAKE_CURRENT_BINARY_DIR}/src)
add_subdirectory(src/parquet)

