#!/bin/sh

# Usage:
#   ./update_rootfs.sh <disk image> <rootfs image> [rootfs partition]
# Example:
#   ./update_rootfs.sh G350 G350-ROOTFS.img 2
# Defaults:
#   ROOTFS_PARTNUM=5

REPO_ROOT="${REPO_ROOT:-Repo/MustardOS}"
REPO_FRONTEND="${REPO_FRONTEND:-frontend}"
REPO_INTERNAL="${REPO_INTERNAL:-internal}"

ROOTFS_PARTNUM="${3:-5}"

REQUIRE_CMDS() {
	for CMD in "$@"; do
		if ! command -v "$CMD" >/dev/null 2>&1; then
			printf "Error: Missing required command '%s'\n" "$CMD" >&2
			exit 1
		fi
	done
}

GET_OFFSET_BYTES() {
	IMG="$1"
	PART="$2"

	START_BYTES="$(
		parted -sm "$IMG" unit B print 2>/dev/null |
			awk -F: -v P="$PART" '$1==P{gsub(/B/,"",$2); print $2}'
	)"
	if printf '%s' "$START_BYTES" | grep -Eq '^[0-9]+$'; then
		printf '%s' "$START_BYTES"
		return 0
	fi

	return 1
}

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
	printf "Usage: %s <image_dir> <rootfs_image> [partition_number]\n" "$0"
	exit 1
fi

REQUIRE_CMDS dd rsync pv zip mount umount

DIR="$1"
if [ ! -d "$DIR" ]; then
	printf "No valid image directory found at '%s'\n" "$DIR"
	exit 1
fi

ROOTFS=$2
if [ ! -f "$ROOTFS" ]; then
	printf "No valid RootFS found at '%s'\n" "$ROOTFS"
	exit 1
fi

IMG_TOTAL=$(find "$DIR" -maxdepth 1 -name '*.img' -type f | wc -l)
if [ "$IMG_TOTAL" -eq 0 ]; then
	printf "No image files found in '%s'\n" "$DIR"
	exit 1
fi

sudo -v

printf "\n=============== \033[1mRootFS Processing\033[0m ==============\n\n"
printf "\033[1mProcessing RootFS:\033[0m %s\n" "$ROOTFS"

MOUNT_POINT=$(mktemp -d)
if ! sudo mount -o loop,rw "$ROOTFS" "$MOUNT_POINT"; then
	printf "\t\033[1m- Failed to mount RootFS:\033[0m '%s' at '%s'\n" "$ROOTFS" "$MOUNT_POINT"
	rmdir "$MOUNT_POINT"
	exit 1
else
	printf "\t\033[1m- Mounted RootFS:\033[0m '%s' at '%s'\n" "$ROOTFS" "$MOUNT_POINT"
fi

BUILD_ID=$(git -C "$HOME/$REPO_ROOT/$REPO_INTERNAL" rev-parse --short HEAD)
printf "\t\033[1m- Using Build ID:\033[0m %s\n" "$BUILD_ID"

rm -rf "$MOUNT_POINT/opt/muos"
mkdir -p "$MOUNT_POINT/opt/muos"

printf "\t\033[1m- Updating MustardOS Internals\033[0m\n"
for I in bin browse config device frontend kiosk script share update; do
	rsync -a --info=progress2 \
		--exclude='.git/' \
		--exclude='.gitmodules' \
		--exclude='LICENSE' \
		--exclude='README.md' \
		--exclude='**/.gitkeep' \
		"$HOME/$REPO_ROOT/$REPO_INTERNAL/$I" "$MOUNT_POINT/opt/muos/"
done

printf "\n"

UPDATE_TASKS="
Frontend|$HOME/$REPO_ROOT/$REPO_FRONTEND/bin/|$MOUNT_POINT/opt/muos/frontend/
"

