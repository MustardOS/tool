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

REPO_URL="https://github.com/gonetz/GLideN64.git"
REPO_DIR="$SCRIPT_DIR/mupen64plus-video-GlideN64"
PATCH_DIR="$SCRIPT_DIR/mp64-patches"
REPO_NAME="mupen64plus-video-gliden64"

echo "[1/8] Cloning mupen64plus-video-gliden64..."
rm -rf "$REPO_DIR"
git clone "$REPO_URL" "$REPO_DIR"

echo "[2/8] Loading toolchain environment..."
. "$TOOLCHAIN_SCRIPT"

if [[ "$DEVICE" == "rk3326" ]]; then
  : "${CPU_TUNE:=cortex-a35}"
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

echo "[4/8] Configuring Building mupen64plus-video-gliden64"

: "${CFLAGS:=}"
: "${CXXFLAGS:=}"
: "${LDFLAGS:=}"

export CFLAGS="-march=armv8-a+crc -mtune=${CPU_TUNE} -fuse-linker-plugin ${CFLAGS}"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="${LDFLAGS:+$LDFLAGS }-flto=$(nproc) -fuse-linker-plugin"

(cd "$REPO_DIR" && ./src/getRevision.sh)
cmake -DNOHQ=On -DCRC_ARMV8=On -DEGL=On -DNEON_OPT=On -DMUPENPLUSAPI=On \
  -DCMAKE_C_FLAGS:STRING="-march=armv8-a+crc -mtune=${CPU_TUNE} -O3 -fuse-linker-plugin" \
  -DCMAKE_CXX_FLAGS:STRING="-march=armv8-a+crc -mtune=${CPU_TUNE} -O3 -fuse-linker-plugin" \
  -DCMAKE_SHARED_LINKER_FLAGS:STRING="-flto=$(nproc) -fuse-linker-plugin" \
  -DCMAKE_EXE_LINKER_FLAGS:STRING="-flto=$(nproc) -fuse-linker-plugin" \
  -S "$REPO_DIR/src" -B "$REPO_DIR/projects/cmake"

make -C "$REPO_DIR/projects/cmake" clean
make -j"$(nproc)" -C "$REPO_DIR/projects/cmake" V=1

echo "[6/8] Stripping mupen64plus-video-gliden64 binary..."
$STRIP "$REPO_DIR/projects/cmake/plugin/Release/mupen64plus-video-GLideN64.so" || true

echo "[7/8] Move Binary to mupen64plussa"
mkdir -p "$SCRIPT_DIR/mupen64plussa/$MP_BIN"
cp -v "$REPO_DIR/projects/cmake/plugin/Release/mupen64plus-video-GLideN64.so" "$SCRIPT_DIR/mupen64plussa/$MP_BIN/."

echo "[8/8] Build complete."