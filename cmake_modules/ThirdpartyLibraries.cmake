
set(APACHE_MIRROR "")

macro(get_apache_mirror)
    if(APACHE_MIRROR STREQUAL "")
        set(APACHE_MIRROR_INFO_URL "https://www.apache.org/dyn/closer.cgi?as_json=1")
        set(APACHE_MIRROR_INFO_PATH "${CMAKE_CURRENT_BINARY_DIR}/apache-mirror.json")
        if(EXISTS "${APACHE_MIRROR_INFO_PATH}")
            set(APACHE_MIRROR_DOWNLOAD_STATUS 0)
        else()
            file(DOWNLOAD "${APACHE_MIRROR_INFO_URL}" "${APACHE_MIRROR_INFO_PATH}"
                    STATUS APACHE_MIRROR_DOWNLOAD_STATUS)
        endif()
        if(APACHE_MIRROR_DOWNLOAD_STATUS EQUAL 0)
            file(READ "${APACHE_MIRROR_INFO_PATH}" APACHE_MIRROR_INFO)
            string(REGEX MATCH "\"preferred\": \"[^\"]+" APACHE_MIRROR_PREFERRED
                    "${APACHE_MIRROR_INFO}")
            string(REGEX
                    REPLACE "\"preferred\": \"" "" APACHE_MIRROR "${APACHE_MIRROR_PREFERRED}")
        else()
            file(REMOVE "${APACHE_MIRROR_INFO_PATH}")
            message(
                    WARNING
                    "Failed to download Apache mirror information: ${APACHE_MIRROR_INFO_URL}: ${APACHE_MIRROR_DOWNLOAD_STATUS}"
            )
        endif()
    endif()
    if(APACHE_MIRROR STREQUAL "")
        # Well-known mirror, in case the URL above fails loading
        set(APACHE_MIRROR "https://apache.osuosl.org/")
    endif()
    message(STATUS "Apache mirror: ${APACHE_MIRROR}")
endmacro()


