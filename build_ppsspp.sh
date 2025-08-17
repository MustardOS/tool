#!/bin/sh

# shellcheck source=/dev/null

# ==== About ====
# PPSSPP build script for MustardOS (H700)
# Created specifically for muOS 2508.0 Goose
# This assumes you have a Cross Compile environment setup with appropriate toolchains.

# Stop if any command fails
set -e

# ===== Device Info =====
DEVICENAME="$1"

# Set the appropriate toolchain script based on device selected
# Adjust paths to suit
case "$DEVICENAME" in
    h700)
        TOOLCHAIN_CMAKE="$HOME/x-tools/h700-muos-cc.cmake"
        TOOLCHAIN_SCRIPT="$HOME/x-tools/h700-muos-cc.sh"
        PPSSPP_BIN="PPSSPP-rg"
        ;;
    a133p)
        TOOLCHAIN_CMAKE="$HOME/x-tools/a133p-muos-cc.cmake"
        TOOLCHAIN_SCRIPT="$HOME/x-tools/a133p-muos-cc.sh"
        PPSSPP_BIN="PPSSPP-tui"
        ;;
    rk3326)
        TOOLCHAIN_CMAKE="$HOME/x-tools/rk3326-muos-cc.cmake"
        TOOLCHAIN_SCRIPT="$HOME/x-tools/rk3326-muos-cc.sh"
        PPSSPP_BIN="PPSSPP-rk"
        ;;
    *)
        echo "Error: Unknown device '$DEVICENAME'. Supported: h700, a133p, rk3326"
        exit 1
        ;;
esac

echo "Using toolchain: $TOOLCHAIN_CMAKE"

# ===== Settings =====
REPO_URL="https://github.com/hrydgard/ppsspp.git"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

PATCH_DIR="$SCRIPT_DIR/ppsspp-patches"

. "$TOOLCHAIN_SCRIPT"

# ===== Prerequisites ======
# Build Freetype

rm -rf freetype
git clone https://gitlab.freedesktop.org/freetype/freetype.git
cd freetype
mkdir build
cd build
cmake .. \
  -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_CMAKE" \
  -DCMAKE_INSTALL_PREFIX="$SYSROOT/usr"

make -j"$(nproc)"
make install

cd "$SCRIPT_DIR"

# Build SDL2_ttf
rm -rf SDL2_ttf
git clone -b release-2.20.2 https://github.com/libsdl-org/SDL_ttf.git SDL2_ttf
cd SDL2_ttf
mkdir build
cd build

cmake .. \
  -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_CMAKE" \
  -DCMAKE_INSTALL_PREFIX="$SYSROOT/usr" \
  -DFREETYPE_LIBRARY="$SYSROOT/usr/lib/libfreetype.so"

make -j"$(nproc)"
make install

cd "$SCRIPT_DIR"

# ===== Start =====
echo "[1/6] Cloning PPSSPP..."
rm -rf ppsspp
git clone --recursive "$REPO_URL"
cd ppsspp

echo "[2/6] Applying patch(es)..."
# Check if patch directory exists
if [ -d "$PATCH_DIR" ]; then
    # Loop over all patch files
    for PATCH_FILE in "$PATCH_DIR"/${DEVICENAME}*; do
        # Skip if no files match
        [ -f "$PATCH_FILE" ] || continue

        echo "Applying patch: $(basename "$PATCH_FILE")"
        patch -p1 < "$PATCH_FILE"
    done
else
    echo "Patch directory not found: $PATCH_DIR"
fi

echo "[3/6] Setting cmake options..."
mkdir build && cd build

# Probably need to tweak device specific build options
# Please help with this part.
case "$DEVICENAME" in
    h700)
        cmake .. \
            -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_CMAKE" \
            -DCMAKE_BUILD_TYPE=Release \
            -DUSING_EGL=ON \
            -DUSING_GLES2=ON \
            -DUSING_FBDEV=ON \
            -DCMAKE_DISABLE_FIND_PACKAGE_Vulkan=ON \
            -DCMAKE_DISABLE_FIND_PACKAGE_X11=ON \
            -DUSING_X11_VULKAN=OFF \
            -DUSING_X11=OFF \
            -DUSE_DISCORD=OFF \
            -DCMAKE_C_FLAGS_RELEASE="-O3 -mcpu=cortex-a53 -mtune=cortex-a53" \
            -DCMAKE_CXX_FLAGS_RELEASE="-O3 -mcpu=cortex-a53 -mtune=cortex-a53" \
            -DCMAKE_PREFIX_PATH="$SYSROOT/usr" \
            -Wno-dev
        ;;
    a133p)
        cmake .. \
            -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_CMAKE" \
            -DCMAKE_BUILD_TYPE=Release \
            -DUSING_EGL=ON \
            -DUSING_GLES2=ON \
            -DUSING_FBDEV=ON \
            -DCMAKE_DISABLE_FIND_PACKAGE_Vulkan=OFF \
            -DCMAKE_DISABLE_FIND_PACKAGE_X11=ON \
            -DUSING_X11_VULKAN=OFF \
            -DUSING_X11=OFF \
            -DUSE_DISCORD=OFF \
            -DCMAKE_C_FLAGS_RELEASE="-O3 -mcpu=cortex-a53 -mtune=cortex-a53" \
            -DCMAKE_CXX_FLAGS_RELEASE="-O3 -mcpu=cortex-a53 -mtune=cortex-a53" \
            -DCMAKE_PREFIX_PATH="$SYSROOT/usr" \
            -Wno-dev
        ;;
    rk3326)
        cmake .. \
            -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_CMAKE" \
            -DCMAKE_BUILD_TYPE=Release \
            -DUSING_EGL=ON \
            -DUSING_GLES2=ON \
            -DUSING_FBDEV=ON \
            -DCMAKE_DISABLE_FIND_PACKAGE_Vulkan=ON \
            -DCMAKE_DISABLE_FIND_PACKAGE_X11=ON \
            -DUSING_X11_VULKAN=OFF \
            -DUSING_X11=OFF \
            -DUSE_DISCORD=OFF \
            -DCMAKE_C_FLAGS_RELEASE="-O3 -mcpu=cortex-a53 -mtune=cortex-a53" \
            -DCMAKE_CXX_FLAGS_RELEASE="-O3 -mcpu=cortex-a53 -mtune=cortex-a53" \
            -DCMAKE_PREFIX_PATH="$SYSROOT/usr" \
            -Wno-dev
        ;;
    *)
        exit 1
    ;;
esac


echo "[4/6] Building PPSSPP..."
make -j"$(nproc)"

echo "[5/6] Stripping Binary..."
$STRIP PPSSPPSDL

echo "[6/6] Calculate MD5 and rename for muOS"
mv "PPSSPPSDL" "$PPSSPP_BIN"
md5sum "$PPSSPP_BIN" | cut -d ' ' -f 1 > "$PPSSPP_BIN.md5"

echo "✅ Build complete."
echo "$PPSSPP_BIN and $PPSSPP_BIN.md5 have been created in $SCRIPT_DIR/ppsspp/build."