printf "%s" "$UPDATE_TASKS" | while IFS='|' read -r COMPONENT SRC DST; do
	# Skip over empty lines like the first and last ones. I like to keep things tidy!
	[ -z "$COMPONENT" ] || [ -z "$SRC" ] || [ -z "$DST" ] && continue

	printf "\t\033[1m- Updating MustardOS %s\033[0m\n" "$COMPONENT"
	rsync -a --info=progress2 \
		--exclude='.git/' \
		--exclude='.gitmodules' \
		--exclude='LICENSE' \
		--exclude='README.md' \
		--exclude='**/.gitkeep' \
		"$SRC" "$DST"
	printf "\n"
done

printf "\t\033[1m- Updating MustardOS Defaults\033[0m\n"

INFO_SHARE="$HOME/$REPO_ROOT/$REPO_INTERNAL/share/info"
ARCHIVES="
Init User Data|init|$HOME/$REPO_ROOT/$REPO_INTERNAL|$MOUNT_POINT/opt/muos/share/archive/muos.init.zip
RetroArch Configurations|config|$INFO_SHARE|$MOUNT_POINT/opt/muos/share/archive/ra.config.zip
Name Configurations|name|$INFO_SHARE|$MOUNT_POINT/opt/muos/share/archive/muos.name.zip
MustardOS Theme|.|$INFO_SHARE/../theme/active|$MOUNT_POINT/opt/muos/share/theme/MustardOS.muxthm
"

echo "$ARCHIVES" | while IFS='|' read -r DEF_NAME DEF_TYPE DEF_DIR DEF_ZIP; do
	[ -z "$DEF_NAME" ] && continue
	[ -z "$DEF_TYPE" ] && continue
	[ -z "$DEF_DIR" ] && continue
	[ -z "$DEF_ZIP" ] && continue

	SRC="$DEF_DIR/$DEF_TYPE"
	[ -d "$SRC" ] || {
		printf "\t  Skipping '%s': %s not found...\n" "$DEF_NAME" "$SRC"
		continue
	}

	mkdir -p "$(dirname "$DEF_ZIP")" || {
		printf "\t  Failed to create %s...\n" "$(dirname "$DEF_ZIP")"
		continue
	}

	printf "\t  Creating Archive of %s...\n" "$DEF_NAME"
	(cd "$DEF_DIR" && rm -f "$DEF_ZIP" && zip -q -r0 "$DEF_ZIP" "$DEF_TYPE") || {
		printf "\t\tFailed to create %s to %s\n" "$SRC" "$DEF_ZIP"
	}
done

printf "\n\t\033[1m- Removing Leftover Files\033[0m\n"
find "$MOUNT_POINT/opt/muos/." -name ".gitkeep" -delete

printf "\t\033[1m- Correcting File Permissions\033[0m\n"
sudo chmod -R 755 "$MOUNT_POINT/opt/muos"
sudo chown -R "$(whoami):$(whoami)" "$MOUNT_POINT/opt/muos"

printf "\t\033[1m- File Synchronisation\033[0m\n"
sync

printf "\t\033[1m- Unmounting Image\033[0m\n"
sudo umount "$MOUNT_POINT"
rmdir "$MOUNT_POINT"

printf "\t\033[1m- All Done!\033[0m\n"

printf "\n==========\033[1m RootFS Processing Complete \033[0m==========\n"

sudo -v

printf "\n===============\033[1m Image Processing \033[0m===============\n\n"

