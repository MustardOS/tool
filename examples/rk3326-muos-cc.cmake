# rk3326-muos-cc.cmake

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

# Absolute path to toolchain root (adjust to your real path)
set(TOOLCHAIN_PATH "/home/antikk/x-tools/aarch64-buildroot-linux-gnu-rk3326")

# Compilers
set(CMAKE_C_COMPILER   ${TOOLCHAIN_PATH}/bin/aarch64-buildroot-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER ${TOOLCHAIN_PATH}/bin/aarch64-buildroot-linux-gnu-g++)
set(CMAKE_ASM_COMPILER ${TOOLCHAIN_PATH}/bin/aarch64-buildroot-linux-gnu-gcc)

# Sysroot
set(CMAKE_SYSROOT ${TOOLCHAIN_PATH}/aarch64-buildroot-linux-gnu/sysroot)

set(CMAKE_FIND_ROOT_PATH ${CMAKE_SYSROOT})

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
