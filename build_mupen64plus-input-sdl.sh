#!/bin/bash
set -euo pipefail

DEVICE="$1"

case "$DEVICE" in
  h700)
    TOOLCHAIN_SCRIPT="$HOME/x-tools/h700-muos-cc.sh"
    MP_BIN="rg"
    ;;
  a133p)
    TOOLCHAIN_SCRIPT="$HOME/x-tools/a133p-muos-cc.sh"
    MP_BIN="tui"
    ;;
  rk3326)
    TOOLCHAIN_SCRIPT="$HOME/x-tools/rk3326-muos-cc.sh"
    MP_BIN="rk"
    ;;
  *)
    echo "Error: Unknown device '$DEVICE'. Supported: h700, a133p, rk3326" >&2
    exit 1
    ;;
esac

# Fix working base to the script directory (tool)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

REPO_URL="https://github.com/mupen64plus/mupen64plus-input-sdl.git"
REPO_DIR="$SCRIPT_DIR/mupen64plus-input-sdl"
PATCH_DIR="$SCRIPT_DIR/mp64-patches"
REPO_NAME="$(basename "$REPO_DIR")"

echo "[1/8] Cloning mupen64plus-input-sdl..."
rm -rf "$REPO_DIR"
git clone "$REPO_URL" "$REPO_DIR"

echo "[2/8] Loading toolchain environment..."
. "$TOOLCHAIN_SCRIPT"

if [[ "$DEVICE" == "a133p" ]]; then
  : "${CPU_TUNE:=cortex-a55}"
else
  : "${CPU_TUNE:=cortex-a53}"
fi

# Ensure toolchain PATH and triplet pkg-config wrapper
export PATH="$XBIN:$PATH"
ln -sf pkg-config "$XBIN/${XHOSTP}-pkg-config" 2>/dev/null || ln -sf pkgconf "$XBIN/${XHOSTP}-pkg-config"
export PKG_CONFIG_SYSROOT_DIR="$SYSROOT"
export PKG_CONFIG_LIBDIR="$SYSROOT/usr/lib/pkgconfig:$SYSROOT/usr/share/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_LIBDIR"

echo "[3/8] Applying patch..."
# apply only patches that start with repo name

if [ -d "$PATCH_DIR" ]; then
  for PATCH_FILE in "$PATCH_DIR/$REPO_NAME"*.patch; do
    [ -f "$PATCH_FILE" ] || continue
    (cd "$REPO_DIR" && patch -p1 < "$PATCH_FILE") || { echo "Error applying $(basename "$PATCH_FILE")"; exit 1; }
  done
else
  echo "Patch directory not found: $PATCH_DIR"
fi

echo "[4/8] Configuring Building mupen64plus-input-sdl"

# Keep a53 base; append LTO only
export CFLAGS="-march=armv8-a+crc -mtune=${CPU_TUNE} -fuse-linker-plugin ${CFLAGS:-}"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="${LDFLAGS:+$LDFLAGS }-flto=$(nproc) -fuse-linker-plugin"

# Run make from tool with inline env (robust option passing)
VULKAN=0 USE_GLES=1 NEW_DYNAREC=1 OPTFLAGS="-O3" V=1 PIE=1 ACCURATE_FPU=1 HOST_CPU=aarch64 GL_CFLAGS="" GL_LDLIBS="-lEGL -lGLESv2" PKG_CONFIG="aarch64-buildroot-linux-gnu-pkg-config" SDL_CONFIG="aarch64-buildroot-linux-gnu-sdl2-config" \
make -C "mupen64plus-input-sdl/projects/unix" clean

VULKAN=0 USE_GLES=1 NEW_DYNAREC=1 OPTFLAGS="-O3" V=1 PIE=1 ACCURATE_FPU=1 HOST_CPU=aarch64 GL_CFLAGS="" GL_LDLIBS="-lEGL -lGLESv2" PKG_CONFIG="aarch64-buildroot-linux-gnu-pkg-config" SDL_CONFIG="aarch64-buildroot-linux-gnu-sdl2-config" \
make -C "mupen64plus-input-sdl/projects/unix" -j"$(nproc)" all

echo "[6/8] Stripping mupen64plus-input-sdl binary..."
$STRIP "mupen64plus-input-sdl/projects/unix/mupen64plus-input-sdl.so" || true

echo "[7/8] Move Binary to mupen64plussa"
mkdir -p "$SCRIPT_DIR/mupen64plussa/$MP_BIN"
cp -v "mupen64plus-input-sdl/projects/unix/mupen64plus-input-sdl.so" "$SCRIPT_DIR/mupen64plussa/$MP_BIN/."

echo "[8/8] Build complete."