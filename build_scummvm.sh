#!/bin/sh

# shellcheck source=/dev/null

# ==== About ====
# ScummVM build script for MustardOS
# Created specifically for MustardOS 2508.0 Goose
# This assumes you have a Cross Compile environment setup with appropriate toolchains.

# Stop if any command fails
set -e

# ===== Device Info =====
DEVICE="$1"

# Set the appropriate toolchain script based on device selected
# Adjust paths to suit
case "$DEVICE" in
    h700)
        TOOLCHAIN_SCRIPT="$HOME/x-tools/h700-muos-cc.sh"
        SVM_BIN="scummvm-rg"
        ;;
    a133p)
        TOOLCHAIN_SCRIPT="$HOME/x-tools/a133p-muos-cc.sh"
        SVM_BIN="scummvm-tui"
        ;;
    rk3326)
        TOOLCHAIN_SCRIPT="$HOME/x-tools/rk3326-muos-cc.sh"
        SVM_BIN="scummvm-rk"
        ;;
    *)
        echo "Error: Unknown device '$DEVICE'. Supported: h700, a133p, rk3326"
        exit 1
        ;;
esac

echo "Using toolchain script: $TOOLCHAIN_SCRIPT"

# ===== Settings =====
REPO_URL="https://github.com/scummvm/scummvm.git"
BRANCH="branch-2-9-1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="$SCRIPT_DIR/scummvm/output"

# ===== Start =====
echo "[1/7] Cloning ScummVM Repository..."
rm -rf scummvm
if [ -z "$BRANCH" ]; then
    # Clone and Build master
    echo "No Branch specified - Cloning Master"
    git clone "$REPO_URL"
else
    # Clone and Build specific branch
    echo "Branch specified - Cloning $BRANCH"
    git clone -b "$BRANCH" --single-branch "$REPO_URL"
fi

cd scummvm

echo "[2/7] Loading toolchain environment..."
. "$TOOLCHAIN_SCRIPT"

echo "[3/7] Configuring ScummVM..."
./configure \
  --host=arm-linux \
  --disable-debug \
  --enable-release \
  --disable-taskbar \
  --disable-cloud \
  --enable-vkeybd \
  --enable-text-console \
  --opengl-mode=gles2 \
  --with-sdl-prefix="$SYSROOT/usr/bin"

echo "[4/7] Building ScummVM..."
make -j"$(nproc)"

echo "[5/7] Stripping ScummVM binary..."
$STRIP "scummvm"

echo "[6/7] Calculate MD5 and rename for MustardOS"
mv "scummvm" "$SVM_BIN"
md5sum "$SVM_BIN" | cut -d ' ' -f 1 > "$SVM_BIN.md5"

echo "[7/7] Bundling all required files..."

# Copy Binary and Hash
mkdir -p "$OUT_DIR"
echo "Copying Binary and Hash"
cp -f "$SCRIPT_DIR/scummvm/$SVM_BIN" "$OUT_DIR/$SVM_BIN"
cp -f "$SCRIPT_DIR/scummvm/$SVM_BIN.md5" "$OUT_DIR/$SVM_BIN.md5"

# Copy Licenses
mkdir -p "$OUT_DIR/doc"
echo "Copying Licenses"
cp -f "$SCRIPT_DIR/scummvm/LICENSES/"* "$OUT_DIR/doc/"

# Copy Themes
mkdir -p "$OUT_DIR/Theme"
echo "Copying Themes"
cp -f "$SCRIPT_DIR/scummvm/gui/themes/"*.dat "$SCRIPT_DIR/scummvm/gui/themes/"*.zip "$OUT_DIR/Theme/"

# Copy Extra
mkdir -p "$OUT_DIR/Extra"
echo "Copying Extra"
cp -f -r "$SCRIPT_DIR/scummvm/dists/engine-data/"* "$OUT_DIR/Extra/"

# ===== Finish =====
echo "✅ Build complete."
echo "All files should now be available in $OUT_DIR"
