#!/bin/sh

for CMD in jq dtc dragonsecboot fdisk unpackbootimg mkbootimg; do
	if ! command -v "$CMD" >/dev/null 2>&1; then
		printf "Error: Missing required command '%s'\n" "$CMD" >&2
		exit 1
	fi
done

MODE="$1"
DEVICE="$2"
IMAGE="$3"

JSON="$PWD/device.json"

[ -z "$MODE" ] || [ -z "$DEVICE" ] && {
	printf "Usage: %s <extract | build | unpack | rebuild | inject | mount> <device> [image.img]\n\n" "$0"
	exit 1
}

cd "$PWD/$DEVICE" || exit 1
[ ! -f "$JSON" ] && {
	printf "Missing 'device.json' file\n\n"
	exit 1
}

case "$MODE" in
	extract)
		printf "\n=============== Extracting Boot Package ===============\n\n"

		UBOOT_HEX=$(jq -r --arg dev "$DEVICE" '.[] | select(.device == $dev) | .offsets.uboot' "$JSON")
		MONITOR_HEX=$(jq -r --arg dev "$DEVICE" '.[] | select(.device == $dev) | .offsets.monitor' "$JSON")
		P1_HEX=$(jq -r --arg dev "$DEVICE" '.[] | select(.device == $dev) | .offsets.p1' "$JSON")
		SUNXI_HEX=$(jq -r --arg dev "$DEVICE" '.[] | select(.device == $dev) | .offsets.sunxi' "$JSON")

		UBOOT_DEC=$((UBOOT_HEX))
		MONITOR_DEC=$((MONITOR_HEX))
		P1_DEC=$((P1_HEX))
		SUNXI_DEC=$((SUNXI_HEX))

		dd if="boot_package.fex" of="u-boot.fex" skip="$UBOOT_DEC" count="$((MONITOR_DEC - UBOOT_DEC))" bs=1
		dd if="boot_package.fex" of="monitor.fex" skip="$MONITOR_DEC" count="$((P1_DEC - MONITOR_DEC))" bs=1
		dd if="boot_package.fex" of="p1.dtbo" skip="$P1_DEC" count="$((SUNXI_DEC - P1_DEC))" bs=1
		dd if="boot_package.fex" of="sunxi.fex" skip="$SUNXI_DEC" bs=1

		dtc -I dtb -O dts -o "sunxi.dts" "sunxi.fex"
		printf "\nBoot package components extracted successfully.\n\n"
		;;

	build)
		printf "\n=============== Building Boot Package ===============\n\n"

		rm -f "boot_package.fex"
		dtc -I dts -O dtb -o "sunxi.fex" "sunxi.dts"

		printf "Packing boot package...\n"
		dragonsecboot -pack "boot_package.cfg"
		rm -f "$TMP_CFG"

		printf "\nBoot package built successfully.\n\n"
		;;

	unpack)
		[ ! -f "$IMAGE" ] && {
			printf "Error: image file '%s' not found\n" "$IMAGE"
			exit 1
		}

		LINE=$(fdisk -x "$IMAGE" | grep -i " boot ")
		START=$(printf "%s" "$LINE" | awk '{print $2}')
		SECTOR=$(printf "%s" "$LINE" | awk '{print $4}')

		printf "\n=============== Unpacking Boot Image ===============\n\n"
		mkdir -p tmp_boot
		dd if="$IMAGE" of=./tmp_boot/boot.img bs=512 skip="$START" count="$SECTOR" status=progress

		printf "\n"

		cd tmp_boot || exit 1
		mkdir -p boot
		unpackbootimg -i boot.img -o boot

		printf "\nUnpacked boot image. Modify ramdisk or dtb as needed in 'tmp_boot/boot'\n"
		printf "Then run: ./boot_tool.sh rebuild %s\n\n" "$DEVICE"
		;;

	rebuild)
		BOOTDIR="$PWD/tmp_boot/boot"
		[ ! -d "$BOOTDIR" ] && {
			printf "Boot directory not found. Run unpack first.\n\n"
			exit 1
		}

		cd "$BOOTDIR" || exit 1

		for FIELD in cmdline base name pagesize kernel_offset ramdisk_offset second_offset tags_offset; do
			FIELD_UPPER=$(printf "%s" "$FIELD" | tr '[:lower:]' '[:upper:]')
			VALUE=$(grep -i "BOARD_${FIELD_UPPER}" boot.img-* 2>/dev/null | awk '{$1=""; print substr($0,2)}')

			[ -z "$VALUE" ] && VALUE=$(jq -r --arg dev "$DEVICE" --arg key "$FIELD" \
				'.[] | select(.device == $dev) | .config[$key]' "$JSON")

			case "$FIELD_UPPER" in
				CMDLINE) BOARD_CMDLINE="$VALUE" ;;
				BASE) BOARD_BASE="$VALUE" ;;
				NAME) BOARD_NAME="$VALUE" ;;
				PAGESIZE) BOARD_PAGESIZE="$VALUE" ;;
				KERNEL_OFFSET) BOARD_KERNEL_OFFSET="$VALUE" ;;
				RAMDISK_OFFSET) BOARD_RAMDISK_OFFSET="$VALUE" ;;
				SECOND_OFFSET) BOARD_SECOND_OFFSET="$VALUE" ;;
				TAGS_OFFSET) BOARD_TAGS_OFFSET="$VALUE" ;;
			esac
		done

		printf "\n=============== Rebuilding Boot Image ===============\n\n"
		[ -f "boot.img-dtb" ] && DT_ARGS="--dt boot.img-dtb " || DT_ARGS=""

		printf "mkbootimg"
		printf " --kernel boot.img-zImage"
		printf " --ramdisk boot.img-ramdisk.gz"
		printf " --board %s" "$BOARD_NAME"
		printf " --base %s" "$BOARD_BASE"
		printf " --kernel_offset %s" "$BOARD_KERNEL_OFFSET"
		printf " --ramdisk_offset %s" "$BOARD_RAMDISK_OFFSET"
		printf " --second_offset %s" "$BOARD_SECOND_OFFSET"
		printf " --tags_offset %s" "$BOARD_TAGS_OFFSET"
		printf " --pagesize %s" "$BOARD_PAGESIZE"
		printf " --cmdline \"%s\"" "$BOARD_CMDLINE"
		[ -f "boot.img-dtb" ] && printf " --dt boot.img-dtb"
		printf " -o ../rebuilt-boot.img\n"

		mkbootimg \
			--kernel boot.img-zImage \
			--ramdisk boot.img-ramdisk.gz \
			--board "$BOARD_NAME" \
			--base "$BOARD_BASE" \
			--kernel_offset "$BOARD_KERNEL_OFFSET" \
			--ramdisk_offset "$BOARD_RAMDISK_OFFSET" \
			--second_offset "$BOARD_SECOND_OFFSET" \
			--tags_offset "$BOARD_TAGS_OFFSET" \
			--pagesize "$BOARD_PAGESIZE" \
			--cmdline "$BOARD_CMDLINE" \
			${DT_ARGS:+--dt boot.img-dtb} \
			-o ../rebuilt-boot.img

		printf "\nRebuilt boot image saved as: tmp_boot/rebuilt-boot.img\n\n"
		;;

	inject)
		[ ! -f "$IMAGE" ] && {
			printf "Error: image file '%s' not found\n\n" "$IMAGE"
			exit 1
		}

		LINE=$(fdisk -x "$IMAGE" | grep -i " boot ")
		START=$(printf "%s" "$LINE" | awk '{print $2}')
		SECTOR=$(printf "%s" "$LINE" | awk '{print $4}')

		OUTPUT="modified-${IMAGE}"
		cp -v "$IMAGE" "$OUTPUT"

		printf "\n=============== Injecting Boot Image ===============\n\n"
		dd if=/dev/zero of="$OUTPUT" bs=512 seek="$START" count="$SECTOR" conv=notrunc status=progress
		dd if=tmp_boot/rebuilt-boot.img of="$OUTPUT" bs=512 seek="$START" conv=notrunc status=progress

		printf "\nModified image saved as: %s\n\n" "$OUTPUT"
		;;

	mount)
		[ ! -f "$IMAGE" ] && {
			printf "Error: image file '%s' not found\n\n" "$IMAGE"
			exit 1
		}

		printf "\n=============== Mounting Boot Image Partition ===============\n\n"
		MOUNT_POINT="/run/media/$USER/MUOS-ROOTFS"

		LOOPDEV=$(losetup -f)
		if [ -z "$LOOPDEV" ]; then
			printf "Error: No free loop device found\n\n"
			exit 1
		fi

		sudo losetup -P "$LOOPDEV" "$IMAGE" || {
			printf "Error: Failed to setup loop device\n\n"
			exit 1
		}

		PARTITION="${LOOPDEV}p5"
		if [ ! -b "$PARTITION" ]; then
			printf "Error: Partition %s not found\n\n" "$PARTITION"
			sudo losetup -d "$LOOPDEV"
			exit 1
		fi

		sudo mkdir -p "$MOUNT_POINT" || exit 1
		sudo mount "$PARTITION" "$MOUNT_POINT" || {
			sudo losetup -d "$LOOPDEV"
			exit 1
		}

		printf "Mounted %s to %s\n" "$PARTITION" "$MOUNT_POINT"
		printf "Press Ctrl+C to unmount and detach loop device\n\n"

		trap 'printf "\nUnmounting...\n"; sync; sudo umount "$MOUNT_POINT"; sudo losetup -d "$LOOPDEV"' EXIT
		sleep infinity
		;;

	*)
		printf "Invalid mode: %s\n\n" "$MODE"
		exit 1
		;;
esac