macro(build_thrift)
    message("Building Apache Thrift from source")
    set(THRIFT_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/thrift_ep/src/thrift_ep-install")
    set(THRIFT_INCLUDE_DIR "${THRIFT_PREFIX}/include")
    set(THRIFT_COMPILER "${THRIFT_PREFIX}/bin/thrift")
    set(THRIFT_CMAKE_ARGS
            ${EP_COMMON_CMAKE_ARGS}
            "-DCMAKE_INSTALL_PREFIX=${THRIFT_PREFIX}"
            "-DCMAKE_INSTALL_RPATH=${THRIFT_PREFIX}/lib"
            -DBUILD_SHARED_LIBS=OFF
            -DBUILD_TESTING=OFF
            -DBUILD_EXAMPLES=OFF
            -DBUILD_TUTORIALS=OFF
            -DWITH_QT4=OFF
            -DWITH_C_GLIB=OFF
            -DWITH_JAVA=OFF
            -DWITH_PYTHON=OFF
            -DWITH_HASKELL=OFF
            -DWITH_CPP=ON
            -DWITH_STATIC_LIB=ON
            -DWITH_LIBEVENT=OFF
            # Work around https://gitlab.kitware.com/cmake/cmake/issues/18865
            -DBoost_NO_BOOST_CMAKE=ON)

    # Thrift also uses boost. Forward important boost settings if there were ones passed.
    if(DEFINED BOOST_ROOT)
        list(APPEND THRIFT_CMAKE_ARGS "-DBOOST_ROOT=${BOOST_ROOT}")
    endif()
    if(DEFINED Boost_NAMESPACE)
        list(APPEND THRIFT_CMAKE_ARGS "-DBoost_NAMESPACE=${Boost_NAMESPACE}")
    endif()

    if(DEFINED FLEX_ROOT)
        # thrift hasn't set the cmake policy that lets us use _ROOT, so work around
        list(APPEND THRIFT_CMAKE_ARGS "-DFLEX_EXECUTABLE=${FLEX_ROOT}/flex")
    endif()

    set(THRIFT_STATIC_LIB_NAME "${CMAKE_STATIC_LIBRARY_PREFIX}thrift")
    if(${UPPERCASE_BUILD_TYPE} STREQUAL "DEBUG")
        set(THRIFT_STATIC_LIB_NAME "${THRIFT_STATIC_LIB_NAME}d")
    endif()
    set(THRIFT_STATIC_LIB
            "${THRIFT_PREFIX}/lib/${THRIFT_STATIC_LIB_NAME}${CMAKE_STATIC_LIBRARY_SUFFIX}")

    if(ZLIB_SHARED_LIB)
        set(THRIFT_CMAKE_ARGS "-DZLIB_LIBRARY=${ZLIB_SHARED_LIB}" ${THRIFT_CMAKE_ARGS})
    else()
        set(THRIFT_CMAKE_ARGS "-DZLIB_LIBRARY=${ZLIB_STATIC_LIB}" ${THRIFT_CMAKE_ARGS})
    endif()
    set(THRIFT_DEPENDENCIES ${THRIFT_DEPENDENCIES} ${ZLIB_LIBRARY})

    if(BOOST_VENDORED)
        set(THRIFT_DEPENDENCIES ${THRIFT_DEPENDENCIES} boost_ep)
    endif()

    if("${THRIFT_SOURCE_URL}" STREQUAL "FROM-APACHE-MIRROR")
        get_apache_mirror()
        set(
                THRIFT_SOURCE_URL
                "${APACHE_MIRROR}/thrift/${THRIFT_BUILD_VERSION}/thrift-${THRIFT_BUILD_VERSION}.tar.gz"
        )
    endif()

    message("Downloading Apache Thrift from ${THRIFT_SOURCE_URL}")
    message("Thrift CMAKE Args ${THRIFT_CMAKE_ARGS}")
    externalproject_add(thrift_ep
            URL ${THRIFT_SOURCE_URL}
            URL_HASH "MD5=${THRIFT_BUILD_MD5_CHECKSUM}"
            BUILD_BYPRODUCTS "${THRIFT_STATIC_LIB}" "${THRIFT_COMPILER}"
            CMAKE_ARGS ${THRIFT_CMAKE_ARGS}
            DEPENDS ${THRIFT_DEPENDENCIES} ${EP_LOG_OPTIONS})

    add_library(Thrift::thrift STATIC IMPORTED)
    # The include directory must exist before it is referenced by a target.
    file(MAKE_DIRECTORY "${THRIFT_INCLUDE_DIR}")
    set_target_properties(Thrift::thrift
            PROPERTIES IMPORTED_LOCATION "${THRIFT_STATIC_LIB}"
            INTERFACE_INCLUDE_DIRECTORIES "${THRIFT_INCLUDE_DIR}")
    add_dependencies(Thrift::thrift thrift_ep)
    set(THRIFT_VERSION ${ARROW_THRIFT_BUILD_VERSION})
    include_directories(${THRIFT_INCLUDE_DIR})
endmacro()

macro(build_arrow)
    message("Building Apache Arrow from source")
    set(ARROW_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/arrow_ep/src/arrow_ep-install")
    set(ARROW_INCLUDE_DIR "${ARROW_PREFIX}/include")
    set(ARROW_CMAKE_ARGS
            ${EP_COMMON_CMAKE_ARGS}
            "-DCMAKE_INSTALL_PREFIX=${ARROW_PREFIX}"
            "-DCMAKE_INSTALL_RPATH=${ARROW_PREFIX}/lib"
            "-DARROW_BUILD_TESTS=ON"
            "-DARROW_USE_GLOG=ON"
            "-DARROW_WITH_BROTLI=ON"
            "-DARROW_WITH_BZ2=ON"
            "-DARROW_WITH_LZ4=ON"
            "-DARROW_WITH_SNAPPY=ON"
            "-DARROW_WITH_ZLIB=ON"
            "-DARROW_WITH_ZSTD=ON"
            )

    set(ARROW_LIB_NAME "${CMAKE_STATIC_LIBRARY_PREFIX}arrow")
    set(ARROW_TESTING_LIB_NAME "${CMAKE_STATIC_LIBRARY_PREFIX}arrow_testing")

#    if(${UPPERCASE_BUILD_TYPE} STREQUAL "DEBUG")
#        set(ARROW_STATIC_LIB_NAME "${ARROW_STATIC_LIB_NAME}d")
#    endif()
    set(ARROW_STATIC_LIB
            "${ARROW_PREFIX}/lib/${ARROW_LIB_NAME}${CMAKE_STATIC_LIBRARY_SUFFIX}")
    set(ARROW_TESTING_STATIC_LIB
            "${ARROW_PREFIX}/lib/${ARROW_TESTING_LIB_NAME}${CMAKE_STATIC_LIBRARY_SUFFIX}")

    set(ARROW_SHARED_LIB
            "${ARROW_PREFIX}/lib/${ARROW_LIB_NAME}${CMAKE_SHARED_LIBRARY_SUFFIX}")
    set(ARROW_TESTING_SHARED_LIB
            "${ARROW_PREFIX}/lib/${ARROW_TESTING_LIB_NAME}${CMAKE_SHARED_LIBRARY_SUFFIX}")

    if("${ARROW_SOURCE_URL}" STREQUAL "FROM-APACHE-MIRROR")
        get_apache_mirror()
        set(
                ARROW_SOURCE_URL
                "${APACHE_MIRROR}/arrow/arrow-${ARROW_BUILD_VERSION}/apache-arrow-${ARROW_BUILD_VERSION}.tar.gz"
        )
    endif()

    message("Downloading Apache Arrow from ${ARROW_SOURCE_URL}")
    set(ARROW_EP_SRC "${CMAKE_CURRENT_BINARY_DIR}/arrow_ep-prefix/src/arrow_ep")
    externalproject_add(arrow_ep
            URL ${ARROW_SOURCE_URL}
            URL_HASH "SHA256=${ARROW_BUILD_SHA256_CHECKSUM}"
            BUILD_BYPRODUCTS "${ARROW_STATIC_LIB}"
            CONFIGURE_COMMAND ${CMAKE_COMMAND} ${ARROW_CMAKE_ARGS} ${ARROW_EP_SRC}/cpp
            DEPENDS ${ARROW_DEPENDENCIES} ${EP_LOG_OPTIONS})

    add_library(Arrow::ArrowStatic STATIC IMPORTED)
    add_library(Arrow::TestStatic STATIC IMPORTED)
    add_library(Arrow::ArrowShared SHARED IMPORTED)
    add_library(Arrow::TestShared SHARED IMPORTED)

    # The include directory must exist before it is referenced by a target.
    file(MAKE_DIRECTORY "${ARROW_INCLUDE_DIR}")

    set_target_properties(Arrow::ArrowStatic
            PROPERTIES IMPORTED_LOCATION "${ARROW_STATIC_LIB}"
            INTERFACE_INCLUDE_DIRECTORIES "${ARROW_INCLUDE_DIR}")
    set_target_properties(Arrow::TestStatic
            PROPERTIES IMPORTED_LOCATION "${ARROW_TESTING_STATIC_LIB}"
            INTERFACE_INCLUDE_DIRECTORIES "${ARROW_INCLUDE_DIR}")
    set_target_properties(Arrow::ArrowShared
            PROPERTIES IMPORTED_LOCATION "${ARROW_SHARED_LIB}"
            INTERFACE_INCLUDE_DIRECTORIES "${ARROW_INCLUDE_DIR}")
    set_target_properties(Arrow::TestShared
            PROPERTIES IMPORTED_LOCATION "${ARROW_TESTING_SHARED_LIB}"
            INTERFACE_INCLUDE_DIRECTORIES "${ARROW_INCLUDE_DIR}")

    add_dependencies(Arrow::ArrowStatic arrow_ep)
    add_dependencies(Arrow::ArrowShared arrow_ep)

    add_dependencies(Arrow::TestStatic arrow_ep)
    add_dependencies(Arrow::TestShared arrow_ep)

    target_link_libraries(Arrow::TestShared
            INTERFACE GTest::Main
            INTERFACE GTest::GTest
            INTERFACE GTest::GMock)

    set(ARROW_VERSION ${ARROW_BUILD_VERSION})
    include_directories(${ARROW_INCLUDE_DIR})
endmacro()

macro(build_gtest)
    message(STATUS "Building gtest from source")
    set(GTEST_VENDORED TRUE)
    set(GTEST_SOURCE_URL "https://github.com/google/googletest/archive/release-${GTEST_BUILD_VERSION}.tar.gz")
    set(GTEST_CMAKE_CXX_FLAGS ${EP_CXX_FLAGS})

    if(CMAKE_BUILD_TYPE MATCHES DEBUG)
        set(CMAKE_GTEST_DEBUG_EXTENSION "d")
    else()
        set(CMAKE_GTEST_DEBUG_EXTENSION "")
    endif()

    if(APPLE)
        set(GTEST_CMAKE_CXX_FLAGS ${GTEST_CMAKE_CXX_FLAGS} -DGTEST_USE_OWN_TR1_TUPLE=1
                -Wno-unused-value -Wno-ignored-attributes)
    endif()

    if(MSVC)
        set(GTEST_CMAKE_CXX_FLAGS "${GTEST_CMAKE_CXX_FLAGS} -DGTEST_CREATE_SHARED_LIBRARY=1")
    endif()

    set(GTEST_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/googletest_ep-prefix/src/googletest_ep")
    set(GTEST_INCLUDE_DIR "${GTEST_PREFIX}/include")

    set(_GTEST_RUNTIME_DIR ${BUILD_OUTPUT_ROOT_DIRECTORY})

    if(MSVC)
        set(_GTEST_IMPORTED_TYPE IMPORTED_IMPLIB)
        set(_GTEST_LIBRARY_SUFFIX
                "${CMAKE_GTEST_DEBUG_EXTENSION}${CMAKE_IMPORT_LIBRARY_SUFFIX}")
        # Use the import libraries from the EP
        set(_GTEST_LIBRARY_DIR "${GTEST_PREFIX}/lib")
    else()
        set(_GTEST_IMPORTED_TYPE IMPORTED_LOCATION)
        set(_GTEST_LIBRARY_SUFFIX
                "${CMAKE_GTEST_DEBUG_EXTENSION}${CMAKE_SHARED_LIBRARY_SUFFIX}")

        # Library and runtime same on non-Windows
        set(_GTEST_LIBRARY_DIR "${GTEST_PREFIX}/lib")
    endif()

    set(GTEST_SHARED_LIB
            "${_GTEST_LIBRARY_DIR}/${CMAKE_SHARED_LIBRARY_PREFIX}gtest${_GTEST_LIBRARY_SUFFIX}")
    set(GMOCK_SHARED_LIB
            "${_GTEST_LIBRARY_DIR}/${CMAKE_SHARED_LIBRARY_PREFIX}gmock${_GTEST_LIBRARY_SUFFIX}")
    set(
            GTEST_MAIN_SHARED_LIB
            "${_GTEST_LIBRARY_DIR}/${CMAKE_SHARED_LIBRARY_PREFIX}gtest_main${_GTEST_LIBRARY_SUFFIX}"
    )
    set(GTEST_CMAKE_ARGS
            ${EP_COMMON_TOOLCHAIN}
            -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
            "-DCMAKE_INSTALL_PREFIX=${GTEST_PREFIX}"
            -DBUILD_SHARED_LIBS=ON
            -DCMAKE_CXX_FLAGS=${GTEST_CMAKE_CXX_FLAGS}
            -DCMAKE_CXX_FLAGS_${UPPERCASE_BUILD_TYPE}=${GTEST_CMAKE_CXX_FLAGS})
    set(GMOCK_INCLUDE_DIR "${GTEST_PREFIX}/include")

    if(APPLE)
        set(GTEST_CMAKE_ARGS ${GTEST_CMAKE_ARGS} "-DCMAKE_MACOSX_RPATH:BOOL=ON")
    endif()

    if(CMAKE_GENERATOR STREQUAL "Xcode")
        # Xcode projects support multi-configuration builds.  This forces the gtest build
        # to use the same output directory as a single-configuration Makefile driven build.
        list(
                APPEND GTEST_CMAKE_ARGS "-DCMAKE_LIBRARY_OUTPUT_DIRECTORY=${_GTEST_LIBRARY_DIR}"
                "-DCMAKE_LIBRARY_OUTPUT_DIRECTORY_${CMAKE_BUILD_TYPE}=${_GTEST_RUNTIME_DIR}")
    endif()

    if(MSVC)
        if(NOT ("${CMAKE_GENERATOR}" STREQUAL "Ninja"))
            set(_GTEST_RUNTIME_DIR ${_GTEST_RUNTIME_DIR}/${CMAKE_BUILD_TYPE})
        endif()
        set(GTEST_CMAKE_ARGS
                ${GTEST_CMAKE_ARGS} "-DCMAKE_RUNTIME_OUTPUT_DIRECTORY=${_GTEST_RUNTIME_DIR}"
                "-DCMAKE_RUNTIME_OUTPUT_DIRECTORY_${CMAKE_BUILD_TYPE}=${_GTEST_RUNTIME_DIR}")
    else()
        list(
                APPEND GTEST_CMAKE_ARGS "-DCMAKE_LIBRARY_OUTPUT_DIRECTORY=${_GTEST_RUNTIME_DIR}"
                "-DCMAKE_RUNTIME_OUTPUT_DIRECTORY_${CMAKE_BUILD_TYPE}=${_GTEST_RUNTIME_DIR}")
    endif()

    add_definitions(-DGTEST_LINKED_AS_SHARED_LIBRARY=1)

    if(MSVC AND NOT ARROW_USE_STATIC_CRT)
        set(GTEST_CMAKE_ARGS ${GTEST_CMAKE_ARGS} -Dgtest_force_shared_crt=ON)
    endif()

    externalproject_add(googletest_ep
            URL ${GTEST_SOURCE_URL}
            BUILD_BYPRODUCTS ${GTEST_SHARED_LIB} ${GTEST_MAIN_SHARED_LIB}
            ${GMOCK_SHARED_LIB}
            CMAKE_ARGS ${GTEST_CMAKE_ARGS} ${EP_LOG_OPTIONS})

    # The include directory must exist before it is referenced by a target.
    file(MAKE_DIRECTORY "${GTEST_INCLUDE_DIR}")

    add_library(GTest::GTest SHARED IMPORTED)
    set_target_properties(GTest::GTest
            PROPERTIES ${_GTEST_IMPORTED_TYPE} "${GTEST_SHARED_LIB}"
            INTERFACE_INCLUDE_DIRECTORIES "${GTEST_INCLUDE_DIR}")

    add_library(GTest::Main SHARED IMPORTED)
    set_target_properties(GTest::Main
            PROPERTIES ${_GTEST_IMPORTED_TYPE} "${GTEST_MAIN_SHARED_LIB}"
            INTERFACE_INCLUDE_DIRECTORIES "${GTEST_INCLUDE_DIR}")

    add_library(GTest::GMock SHARED IMPORTED)
    set_target_properties(GTest::GMock
            PROPERTIES ${_GTEST_IMPORTED_TYPE} "${GMOCK_SHARED_LIB}"
            INTERFACE_INCLUDE_DIRECTORIES "${GTEST_INCLUDE_DIR}")
    include_directories(${GTEST_INCLUDE_DIR})
    add_dependencies(GTest::GTest googletest_ep)
    add_dependencies(GTest::Main googletest_ep)
    add_dependencies(GTest::GMock googletest_ep)
endmacro()



set(EP_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${CMAKE_CXX_FLAGS_${UPPERCASE_BUILD_TYPE}}")
set(EP_C_FLAGS "${CMAKE_C_FLAGS} ${CMAKE_C_FLAGS_${UPPERCASE_BUILD_TYPE}}")

if(NOT MSVC)
    # Set -fPIC on all external projects
    set(EP_CXX_FLAGS "${EP_CXX_FLAGS} -fPIC")
    set(EP_C_FLAGS "${EP_C_FLAGS} -fPIC")
endif()

# CC/CXX environment variables are captured on the first invocation of the
# builder (e.g make or ninja) instead of when CMake is invoked into to build
# directory. This leads to issues if the variables are exported in a subshell
# and the invocation of make/ninja is in distinct subshell without the same
# environment (CC/CXX).
set(EP_COMMON_TOOLCHAIN -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
        -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER})

if(CMAKE_AR)
    set(EP_COMMON_TOOLCHAIN ${EP_COMMON_TOOLCHAIN} -DCMAKE_AR=${CMAKE_AR})
endif()

if(CMAKE_RANLIB)
    set(EP_COMMON_TOOLCHAIN ${EP_COMMON_TOOLCHAIN} -DCMAKE_RANLIB=${CMAKE_RANLIB})
endif()


set(EP_COMMON_CMAKE_ARGS
        ${EP_COMMON_TOOLCHAIN}
        -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
        -DCMAKE_C_FLAGS=${EP_C_FLAGS}
        -DCMAKE_C_FLAGS_${UPPERCASE_BUILD_TYPE}=${EP_C_FLAGS}
        -DCMAKE_CXX_FLAGS=${EP_CXX_FLAGS}
        -DCMAKE_CXX_FLAGS_${UPPERCASE_BUILD_TYPE}=${EP_CXX_FLAGS})

if(NOT PARQUET_VERBOSE_THIRDPARTY_BUILD)
    set(EP_LOG_OPTIONS
            LOG_CONFIGURE
            1
            LOG_BUILD
            1
            LOG_INSTALL
            1
            LOG_DOWNLOAD
            1)
    set(Boost_DEBUG FALSE)
else()
    set(EP_LOG_OPTIONS)
    set(Boost_DEBUG TRUE)
endif()

# Ensure that a default make is set
if("${MAKE}" STREQUAL "")
    if(NOT MSVC)
        find_program(MAKE make)
    endif()
endif()

# Using make -j in sub-make is fragile
# see discussion https://github.com/apache/arrow/pull/2779
if(${CMAKE_GENERATOR} MATCHES "Makefiles")
    set(MAKE_BUILD_ARGS "")
else()
    # limit the maximum number of jobs for ninja
    set(MAKE_BUILD_ARGS "-j${NPROC}")
endif()

# ----------------------------------------------------------------------
# Find pthreads

set(THREADS_PREFER_PTHREAD_FLAG ON)
find_package(Threads REQUIRED)

