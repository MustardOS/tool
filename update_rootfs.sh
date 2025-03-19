#!/bin/sh

REPO_ROOT="${REPO_ROOT:-Repo/MustardOS}"
REPO_FRONTEND="${REPO_FRONTEND:-frontend}"
REPO_INTERNAL="${REPO_INTERNAL:-internal}"
REPO_APPLICATION="${REPO_APPLICATION:-application}"
REPO_EMULATOR="${REPO_EMULATOR:-emulator}"

if [ "$#" -ne 2 ]; then
	printf "Usage: %s <image_dir> <rootfs_image>\n" "$0"
	exit 1
fi

for CMD in dd rsync; do
	if ! command -v "$CMD" >/dev/null 2>&1; then
		printf "Error: Missing required command '%s'\n" "$CMD" >&2
		exit 1
	fi
done

DIR=$1
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

printf "\t\033[1m- Updating muOS Internals\033[0m\n"
for I in bin browse config default device extra init script share; do
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
Frontend|$HOME/$REPO_ROOT/$REPO_FRONTEND/bin/|$MOUNT_POINT/opt/muos/extra/
Applications|$HOME/$REPO_ROOT/$REPO_APPLICATION/|$MOUNT_POINT/opt/muos/init/MUOS/application/
Emulators|$HOME/$REPO_ROOT/$REPO_EMULATOR/|$MOUNT_POINT/opt/muos/init/MUOS/emulator/
"

printf "%s" "$UPDATE_TASKS" | while IFS='|' read -r COMPONENT SRC DST; do
	# Skip over empty lines like the first and last ones. I like to keep things tidy!
	[ -z "$COMPONENT" ] || [ -z "$SRC" ] || [ -z "$DST" ] && continue

	printf "\t\033[1m- Updating muOS %s\033[0m\n" "$COMPONENT"
	rsync -a --info=progress2 \
		--exclude='.git/' \
		--exclude='.gitmodules' \
		--exclude='LICENSE' \
		--exclude='README.md' \
		--exclude='**/.gitkeep' \
		"$SRC" "$DST"
	printf "\n"
done

printf "\t\033[1m- Updating muOS Defaults\033[0m\n"

UPDATE_DEFAULTS="
info/config|$MOUNT_POINT/opt/muos/default/MUOS/info/config/
info/name|$MOUNT_POINT/opt/muos/default/MUOS/info/name/
retroarch|$MOUNT_POINT/opt/muos/default/MUOS/retroarch/
theme|$MOUNT_POINT/opt/muos/default/MUOS/theme/
"

echo "$UPDATE_DEFAULTS" | while IFS='|' read -r SUBDIR DST; do
	[ -z "$SUBDIR" ] || [ -z "$DST" ] && continue

	rsync -a --info=progress2 "$HOME/$REPO_ROOT/$REPO_INTERNAL/init/MUOS/$SUBDIR/" "$DST"
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

printf "\n==========\033[1m RootFS Processing Complete \033[0m==========\n"

sudo -v

printf "\n===============\033[1m Image Processing \033[0m===============\n\n"

for IMG in "$DIR"/*.img; do
	if [ -f "$IMG" ]; then
		printf "\033[1mProcessing Image:\033[0m %s\n" "$IMG"

		DEVICE=$(echo "$IMG" | sed -n 's/.*muOS-\([^-_]*-[^-_]*\).*\.img/\1/p')
		if [ -z "$DEVICE" ]; then
			printf "\t\033[1m- Failed to extract device name from image name\033[0m\n"
			continue
		else
			printf "\t\033[1m- Detected Device Type:\033[0m %s\n" "$DEVICE"
		fi

		MOUNT_POINT=$(mktemp -d)
		if ! sudo mount -o loop,rw "$ROOTFS" "$MOUNT_POINT"; then
			printf "\t\033[1m- Failed to mount RootFS:\033[0m '%s' at '%s'\n" "$ROOTFS" "$MOUNT_POINT"
			rmdir "$MOUNT_POINT"
			continue
		else
			printf "\t\033[1m- Mounted RootFS:\033[0m '%s' at '%s'\n" "$ROOTFS" "$MOUNT_POINT"
		fi

		printf "\t\033[1m- Updating Device Type\033[0m\n"
		echo "$DEVICE" | sudo tee "$MOUNT_POINT/opt/muos/config/device.txt" >/dev/null
		printf "\t\033[1m- Confirmed Device Type:\033[0m %s\n" "$(cat "$MOUNT_POINT/opt/muos/config/device.txt")"

		printf "\t\033[1m- Updating Version Information\033[0m\n"
		sed -i "2s/.*/$BUILD_ID/" "$MOUNT_POINT/opt/muos/config/version.txt" >/dev/null

		printf "\t\033[1m- Updating Build Identification\033[0m\n"
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

		printf "\t\033[1m- Injecting modified RootFS\033[0m\n"
		dd if="$ROOTFS" of="$IMG" bs=4M seek=39 conv=notrunc,noerror status=progress

		printf "\n"

		sudo -v
	fi
done

printf "==========\033[1m Image Processing Complete \033[0m===========\n\n"
