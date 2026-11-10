# quickai-whisper: whisper.cpp (the submodule whisper.cpp/, a release tag) and the program QuickAI talks to (src/).
cmake_minimum_required(VERSION 3.14)

file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/VERSION" QUICKAI_WHISPER_VERSION LIMIT_COUNT 1)
project(quickai-whisper VERSION ${QUICKAI_WHISPER_VERSION} LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if (NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "" FORCE)
endif()

# whisper.cpp as a library only, linked in, and without OpenMP (one dependency less)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(GGML_OPENMP OFF CACHE BOOL "" FORCE)

# The processors it runs on, never the one that builds it (GGML_NATIVE would make a program that stops on an older one).
# On x86-64 every instruction set is said here, as ggml turns AVX2 and its kin on by itself once GGML_NATIVE is off:
#   portable  SSE 4.2 and no further (x86-64-v2: every processor of the last fifteen years)
#   avx2      AVX, AVX2, FMA, F16C and BMI2 (Intel Haswell and AMD Excavator, 2013, and newer): two to three times as fast
# QuickAI runs quickai-whisper-avx2 where the processor has them, else quickai-whisper.
set(QUICKAI_WHISPER_CPU portable CACHE STRING "portable or avx2")
set(GGML_NATIVE OFF CACHE BOOL "" FORCE)
if (QUICKAI_WHISPER_CPU STREQUAL "avx2")
    set(_on ON)
elseif (QUICKAI_WHISPER_CPU STREQUAL "portable")
    set(_on OFF)
else()
    message(FATAL_ERROR "QUICKAI_WHISPER_CPU is portable or avx2, not ${QUICKAI_WHISPER_CPU}")
endif()
set(GGML_SSE42 ON CACHE BOOL "" FORCE)
foreach (_feature AVX AVX2 FMA F16C BMI2)
    set(GGML_${_feature} ${_on} CACHE BOOL "" FORCE)
endforeach()
foreach (_feature AVX_VNNI AVX512 AVX512_VBMI AVX512_VNNI AVX512_BF16 AMX_TILE AMX_INT8 AMX_BF16)
    set(GGML_${_feature} OFF CACHE BOOL "" FORCE)
endforeach()

add_subdirectory(whisper.cpp)

add_executable(quickai-whisper src/main.cpp)
target_link_libraries(quickai-whisper PRIVATE whisper)
target_compile_definitions(quickai-whisper PRIVATE QUICKAI_WHISPER_VERSION="${QUICKAI_WHISPER_VERSION}")
# the program's name: quickai-whisper, or the build's (quickai-whisper-avx2)
set(QUICKAI_WHISPER_NAME quickai-whisper CACHE STRING "the name of the program")
set_target_properties(quickai-whisper PROPERTIES OUTPUT_NAME "${QUICKAI_WHISPER_NAME}")

# the C and C++ runtimes linked in, so that the program needs nothing beside it: MinGW's DLLs on Windows, a libstdc++
# as new as the build's on Linux
option(QUICKAI_WHISPER_STATIC_RUNTIME "link the C++ runtime in" ON)
if (QUICKAI_WHISPER_STATIC_RUNTIME)
    if (MINGW)
        target_link_options(quickai-whisper PRIVATE -static)
    elseif (UNIX AND NOT APPLE)
        target_link_options(quickai-whisper PRIVATE -static-libstdc++ -static-libgcc)
    endif()
endif()

install(TARGETS quickai-whisper RUNTIME DESTINATION bin)
