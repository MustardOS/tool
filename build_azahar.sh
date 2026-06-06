#!/bin/sh

# shellcheck source=/dev/null

# ==== About ====
# Azahar (Nintendo 3DS) build script for MustardOS / muOS
# Vulkan-primary standalone build. Mirrors build_ppsspp.sh.
# Assumes a cross-compile toolchain is set up (see $HOME/dev/x-tools).

# Stop if any command fails
set -e

# ===== Args =====
# Usage: ./build_azahar.sh <device> [git-ref]
# git-ref defaults to the commit the azahar-patches suite is based on.
DEVICENAME="$1"
GITREF="${2:-308a9b14e}"   # base commit the patch suite applies cleanly to

# Set the appropriate toolchain script based on device selected
case "$DEVICENAME" in
    rk3576)
        TOOLCHAIN_CMAKE="$HOME/dev/x-tools/rk3576-muos-cc.cmake"
        TOOLCHAIN_SCRIPT="$HOME/dev/x-tools/rk3576-muos-cc.sh"
        AZAHAR_BIN="Azahar-vita"
        # RK3576 = 4x Cortex-A72 + 4x Cortex-A53, Mali-G52. Vulkan via VK_KHR_display.
        # Arch tuning only. These go into CMAKE_C/CXX_FLAGS (additive), so Azahar's Release config
        # still supplies "-O3 -DNDEBUG" — do NOT set CMAKE_*_FLAGS_RELEASE (that replaces the
        # defaults and would drop -DNDEBUG, leaving asserts in hot paths -> major slowdown).
        CPU_FLAGS="-march=armv8-a+simd -mtune=cortex-a72 -fomit-frame-pointer -fstrict-aliasing"
        ;;
    *)
        echo "Error: Unknown/unsupported device '$DEVICENAME'. Supported: rk3576"
        exit 1
        ;;
esac

echo "Device:    $DEVICENAME"
echo "Git ref:   $GITREF"
echo "Toolchain: $TOOLCHAIN_CMAKE"

# ===== Settings =====
REPO_URL="https://github.com/azahar-emu/azahar.git"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="$SCRIPT_DIR/azahar/output/"
PATCH_DIR="$SCRIPT_DIR/azahar-patches"
BUILD_DIR="build-$DEVICENAME"

. "$TOOLCHAIN_SCRIPT"

# ===== 01 Clone Azahar =====
echo "[Step 01] Cloning Azahar at $GITREF ..."
if [ -d "azahar/.git" ]; then
    echo "Updating existing Azahar clone..."
    cd azahar
    git reset --hard
    git clean -fd
    git fetch origin
    git checkout "$GITREF"
    git submodule update --init --recursive
else
    echo "Cloning Azahar..."
    git clone "$REPO_URL" azahar
    cd azahar
    git checkout "$GITREF"
    git submodule update --init --recursive
fi

# ===== 02 Apply patches =====
echo "[Step 02] Applying patch(es)..."
if [ -d "$PATCH_DIR" ]; then
    # Numbered patches only (skips README.md and knulli-reference/).
    for PATCH_FILE in "$PATCH_DIR"/0*.patch; do
        [ -f "$PATCH_FILE" ] || continue
        echo "Applying patch: $(basename "$PATCH_FILE")"
        git apply "$PATCH_FILE"
    done
else
    echo "Patch directory not found: $PATCH_DIR"
    exit 1
fi

# ===== 03 Setup CMake =====
echo "[Step 03] Setting cmake options..."
rm -rf "$BUILD_DIR"
case "$DEVICENAME" in
    rk3576)
        cmake -S . -B "$BUILD_DIR" -G Ninja \
            -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_CMAKE" \
            -DCMAKE_BUILD_TYPE=Release \
            -DENABLE_QT=OFF \
            -DENABLE_SDL2=ON \
            -DENABLE_SDL2_FRONTEND=ON \
            -DUSE_SYSTEM_SDL2=ON \
            -DENABLE_VULKAN=ON \
            -DENABLE_OPENGL=ON \
            -DENABLE_SOFTWARE_RENDERER=ON \
            -DENABLE_WEB_SERVICE=OFF \
            -DENABLE_LIBUSB=OFF \
            -DENABLE_TESTS=OFF \
            -DENABLE_OPENAL=OFF \
            -DENABLE_ROOM_STANDALONE=OFF \
            -DUSE_DISCORD_PRESENCE=OFF \
            -DENABLE_SCRIPTING=OFF \
            -DENABLE_LTO=OFF \
            -DENABLE_NATIVE_OPTIMIZATION=OFF \
            -DCITRA_WARNINGS_AS_ERRORS=OFF \
            -DCMAKE_C_FLAGS="$CPU_FLAGS" \
            -DCMAKE_CXX_FLAGS="$CPU_FLAGS" \
            -Wno-dev
        ;;
    *)
        exit 1
        ;;
esac

# ===== 04 Build Azahar =====
echo "[Step 04] Building Azahar..."
ninja -C "$BUILD_DIR" citra_meta

# ===== 05 Cleanup the binary =====
echo "[Step 05] Prepare the resultant binary"
BIN_PATH="$BUILD_DIR/bin/Release/azahar"

# Strip binary
"$STRIP" "$BIN_PATH"

# Rename + checksum
cp -f "$BIN_PATH" "$BUILD_DIR/$AZAHAR_BIN"
md5sum "$BUILD_DIR/$AZAHAR_BIN" | cut -d ' ' -f 1 > "$BUILD_DIR/$AZAHAR_BIN.md5"

# Compress binary for use in muOS
tar -czf "$BUILD_DIR/${AZAHAR_BIN}.tar.gz" -C "$BUILD_DIR" "$AZAHAR_BIN"
rm -f "$BUILD_DIR/$AZAHAR_BIN"

# ===== 06 Package =====
echo "[Step 06] Package Azahar files for use in muOS"
mkdir -p "$OUT_DIR"
cp -f "$BUILD_DIR/${AZAHAR_BIN}.tar.gz" "$OUT_DIR"
cp -f "$BUILD_DIR/${AZAHAR_BIN}.md5" "$OUT_DIR"

# ===== Finish =====
cd "$SCRIPT_DIR"
echo "✅ Build complete."
echo "All files have been placed in $OUT_DIR"
