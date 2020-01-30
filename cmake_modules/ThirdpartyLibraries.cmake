
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
            -DWITH_LIBEVENT=OFF
            -DWITH_STATIC_LIB=ON
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
            )

    set(ARROW_STATIC_LIB_NAME "${CMAKE_STATIC_LIBRARY_PREFIX}arrow")
    if(${UPPERCASE_BUILD_TYPE} STREQUAL "DEBUG")
        set(ARROW_STATIC_LIB_NAME "${ARROW_STATIC_LIB_NAME}d")
    endif()
    set(ARROW_STATIC_LIB
            "${AROW_PREFIX}/lib/${ARROW_STATIC_LIB_NAME}${CMAKE_STATIC_LIBRARY_SUFFIX}")

    if("${ARROW_SOURCE_URL}" STREQUAL "FROM-APACHE-MIRROR")
        get_apache_mirror()
        set(
                ARROW_SOURCE_URL
                "${APACHE_MIRROR}/arrow/${ARROW_BUILD_VERSION}/arrow-${ARROW_BUILD_VERSION}.tar.gz"
        )
    endif()

    message("Downloading Apache Arrow from ${ARROW_SOURCE_URL}")
    externalproject_add(arrow_ep
            URL ${ARROW_SOURCE_URL}
            URL_HASH "SHA256=${ARROW_BUILD_SHA256_CHECKSUM}"
            BUILD_BYPRODUCTS "${THRIFT_STATIC_LIB}" "${THRIFT_COMPILER}"
            CMAKE_ARGS ${THRIFT_CMAKE_ARGS}
            DEPENDS ${THRIFT_DEPENDENCIES} ${EP_LOG_OPTIONS})

    add_library(Arrow::arrow STATIC IMPORTED)
    # The include directory must exist before it is referenced by a target.
    file(MAKE_DIRECTORY "${ARROW_INCLUDE_DIR}")
    set_target_properties(Arrow::arrow
            PROPERTIES IMPORTED_LOCATION "${ARROW_STATIC_LIB}"
            INTERFACE_INCLUDE_DIRECTORIES "${ARROW_INCLUDE_DIR}")
    add_dependencies(Arrow::arrow arrow_ep)
    set(ARROW_VERSION ${ARROW_BUILD_VERSION})
    include_directories(${ARROW_INCLUDE_DIR})
endmacro()


set(EP_COMMON_CMAKE_ARGS
        ${EP_COMMON_TOOLCHAIN}
        -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
        -DCMAKE_C_FLAGS=${EP_C_FLAGS}
        -DCMAKE_C_FLAGS_${UPPERCASE_BUILD_TYPE}=${EP_C_FLAGS}
        -DCMAKE_CXX_FLAGS=${EP_CXX_FLAGS}
        -DCMAKE_CXX_FLAGS_${UPPERCASE_BUILD_TYPE}=${EP_CXX_FLAGS})

if(NOT ARROW_VERBOSE_THIRDPARTY_BUILD)
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