for IMG in "$DIR"/*.img; do
	[ -f "$IMG" ] || continue

	printf "\033[1mProcessing Image:\033[0m %s\n" "$IMG"

	DEVICE=$(printf '%s' "$IMG" | sed -n 's#.*MustardOS_\([^_]*\)_.*\.img$#\1#p')
	if [ -z "$DEVICE" ]; then
		printf "\t\033[1m- Failed to extract device name from image name\033[0m\n"
		continue
	else
		printf "\t\033[1m- Detected Device Type:\033[0m %s\n" "$DEVICE"
	fi

	printf "\t\033[1m- Copying RootFS:\033[0m '%s' to '%s'\n" "$ROOTFS" "$DEVICE.$ROOTFS"
	cp "$ROOTFS" "$DEVICE.$ROOTFS" && sync

	MOUNT_POINT=$(mktemp -d)
	if ! sudo mount -o loop,rw "$DEVICE.$ROOTFS" "$MOUNT_POINT"; then
		printf "\t\033[1m- Failed to mount RootFS:\033[0m '%s' at '%s'\n" "$DEVICE.$ROOTFS" "$MOUNT_POINT"
		rmdir "$MOUNT_POINT"
		continue
	else
		printf "\t\033[1m- Mounted RootFS:\033[0m '%s' at '%s'\n" "$DEVICE.$ROOTFS" "$MOUNT_POINT"
	fi

	printf "\t\033[1m- Removing Other Devices\033[0m\n"
	DEVICE_LOWER=$(printf "%s" "$DEVICE" | tr '[:upper:]' '[:lower:]')

	for DEV_DIR in "$MOUNT_POINT/opt/muos/device/"*/; do
		NAME=$(basename "$DEV_DIR")
		[ "$NAME" != "$DEVICE_LOWER" ] && rm -rf "$DEV_DIR"
	done

	mv "$MOUNT_POINT/opt/muos/device/$DEVICE_LOWER"/* "$MOUNT_POINT/opt/muos/device/"
	rm -rf "$MOUNT_POINT/opt/muos/device/$DEVICE_LOWER"

	printf "\t\033[1m- Confirmed Device Type:\033[0m %s\n" "$(cat "$MOUNT_POINT/opt/muos/device/config/board/name")"

	printf "\t\033[1m- Updating Build Identification\033[0m\n"
	printf "%s" "$BUILD_ID" >"$MOUNT_POINT/opt/muos/config/system/build"
	echo "$BUILD_ID" >"$DIR/buildID.txt"
	printf "\t\033[1m- Confirmed Build Identification:\033[0m %s\n" "$BUILD_ID"

	printf "\t\033[1m- Correcting File Permissions\033[0m\n"
	sudo chmod -R 755 "$MOUNT_POINT/opt/muos"
	sudo chown -R "$(whoami):$(whoami)" "$MOUNT_POINT/opt/muos"

	printf "\t\033[1m- File Synchronisation\033[0m\n"
	sync

	printf "\t\033[1m- Unmounting Image\033[0m\n"
	sudo umount "$MOUNT_POINT"
	rmdir "$MOUNT_POINT"

	sudo -v

	OFFSET_BYTES="$(GET_OFFSET_BYTES "$IMG" "$ROOTFS_PARTNUM")"

	if [ -z "$OFFSET_BYTES" ]; then
		printf "\t\033[1m- ERROR:\033[0m Could not determine offset for partition %s in %s\n" "$ROOTFS_PARTNUM" "$IMG" >&2
		printf "\n\t\033[1m- Removing RootFS:\033[0m \"%s\"\n" "$DEVICE.$ROOTFS"
		rm -f "$DEVICE.$ROOTFS"
		continue
	fi

	printf "\t\033[1m- Injecting modified RootFS\033[0m (part=%s, offset=%s bytes)\n" "$ROOTFS_PARTNUM" "$OFFSET_BYTES"
	pv "$DEVICE.$ROOTFS" | sudo dd of="$IMG" bs=12M oflag=seek_bytes seek="$OFFSET_BYTES" conv=notrunc,noerror,fsync status=none

	printf "\n\t\033[1m- Removing RootFS:\033[0m \"%s\"\n" "$DEVICE.$ROOTFS"
	rm -f "$DEVICE.$ROOTFS"

	printf "\t\033[1m- All Done!\033[0m\n\n"
	sudo -v
done

printf "==========\033[1m Image Processing Complete \033[0m===========\n\n"
