#!/bin/bash

export DEVICE=H700
export PLATFORM=unix
export ARCH=arm64

export XTOOL="$HOME/x-tools"
export XHOST="aarch64-buildroot-linux-gnu-h700"
export XBIN="$XTOOL/$XHOST/bin"
export XHOSTP="aarch64-buildroot-linux-gnu"

export PATH="$XBIN:$PATH"

export SYSROOT="$XTOOL/$XHOST/$XHOSTP/sysroot"
export DESTDIR="$SYSROOT"

export CC="$XBIN/$XHOSTP-gcc"
export CXX="$XBIN/$XHOSTP-g++"
export AR="$XBIN/$XHOSTP-ar"
export LD="$XBIN/$XHOSTP-ld"
export STRIP="$XBIN/$XHOSTP-strip"

export LD_LIBRARY_PATH="$SYSROOT/usr/lib"

export CPP_FLAGS="--sysroot=$SYSROOT -I$SYSROOT/usr/include"
export LD_FLAGS="-L$SYSROOT -L$SYSROOT/lib -L$SYSROOT/usr/lib -L$SYSROOT/usr/local/lib"

export CPPFLAGS="$CPP_FLAGS"
export LDFLAGS="$LD_FLAGS"
export CFLAGS="-march=armv8-a+simd -mtune=cortex-a53 $CPP_FLAGS"
export CCFLAGS="$CPP_FLAGS"
export CXXFLAGS="$CPP_FLAGS"

export INC_DIR="$CPP_FLAGS"
export LIB_DIR="$LD_FLAGS"

export ARMABI="$XHOST"
export TOOLCHAIN_DIR="$XTOOL/$XHOST"

export PKG_CONFIG_LIBDIR="$SYSROOT/usr/lib/pkgconfig"
export PKG_CONFIG_PATH="$SYSROOT/usr/lib/pkgconfig"
export PKG_CONF_PATH="$XBIN/pkgconf"

export CROSS_COMPILE="$XBIN/$XHOSTP-"

export SDL_CONFIG="$SYSROOT/usr/bin/sdl-config"
export SDL2CONFIG="$SYSROOT/usr/bin/sdl2-config"
export FREETYPE_CONFIG="$SYSROOT/usr/bin/freetype-config"

export ALSA_CFLAGS="-I$SYSROOT/usr/include"
export ALSA_LIBS="-L$SYSROOT/usr/lib -lasound"

export MAGIC="/usr/share/file/magic.mgc"

echo "Device: $DEVICE"
echo "Cross Path: $XTOOL"
echo "Host: $XHOST"
echo "Binaries Path: $XBIN"
