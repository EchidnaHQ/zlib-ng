cmake_minimum_required(VERSION 3.12)

include(FetchContent)

enable_language(CXX)

# Google test requires at least C++11
set(CMAKE_CXX_STANDARD 11)

# Google test requires MSAN instrumented LLVM C++ libraries
if(WITH_SANITIZER STREQUAL "Memory")
    if(NOT DEFINED ENV{LLVM_BUILD_DIR})
        message(FATAL_ERROR "MSAN instrumented C++ libraries required!")
    endif()

    # Must set include and compile options before fetching googletest
    include_directories($ENV{LLVM_BUILD_DIR}/include $ENV{LLVM_BUILD_DIR}/include/c++/v1)
    add_compile_options(-stdlib=libc++ -g)
endif()

if(NOT TARGET GTest::GTest)
    # Prevent overriding the parent project's compiler/linker settings for Windows
    set(gtest_force_shared_crt ON CACHE BOOL
        "Use shared (DLL) run-time lib even when Google Test is built as static lib." FORCE)

    # Allow specifying alternative Google test repository
    if(NOT DEFINED GTEST_REPOSITORY)
        set(GTEST_REPOSITORY https://github.com/google/googletest.git)
    endif()
    if(NOT DEFINED GTEST_TAG)
        # Use older version of Google test to support older versions of GCC
        if (CMAKE_CXX_COMPILER_ID MATCHES "GNU" AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS_EQUAL 5.3)
            set(GTEST_TAG release-1.10.0)
        else()
            set(GTEST_TAG release-1.11.0)
        endif()
    endif()

    # Fetch Google test source code from official repository
    FetchContent_Declare(googletest
        GIT_REPOSITORY ${GTEST_REPOSITORY}
        GIT_TAG ${GTEST_TAG})

    FetchContent_GetProperties(googletest)
    if(NOT googletest_POPULATED)
        FetchContent_Populate(googletest)
        add_subdirectory(${googletest_SOURCE_DIR} ${googletest_BINARY_DIR} EXCLUDE_FROM_ALL)
    endif()
    add_library(GTest::GTest ALIAS gtest)
endif()

set(TEST_SRCS
    test_adler32.cc
    test_aligned_alloc.cc
    test_compare256.cc
    test_compress.cc
    test_compress_bound.cc
    test_crc32.cc
    test_cve-2003-0107.cc
    test_deflate_bound.cc
    test_deflate_copy.cc
    test_deflate_dict.cc
    test_deflate_hash_head_0.cc
    test_deflate_header.cc
    test_deflate_params.cc
    test_deflate_pending.cc
    test_deflate_prime.cc
    test_deflate_quick_bi_valid.cc
    test_deflate_quick_block_open.cc
    test_deflate_tune.cc
    test_dict.cc
    test_inflate_adler32.cc
    test_inflate_sync.cc
    test_large_buffers.cc
    test_small_buffers.cc
    test_version.cc
    )

if(WITH_GZFILEOP)
    list(APPEND TEST_SRCS test_gzio.cc)
endif()

add_executable(gtest_zlib test_main.cc ${TEST_SRCS})

target_include_directories(gtest_zlib PRIVATE
    ${CMAKE_SOURCE_DIR}
    ${CMAKE_BINARY_DIR})

if(WITH_SANITIZER STREQUAL "Memory")
    target_link_directories(gtest_zlib PRIVATE $ENV{LLVM_BUILD_DIR}/lib)
    target_link_options(gtest_zlib PRIVATE
        -stdlib=libc++
        -lc++abi
        -fsanitize=memory
        -fsanitize-memory-track-origins)
endif()

if(ZLIB_DUAL_LINK AND NOT ZLIB_COMPAT)
    find_package(ZLIB)
    if(ZLIB_FOUND)
        message(STATUS "Added dual linking tests against zlib")
        message(STATUS "  Zlib include dir: ${ZLIB_INCLUDE_DIR}")
        message(STATUS "  Zlib libraries: ${ZLIB_LIBRARIES}")

        target_sources(gtest_zlib PRIVATE test_compress_dual.cc)
        target_include_directories(gtest_zlib PRIVATE ${ZLIB_INCLUDE_DIR})
        target_link_libraries(gtest_zlib ${ZLIB_LIBRARIES})
    else()
        message(WARNING "Zlib not found, skipping dual linking tests")
    endif()
endif()

target_link_libraries(gtest_zlib zlibstatic GTest::GTest)

find_package(Threads)
if(Threads_FOUND)
    target_sources(gtest_zlib PRIVATE test_deflate_concurrency.cc)
    if(UNIX AND NOT APPLE)
        # On Linux, use a workaround for https://gcc.gnu.org/bugzilla/show_bug.cgi?id=52590
        target_link_libraries(gtest_zlib -Wl,--whole-archive -lpthread -Wl,--no-whole-archive)
    endif()
    target_link_libraries(gtest_zlib Threads::Threads)
endif()

if(ZLIB_ENABLE_TESTS)
    add_test(NAME gtest_zlib
        COMMAND ${CMAKE_CROSSCOMPILING_EMULATOR} $<TARGET_FILE:gtest_zlib>)
endif()
