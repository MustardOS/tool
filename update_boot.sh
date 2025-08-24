#!/bin/sh

printf "\nMustardOS Boot Package Tool\n\n"

USAGE() {
	echo "Usage: $0 [options]"
	echo ""
	echo "Options:"
	echo "  -b, --build <device_dir>            Build a boot package from the specified directory"
	echo "  -d, --dump <device_image> <sector>  Dump the boot package from a device image"
	echo "  -e, --extract <boot_image>          Extract contents from a boot package file"
	echo ""
	echo "Examples:"
	echo "  $0 -b rg34xx-h"
	echo "  $0 -e rg34xx-h.bin"
	echo ""
	exit 1
}

[ "$#" -lt 2 ] && USAGE

# Check for all the required commands we'll be using from here on in
for CMD in dtc dd; do
	if ! command -v "$CMD" >/dev/null 2>&1; then
		printf "Error: Missing required command '%s'\n" "$CMD" >&2
		exit 1
	fi
done

# Exit immediately if a command exits with a non-zero status
set -e

# Boot package parameters
BOOT_PACKAGE_CFG="[package]
item=u-boot,                 u-boot.fex
item=monitor,                monitor.fex
item=dtbo,                   p1.dtbo
item=dtb,                    sunxi.fex"

BUILD() {
	DIR="$1"
	if [ ! -d "$DIR" ]; then
		printf "\nError: Directory not found: '%s'\n" "$DIR" >&2
		exit 1
	fi

	printf "\nBuilding boot package in '%s'...\n" "$DIR"

	cd "$DIR" || exit 1

	printf "Generating DTB file...\n"
	dtc -I dts -O dtb -o sunxi.fex sunxi.dts

	TMP_CFG="/tmp/boot_package.cfg"
	printf "%s" "$BOOT_PACKAGE_CFG" >"$TMP_CFG"

	printf "Packing boot package...\n"
	./dragonsecboot -pack "$TMP_CFG"
	rm -f "$TMP_CFG"

	printf "Build completed\n"
}

EXTRACT() {
	PREFIX="$1"
	if [ ! -f "$PREFIX" ]; then
		printf "\nError: '%s' not found\n" "$PREFIX" >&2
		exit 1
	fi

	UBOOT_OFFSET=0x800
	MONITOR_OFFSET=0x100800
	P1_OFFSET=0x11ac00
	SUNXI_OFFSET=0x11b800

	printf "\nExtracting contents from '%s.fex'...\n" "$PREFIX"
	mkdir -p "$PREFIX"

	dd if="$PREFIX.fex" of="$PREFIX/u-boot.fex" skip=$((UBOOT_OFFSET)) count=$((MONITOR_OFFSET - UBOOT_OFFSET)) bs=1
	dd if="$PREFIX.fex" of="$PREFIX/monitor.fex" skip=$((MONITOR_OFFSET)) count=$((P1_OFFSET - MONITOR_OFFSET)) bs=1
	dd if="$PREFIX.fex" of="$PREFIX/p1.dtbo" skip=$((P1_OFFSET)) count=$((SUNXI_OFFSET - P1_OFFSET)) bs=1
	dd if="$PREFIX.fex" of="$PREFIX/sunxi.fex" skip=$((SUNXI_OFFSET)) bs=1

	printf "Converting DTB file back to DTS...\n"
	dtc -I dtb -O dts -o "$PREFIX/sunxi.dts" "$PREFIX/sunxi.fex"

	printf "Extraction completed\n"
}

case "$1" in
	-b | --build) BUILD "$2" ;;
	-e | --extract) EXTRACT "$2" ;;
	*) USAGE ;;
esac
