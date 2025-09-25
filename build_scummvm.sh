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

# ===== Settings =====
REPO_URL="https://github.com/scummvm/scummvm.git"
REPO_DIR="scummvm"
BRANCH="branch-2-9-1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="$SCRIPT_DIR/scummvm/output"

# ===== Init Toolchain =====
echo "[Step 01] Loading toolchain environment..."
echo ""
sleep 1

echo "Using toolchain script: $TOOLCHAIN_SCRIPT"
. "$TOOLCHAIN_SCRIPT"

# ===== Prerequisites =====
echo "[Step 02] Checking Prerequisites."
echo ""
sleep 1

# We need to explicitly point at Freetype2
export CFLAGS="$CFLAGS -I$SYSROOT/usr/include/freetype2"
export CXXFLAGS="$CXXFLAGS -I$SYSROOT/usr/include/freetype2"
export LDFLAGS="$LDFLAGS -L$SYSROOT/usr/lib"

# ===== Start =====
echo "[Step 03] Cloning ScummVM Repository..."
echo ""
sleep 1

if [ -d "$REPO_DIR/.git" ]; then
    echo "Repo already exists. Updating..."
    cd "$REPO_DIR"

    # Default branch to master if not set
    : "${BRANCH:=master}"

    git fetch --all
    git checkout "$BRANCH"
    git pull --rebase origin "$BRANCH"

    make clean || true
else

    echo "Cloning fresh repository..."
    git clone --progress --quiet --recurse-submodules -j"$(nproc)" -b "$BRANCH" "$REPO_URL" "$REPO_DIR"
    cd "$REPO_DIR"
fi

echo "[Step 04] Configuring ScummVM..."
echo ""
sleep 1

./configure \
  --host=arm-linux \
  --disable-debug \
  --enable-release \
  --disable-taskbar \
  --enable-vkeybd \
  --enable-text-console \
  --enable-ext-neon \
  --enable-dlc \
  --enable-scummvmdlc \
  --enable-freetype2 \
  --opengl-mode=gles2 \
  --with-sdl-prefix="$SYSROOT/usr/bin" \
  --with-freetype2-prefix="$SYSROOT/usr/bin" \
  --with-libcurl-prefix="$SYSROOT/usr"

echo "[Step 05] Building ScummVM..."
echo ""
sleep 1

make -j"$(nproc)"

echo "[Step 06] Preparing Binary for muOS."
echo ""
sleep 1

$STRIP "scummvm"
mv "scummvm" "$SVM_BIN"
md5sum "$SVM_BIN" | cut -d ' ' -f 1 > "$SVM_BIN.md5"

tar -czf "${SVM_BIN}.tar.gz" "$SVM_BIN"

echo "[Step 07] Bundling all required files..."
echo ""
sleep 1

# Copy Binary and Hash
mkdir -p "$OUT_DIR"
echo "Copying Binary and Hash"
cp -f "$SCRIPT_DIR/scummvm/${SVM_BIN}.tar.gz" "$OUT_DIR/${SVM_BIN}.tar.gz"
cp -f "$SCRIPT_DIR/scummvm/${SVM_BIN}.md5" "$OUT_DIR/${SVM_BIN}.md5"

# Copy Licenses
mkdir -p "$OUT_DIR/doc"
echo "Copying Licenses"
cp -f "$SCRIPT_DIR/scummvm/LICENSES/"* "$OUT_DIR/doc/"

# Copy Themes
mkdir -p "$OUT_DIR/Theme"
echo "Copying Themes"
cp -f "$SCRIPT_DIR/scummvm/gui/themes/"*.dat "$SCRIPT_DIR/scummvm/gui/themes/"*.zip "$OUT_DIR/Theme/"
cp -f "$SCRIPT_DIR/scummvm/dists/networking/wwwroot.zip" "$OUT_DIR/Theme/"

# Copy Extra
mkdir -p "$OUT_DIR/Extra"
echo "Copying Extra"
cp -f -r "$SCRIPT_DIR/scummvm/dists/engine-data/"* "$OUT_DIR/Extra/"
cp -f "$SCRIPT_DIR/scummvm/backends/vkeybd/packs/vkeybd_default.zip" "$OUT_DIR/Extra"

# ===== Cleanup =====
rm -f "$SCRIPT_DIR/scummvm/$SVM_BIN"
rm -f "$SCRIPT_DIR/scummvm/${SVM_BIN}.md5"
rm -f "$SCRIPT_DIR/scummvm/${SVM_BIN}.tar.gz"

# ===== Finish =====
echo "✅ Build complete."
echo "All files should now be available in $OUT_DIR"
