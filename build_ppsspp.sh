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
OUT_DIR="$SCRIPT_DIR/ppsspp/output/"

PATCH_DIR="$SCRIPT_DIR/ppsspp-patches"

. "$TOOLCHAIN_SCRIPT"

# ===== Commit Information =====
# Master - leave blank
# 1.19.3 - e49c0bd
# 1.18.1 - 0f50225
# 1.17.1 - d479b74

COMMIT=""

# ===== Prerequisites ======
# Build Freetype
# We currently don't check toolchain to see if this step is needed.

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

# Build SDL2_ttf 2.20.2
# We currently don't check toolchain to see if this step is needed.

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

# ===== Start PPSSPP Build Process =====
# ===== 01 Clone PPSSPP =====

echo "[Step 01] Cloning PPSSPP..."
rm -rf ppsspp
if [ -z "$COMMIT" ]; then
    # Clone and Build master
    echo "No commit specified - Cloning Master"
    git clone --recursive "$REPO_URL"
    cd ppsspp
else
    # Clone and Build specific branch
    # This step may require additional work depending on which commit is building.
    echo "Commit specified - Cloning $COMMIT"
    git clone --recursive "$REPO_URL"
    cd ppsspp
    git checkout "$COMMIT"
    git submodule update --init --recursive
fi

# ===== 02 Apply PPSSPP patches =====

echo "[Step 02] Applying patch(es)..."
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

# ===== 03 Setup CMAKE =====

echo "[Step 03] Setting cmake options..."
mkdir build && cd build

# Further work may be required to optimise different device build options
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
            -DCMAKE_BUILD_TYPE=Release \
            -DBUILD_SHARED_LIBS=OFF \
            -DARM=ON \
            -DARM64=ON \
            -DUSING_GLES2=ON \
            -DUSING_EGL=ON \
            -DUSING_FBDEV=ON \
            -DVULKAN=OFF \
            -DARM_NO_VULKAN=ON \
            -DUSING_X11_VULKAN=OFF \
            -DUSE_WAYLAND_WSI=OFF \
            -DUSE_FFMPEG=ON \
            -DUSE_SYSTEM_FFMPEG=OFF \
            -DUSE_DISCORD=OFF \
            -DANDROID=OFF -DWIN32=OFF -DAPPLE=OFF \
            -DUNITTEST=OFF -DSIMULATOR=OFF \
            -DMOBILE_DEVICE=OFF -DENABLE_CTEST=OFF \
            -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_CMAKE" \
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
            -DCMAKE_C_FLAGS_RELEASE="-O3 -mcpu=cortex-a35 -mtune=cortex-a35 -fomit-frame-pointer -fstrict-aliasing" \
            -DCMAKE_CXX_FLAGS_RELEASE="-O3 -mcpu=cortex-a35 -mtune=cortex-a35 -fomit-frame-pointer -fstrict-aliasing" \
            -DCMAKE_PREFIX_PATH="$SYSROOT/usr" \
            -Wno-dev
        ;;
    *)
        exit 1
    ;;
esac

# ===== 04 Make PPSSPP =====

echo "[Step 04] Building PPSSPP..."
make -j"$(nproc)"

# ===== 05 Cleanup the binary =====

echo "[Step 05] Prepare the resultant binary"

# Strip binary
$STRIP PPSSPPSDL

# Calculate MD5 and rename
mv "PPSSPPSDL" "$PPSSPP_BIN"
md5sum "$PPSSPP_BIN" | cut -d ' ' -f 1 > "$PPSSPP_BIN.md5"

# Compress binary for use in muOS
cd "$SCRIPT_DIR"
tar -czf "$SCRIPT_DIR/ppsspp/build/${PPSSPP_BIN}.tar.gz" -C ppsspp/build "$PPSSPP_BIN"
rm "$SCRIPT_DIR/ppsspp/build/$PPSSPP_BIN"

# ===== 06 Package PPSSPP =====

echo "[Step 06] Package PPSSPP files for use in muOS"

mkdir -p "$OUT_DIR"
rsync -a --exclude=debugger ppsspp/assets/ "$OUT_DIR"
cp -f $SCRIPT_DIR/ppsspp/build/${PPSSPP_BIN}.* "$OUT_DIR"

# ===== Finish =====

echo "✅ Build complete."
echo "All files have been placed in $OUT_DIR"
