# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

# Common path suffixes to be searched by find_library or find_path.
# Windows artifacts may be found under "<root>/Library", so
# search there as well.
set(LIB_PATH_SUFFIXES
    "${CMAKE_LIBRARY_ARCHITECTURE}"
    "lib/${CMAKE_LIBRARY_ARCHITECTURE}"
    "lib64"
    "lib32"
    "lib"
    "bin"
    "Library"
    "Library/lib"
    "Library/bin")
set(INCLUDE_PATH_SUFFIXES "include" "Library" "Library/include")

# \arg OUTPUTS list to append built targets to
function(ADD_ARROW_LIB LIB_NAME)
  set(options BUILD_SHARED BUILD_STATIC)
  set(one_value_args CMAKE_PACKAGE_NAME PKG_CONFIG_NAME SHARED_LINK_FLAGS)
  set(multi_value_args
      SOURCES
      OUTPUTS
      STATIC_LINK_LIBS
      SHARED_LINK_LIBS
      SHARED_PRIVATE_LINK_LIBS
      EXTRA_INCLUDES
      PRIVATE_INCLUDES
      DEPENDENCIES
      SHARED_INSTALL_INTERFACE_LIBS
      STATIC_INSTALL_INTERFACE_LIBS
      OUTPUT_PATH)
  cmake_parse_arguments(ARG
                        "${options}"
                        "${one_value_args}"
                        "${multi_value_args}"
                        ${ARGN})
  if(ARG_UNPARSED_ARGUMENTS)
    message(SEND_ERROR "Error: unrecognized arguments: ${ARG_UNPARSED_ARGUMENTS}")
  endif()

  if(ARG_OUTPUTS)
    set(${ARG_OUTPUTS})
  endif()

  set(BUILD_SHARED ${ARG_BUILD_SHARED})
  set(BUILD_STATIC ${ARG_BUILD_STATIC})
  if(ARG_OUTPUT_PATH)
    set(OUTPUT_PATH ${ARG_OUTPUT_PATH})
  else()
    set(OUTPUT_PATH ${BUILD_OUTPUT_ROOT_DIRECTORY})
  endif()

  # generate a single "objlib" from all C++ modules and link
  # that "objlib" into each library kind, to avoid compiling twice
  add_library(${LIB_NAME}_objlib OBJECT ${ARG_SOURCES})
  # Necessary to make static linking into other shared libraries work properly
  set_property(TARGET ${LIB_NAME}_objlib PROPERTY POSITION_INDEPENDENT_CODE 1)
  if(ARG_DEPENDENCIES)
    add_dependencies(${LIB_NAME}_objlib ${ARG_DEPENDENCIES})
  endif()
  set(LIB_DEPS $<TARGET_OBJECTS:${LIB_NAME}_objlib>)
  set(LIB_INCLUDES)
  set(EXTRA_DEPS)

  if(ARG_OUTPUTS)
    list(APPEND ${ARG_OUTPUTS} ${LIB_NAME}_objlib)
  endif()

  if(ARG_EXTRA_INCLUDES)
    target_include_directories(${LIB_NAME}_objlib SYSTEM PUBLIC ${ARG_EXTRA_INCLUDES})
  endif()
  if(ARG_PRIVATE_INCLUDES)
    target_include_directories(${LIB_NAME}_objlib PRIVATE ${ARG_PRIVATE_INCLUDES})
  endif()

  set(RUNTIME_INSTALL_DIR bin)

  if(BUILD_SHARED)
    add_library(${LIB_NAME}_shared SHARED ${LIB_DEPS})
    if(EXTRA_DEPS)
      add_dependencies(${LIB_NAME}_shared ${EXTRA_DEPS})
    endif()

    if(ARG_OUTPUTS)
      list(APPEND ${ARG_OUTPUTS} ${LIB_NAME}_shared)
    endif()

    if(LIB_INCLUDES)
      target_include_directories(${LIB_NAME}_shared SYSTEM PUBLIC ${ARG_EXTRA_INCLUDES})
    endif()

    if(ARG_PRIVATE_INCLUDES)
      target_include_directories(${LIB_NAME}_shared PRIVATE ${ARG_PRIVATE_INCLUDES})
    endif()

    set_target_properties(${LIB_NAME}_shared
                          PROPERTIES LIBRARY_OUTPUT_DIRECTORY
                                     "${OUTPUT_PATH}"
                                     RUNTIME_OUTPUT_DIRECTORY
                                     "${OUTPUT_PATH}"
                                     PDB_OUTPUT_DIRECTORY
                                     "${OUTPUT_PATH}"
                                     LINK_FLAGS
                                     "${ARG_SHARED_LINK_FLAGS}"
                                     OUTPUT_NAME
                                     ${LIB_NAME}
                                     VERSION
                                     "${ARROW_FULL_SO_VERSION}"
                                     SOVERSION
                                     "${ARROW_SO_VERSION}")

    target_link_libraries(${LIB_NAME}_shared
                          LINK_PUBLIC
                          "$<BUILD_INTERFACE:${ARG_SHARED_LINK_LIBS}>"
                          "$<INSTALL_INTERFACE:${ARG_SHARED_INSTALL_INTERFACE_LIBS}>"
                          LINK_PRIVATE
                          ${ARG_SHARED_PRIVATE_LINK_LIBS})

    if(ARROW_RPATH_ORIGIN)
      if(APPLE)
        set(_lib_install_rpath "@loader_path")
      else()
        set(_lib_install_rpath "\$ORIGIN")
      endif()
      set_target_properties(${LIB_NAME}_shared
                            PROPERTIES INSTALL_RPATH ${_lib_install_rpath})
    endif()

    install(TARGETS ${LIB_NAME}_shared ${INSTALL_IS_OPTIONAL}
            EXPORT ${LIB_NAME}_targets
            RUNTIME DESTINATION ${RUNTIME_INSTALL_DIR}
            LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
            ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
            INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
  endif()

  if(BUILD_STATIC)
    add_library(${LIB_NAME}_static STATIC ${LIB_DEPS})
    if(EXTRA_DEPS)
      add_dependencies(${LIB_NAME}_static ${EXTRA_DEPS})
    endif()

    if(ARG_OUTPUTS)
      list(APPEND ${ARG_OUTPUTS} ${LIB_NAME}_static)
    endif()

    if(LIB_INCLUDES)
      target_include_directories(${LIB_NAME}_static SYSTEM PUBLIC ${ARG_EXTRA_INCLUDES})
    endif()

    if(ARG_PRIVATE_INCLUDES)
      target_include_directories(${LIB_NAME}_static PRIVATE ${ARG_PRIVATE_INCLUDES})
    endif()

    if(MSVC)
      set(LIB_NAME_STATIC ${LIB_NAME}_static)
    else()
      set(LIB_NAME_STATIC ${LIB_NAME})
    endif()

    if(ARROW_BUILD_STATIC AND WIN32)
      target_compile_definitions(${LIB_NAME}_static PUBLIC ARROW_STATIC)
    endif()

    set_target_properties(${LIB_NAME}_static
                          PROPERTIES LIBRARY_OUTPUT_DIRECTORY "${OUTPUT_PATH}" OUTPUT_NAME
                                     ${LIB_NAME_STATIC})

    if(ARG_STATIC_INSTALL_INTERFACE_LIBS)
      set(INTERFACE_LIBS ${ARG_STATIC_INSTALL_INTERFACE_LIBS})
    else()
      set(INTERFACE_LIBS ${ARG_STATIC_LINK_LIBS})
    endif()

    target_link_libraries(${LIB_NAME}_static LINK_PUBLIC
                          "$<BUILD_INTERFACE:${ARG_STATIC_LINK_LIBS}>"
                          "$<INSTALL_INTERFACE:${INTERFACE_LIBS}>")

    install(TARGETS ${LIB_NAME}_static ${INSTALL_IS_OPTIONAL}
            EXPORT ${LIB_NAME}_targets
            RUNTIME DESTINATION ${RUNTIME_INSTALL_DIR}
            LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
            ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
            INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
  endif()

  # Modify variable in calling scope
  if(ARG_OUTPUTS)
    set(${ARG_OUTPUTS} ${${ARG_OUTPUTS}} PARENT_SCOPE)
  endif()
endfunction()

#
# \arg PREFIX a string to append to the name of the benchmark executable. For
# example, if you have src/arrow/foo/bar-benchmark.cc, then PREFIX "foo" will
# create test executable foo-bar-benchmark
# \arg LABELS the benchmark label or labels to assign the unit tests to. By
# default, benchmarks will go in the "benchmark" group. Custom targets for the
# group names must exist
function(ADD_BENCHMARK REL_BENCHMARK_NAME)
  set(options)
  set(one_value_args)
  set(multi_value_args
      EXTRA_LINK_LIBS
      STATIC_LINK_LIBS
      DEPENDENCIES
      PREFIX
      LABELS)
  cmake_parse_arguments(ARG
                        "${options}"
                        "${one_value_args}"
                        "${multi_value_args}"
                        ${ARGN})
  if(ARG_UNPARSED_ARGUMENTS)
    message(SEND_ERROR "Error: unrecognized arguments: ${ARG_UNPARSED_ARGUMENTS}")
  endif()

  if(NO_BENCHMARKS)
    return()
  endif()
  get_filename_component(BENCHMARK_NAME ${REL_BENCHMARK_NAME} NAME_WE)

  if(ARG_PREFIX)
    set(BENCHMARK_NAME "${ARG_PREFIX}-${BENCHMARK_NAME}")
  endif()

  # Make sure the executable name contains only hyphens, not underscores
  string(REPLACE "_" "-" BENCHMARK_NAME ${BENCHMARK_NAME})

  if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/${REL_BENCHMARK_NAME}.cc)
    # This benchmark has a corresponding .cc file, set it up as an executable.
    set(BENCHMARK_PATH "${EXECUTABLE_OUTPUT_PATH}/${BENCHMARK_NAME}")
    add_executable(${BENCHMARK_NAME} "${REL_BENCHMARK_NAME}.cc")

    if(ARG_STATIC_LINK_LIBS)
      # Customize link libraries
      target_link_libraries(${BENCHMARK_NAME} PRIVATE ${ARG_STATIC_LINK_LIBS})
    else()
      target_link_libraries(${BENCHMARK_NAME} PRIVATE ${ARROW_BENCHMARK_LINK_LIBS})
    endif()
    add_dependencies(benchmark ${BENCHMARK_NAME})
    set(NO_COLOR "--color_print=false")

    if(ARG_EXTRA_LINK_LIBS)
      target_link_libraries(${BENCHMARK_NAME} PRIVATE ${ARG_EXTRA_LINK_LIBS})
    endif()
  else()
    # No executable, just invoke the benchmark (probably a script) directly.
    set(BENCHMARK_PATH ${CMAKE_CURRENT_SOURCE_DIR}/${REL_BENCHMARK_NAME})
    set(NO_COLOR "")
  endif()

  # With OSX and conda, we need to set the correct RPATH so that dependencies
  # are found. The installed libraries with conda have an RPATH that matches
  # for executables and libraries lying in $ENV{CONDA_PREFIX}/bin or
  # $ENV{CONDA_PREFIX}/lib but our test libraries and executables are not
  # installed there.
  if(NOT "$ENV{CONDA_PREFIX}" STREQUAL "" AND APPLE)
    set_target_properties(${BENCHMARK_NAME}
                          PROPERTIES BUILD_WITH_INSTALL_RPATH
                                     TRUE
                                     INSTALL_RPATH_USE_LINK_PATH
                                     TRUE
                                     INSTALL_RPATH
                                     "$ENV{CONDA_PREFIX}/lib;${EXECUTABLE_OUTPUT_PATH}")
  endif()

  # Add test as dependency of relevant label targets
  add_dependencies(all-benchmarks ${BENCHMARK_NAME})
  foreach(TARGET ${ARG_LABELS})
    add_dependencies(${TARGET} ${BENCHMARK_NAME})
  endforeach()

  if(ARG_DEPENDENCIES)
    add_dependencies(${BENCHMARK_NAME} ${ARG_DEPENDENCIES})
  endif()

  if(ARG_LABELS)
    set(ARG_LABELS "benchmark;${ARG_LABELS}")
  else()
    set(ARG_LABELS benchmark)
  endif()

  add_test(${BENCHMARK_NAME}
           ${BUILD_SUPPORT_DIR}/run-test.sh
           ${CMAKE_BINARY_DIR}
           benchmark
           ${BENCHMARK_PATH}
           ${NO_COLOR})
  set_property(TEST ${BENCHMARK_NAME} APPEND PROPERTY LABELS ${ARG_LABELS})
endfunction()

#
# Testing
#
# Add a new test case, with or without an executable that should be built.
#
# REL_TEST_NAME is the name of the test. It may be a single component
# (e.g. monotime-test) or contain additional components (e.g.
# net/net_util-test). Either way, the last component must be a globally
# unique name.
#
# If given, SOURCES is the list of C++ source files to compile into the test
# executable.  Otherwise, "REL_TEST_NAME.cc" is used.
#
# The unit test is added with a label of "unittest" to support filtering with
# ctest.
#
# Arguments after the test name will be passed to set_tests_properties().
#
# \arg ENABLED if passed, add this unit test even if ARROW_BUILD_TESTS is off
# \arg PREFIX a string to append to the name of the test executable. For
# example, if you have src/arrow/foo/bar-test.cc, then PREFIX "foo" will create
# test executable foo-bar-test
# \arg LABELS the unit test label or labels to assign the unit tests
# to. By default, unit tests will go in the "unittest" group, but if we have
# multiple unit tests in some subgroup, you can assign a test to multiple
# groups use the syntax unittest;GROUP2;GROUP3. Custom targets for the group
# names must exist
function(ADD_TEST_CASE REL_TEST_NAME)
  set(options NO_VALGRIND ENABLED)
  set(one_value_args)
  set(multi_value_args
      SOURCES
      STATIC_LINK_LIBS
      EXTRA_LINK_LIBS
      EXTRA_INCLUDES
      EXTRA_DEPENDENCIES
      LABELS
      PREFIX)
  cmake_parse_arguments(ARG
                        "${options}"
                        "${one_value_args}"
                        "${multi_value_args}"
                        ${ARGN})
  if(ARG_UNPARSED_ARGUMENTS)
    message(SEND_ERROR "Error: unrecognized arguments: ${ARG_UNPARSED_ARGUMENTS}")
  endif()

  if(NO_TESTS AND NOT ARG_ENABLED)
    return()
  endif()
  get_filename_component(TEST_NAME ${REL_TEST_NAME} NAME_WE)

  if(ARG_PREFIX)
    set(TEST_NAME "${ARG_PREFIX}-${TEST_NAME}")
  endif()

  if(ARG_SOURCES)
    set(SOURCES ${ARG_SOURCES})
  else()
    set(SOURCES "${REL_TEST_NAME}.cc")
  endif()

  # Make sure the executable name contains only hyphens, not underscores
  string(REPLACE "_" "-" TEST_NAME ${TEST_NAME})

  set(TEST_PATH "${EXECUTABLE_OUTPUT_PATH}/${TEST_NAME}")
  add_executable(${TEST_NAME} ${SOURCES})

  # With OSX and conda, we need to set the correct RPATH so that dependencies
  # are found. The installed libraries with conda have an RPATH that matches
  # for executables and libraries lying in $ENV{CONDA_PREFIX}/bin or
  # $ENV{CONDA_PREFIX}/lib but our test libraries and executables are not
  # installed there.
  if(NOT "$ENV{CONDA_PREFIX}" STREQUAL "" AND APPLE)
    set_target_properties(${TEST_NAME}
                          PROPERTIES BUILD_WITH_INSTALL_RPATH
                                     TRUE
                                     INSTALL_RPATH_USE_LINK_PATH
                                     TRUE
                                     INSTALL_RPATH
                                     "${EXECUTABLE_OUTPUT_PATH};$ENV{CONDA_PREFIX}/lib")
  endif()

  if(ARG_STATIC_LINK_LIBS)
    # Customize link libraries
    target_link_libraries(${TEST_NAME} PRIVATE ${ARG_STATIC_LINK_LIBS})
  else()
    target_link_libraries(${TEST_NAME} PRIVATE ${ARROW_TEST_LINK_LIBS})
  endif()

  if(ARG_EXTRA_LINK_LIBS)
    target_link_libraries(${TEST_NAME} PRIVATE ${ARG_EXTRA_LINK_LIBS})
  endif()

  if(ARG_EXTRA_INCLUDES)
    target_include_directories(${TEST_NAME} SYSTEM PUBLIC ${ARG_EXTRA_INCLUDES})
  endif()

  if(ARG_EXTRA_DEPENDENCIES)
    add_dependencies(${TEST_NAME} ${ARG_EXTRA_DEPENDENCIES})
  endif()

  if(ARROW_TEST_MEMCHECK AND NOT ARG_NO_VALGRIND)
    set_property(TARGET ${TEST_NAME}
                 APPEND_STRING
                 PROPERTY COMPILE_FLAGS " -DARROW_VALGRIND")
    add_test(
      ${TEST_NAME} bash -c
      "cd '${CMAKE_SOURCE_DIR}'; \
               valgrind --suppressions=valgrind.supp --tool=memcheck --gen-suppressions=all \
                 --leak-check=full --leak-check-heuristics=stdstring --error-exitcode=1 ${TEST_PATH}"
      )
  elseif(WIN32)
    add_test(${TEST_NAME} ${TEST_PATH})
  else()
    add_test(${TEST_NAME}
             ${BUILD_SUPPORT_DIR}/run-test.sh
             ${CMAKE_BINARY_DIR}
             test
             ${TEST_PATH})
  endif()

  # Add test as dependency of relevant targets
  add_dependencies(all-tests ${TEST_NAME})
  foreach(TARGET ${ARG_LABELS})
    add_dependencies(${TARGET} ${TEST_NAME})
  endforeach()

  if(ARG_LABELS)
    set(ARG_LABELS "unittest;${ARG_LABELS}")
  else()
    set(ARG_LABELS unittest)
  endif()

  set_property(TEST ${TEST_NAME} APPEND PROPERTY LABELS ${ARG_LABELS})
endfunction()

#
# Examples
#
# Add a new example, with or without an executable that should be built.
# If examples are enabled then they will be run along side unit tests with ctest.
# 'make runexample' to build/run only examples.
#
# REL_EXAMPLE_NAME is the name of the example app. It may be a single component
# (e.g. monotime-example) or contain additional components (e.g.
# net/net_util-example). Either way, the last component must be a globally
# unique name.

# The example will registered as unit test with ctest with a label
# of 'example'.
#
# Arguments after the test name will be passed to set_tests_properties().
#
# \arg PREFIX a string to append to the name of the example executable. For
# example, if you have src/arrow/foo/bar-example.cc, then PREFIX "foo" will
# create test executable foo-bar-example
function(ADD_ARROW_EXAMPLE REL_EXAMPLE_NAME)
  set(options)
  set(one_value_args)
  set(multi_value_args EXTRA_LINK_LIBS DEPENDENCIES PREFIX)
  cmake_parse_arguments(ARG
                        "${options}"
                        "${one_value_args}"
                        "${multi_value_args}"
                        ${ARGN})
  if(ARG_UNPARSED_ARGUMENTS)
    message(SEND_ERROR "Error: unrecognized arguments: ${ARG_UNPARSED_ARGUMENTS}")
  endif()

  if(NO_EXAMPLES)
    return()
  endif()
  get_filename_component(EXAMPLE_NAME ${REL_EXAMPLE_NAME} NAME_WE)

  if(ARG_PREFIX)
    set(EXAMPLE_NAME "${ARG_PREFIX}-${EXAMPLE_NAME}")
  endif()

  if(EXISTS ${CMAKE_SOURCE_DIR}/examples/arrow/${REL_EXAMPLE_NAME}.cc)
    # This example has a corresponding .cc file, set it up as an executable.
    set(EXAMPLE_PATH "${EXECUTABLE_OUTPUT_PATH}/${EXAMPLE_NAME}")
    add_executable(${EXAMPLE_NAME} "${REL_EXAMPLE_NAME}.cc")
    target_link_libraries(${EXAMPLE_NAME} ${ARROW_EXAMPLE_LINK_LIBS})
    add_dependencies(runexample ${EXAMPLE_NAME})
    set(NO_COLOR "--color_print=false")

    if(ARG_EXTRA_LINK_LIBS)
      target_link_libraries(${EXAMPLE_NAME} ${ARG_EXTRA_LINK_LIBS})
    endif()
  endif()

  if(ARG_DEPENDENCIES)
    add_dependencies(${EXAMPLE_NAME} ${ARG_DEPENDENCIES})
  endif()

  add_test(${EXAMPLE_NAME} ${EXAMPLE_PATH})
  set_tests_properties(${EXAMPLE_NAME} PROPERTIES LABELS "example")
endfunction()

function(ARROW_INSTALL_ALL_HEADERS PATH)
  set(options)
  set(one_value_args)
  set(multi_value_args PATTERN)
  cmake_parse_arguments(ARG
                        "${options}"
                        "${one_value_args}"
                        "${multi_value_args}"
                        ${ARGN})
  if(NOT ARG_PATTERN)
    # The .hpp extension is used by some vendored libraries
    set(ARG_PATTERN "*.h" "*.hpp")
  endif()
  file(GLOB CURRENT_DIRECTORY_HEADERS ${ARG_PATTERN})

  set(PUBLIC_HEADERS)
  foreach(HEADER ${CURRENT_DIRECTORY_HEADERS})
    get_filename_component(HEADER_BASENAME ${HEADER} NAME)
    if(HEADER_BASENAME MATCHES "internal")
      continue()
    endif()
    list(APPEND PUBLIC_HEADERS ${HEADER})
  endforeach()
  install(FILES ${PUBLIC_HEADERS} DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/${PATH}")
endfunction()

