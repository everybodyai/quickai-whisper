# CMake's toolchain for Windows x86_64 with MinGW-w64 (POSIX threads), for build/windows.sh.
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR x86_64)
set(CMAKE_C_COMPILER x86_64-w64-mingw32-gcc-posix)
set(CMAKE_CXX_COMPILER x86_64-w64-mingw32-g++-posix)
set(CMAKE_RC_COMPILER x86_64-w64-mingw32-windres)
set(CMAKE_FIND_ROOT_PATH /usr/x86_64-w64-mingw32)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
# MinGW's headers name Windows 8's thread power throttling only in part, which ggml uses from Windows 8's interface on:
# it is built for Windows 7's (0x0601), which leaves that hint out and runs the same on Windows 10 and 11
set(CMAKE_C_FLAGS_INIT "-D_WIN32_WINNT=0x0601")
set(CMAKE_CXX_FLAGS_INIT "-D_WIN32_WINNT=0x0601")
