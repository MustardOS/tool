#!/bin/sh

# shellcheck source=/dev/null

# ==== About ====
# Retroarch build script for MustardOS
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
        RA_BIN="retroarch-rg"
        ;;
    a133p)
        TOOLCHAIN_SCRIPT="$HOME/x-tools/a133p-muos-cc.sh"
        RA_BIN="retroarch-tui"
        ;;
    rk3326)
        TOOLCHAIN_SCRIPT="$HOME/x-tools/rk3326-muos-cc.sh"
        RA_BIN="retroarch-rk"
        ;;
    *)
        echo "Error: Unknown device '$DEVICE'. Supported: h700, a133p, rk3326"
        exit 1
        ;;
esac

echo "Using toolchain script: $TOOLCHAIN_SCRIPT"

# ===== Settings =====
REPO_URL="https://github.com/libretro/RetroArch.git"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# We patch Ozone to better scale on small screens (maybe other things?)
# Assumes patches lives in "retroarch-patches" folder in script directory.
PATCH_DIR="$SCRIPT_DIR/retroarch-patches"

# ===== Start =====
echo "[1/8] Cloning RetroArch..."
rm -rf RetroArch
git clone "$REPO_URL"
cd RetroArch

echo "[2/8] Loading toolchain environment..."
. "$TOOLCHAIN_SCRIPT"

echo "[3/8] Applying patch..."
# Check if patch directory exists
if [ -d "$PATCH_DIR" ]; then
    # Loop over all patch files
    for PATCH_FILE in "$PATCH_DIR"/*.patch; do
        # Skip if no files match
        [ -f "$PATCH_FILE" ] || continue

        echo "Applying patch: $(basename "$PATCH_FILE")"
        patch -p1 < "$PATCH_FILE"
    done
else
    echo "Patch directory not found: $PATCH_DIR"
fi

echo "[4/8] Configuring RetroArch..."
./configure \
  --enable-xdelta \
  --enable-sdl2 \
  --enable-udev \
  --disable-glslang \
  --disable-nvda \
  --disable-materialui \
  --disable-systemd \
  --disable-x11 \
  --disable-xrandr \
  --disable-xinerama \
  --disable-wayland \
  --disable-cdrom \
  --enable-libshake \
  --disable-crtswitchres \
  --enable-hid \
  --disable-vulkan \
  --disable-qt \
  --disable-pulse \
  --disable-oss \
  --enable-alsa \
  --enable-pipewire \
  --enable-command \
  --enable-threads \
  --enable-bluetooth \
  --disable-parport \
  --enable-opengles

echo "[5/8] Fixing include/lib paths..."
sed -i s#/usr/include#"$SYSROOT"/usr/include#g config.mk
sed -i s#/usr/lib#"$SYSROOT"/usr/lib#g config.mk

echo "[6/8] Building RetroArch..."
make -j"$(nproc)"

echo "[7/8] Stripping Retroarch binary..."
$STRIP "retroarch"

echo "[8/8] Calculate MD5 and rename for MustardOS"
mv "retroarch" "$RA_BIN"
md5sum "$RA_BIN" | cut -d ' ' -f 1 > "$RA_BIN.md5"

echo "✅ Build complete."
echo "$RA_BIN and $RA_BIN.md5 have been created in $SCRIPT_DIR/Retroarch."
