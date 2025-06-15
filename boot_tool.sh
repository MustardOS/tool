#!/bin/sh

REQUIRED_TOOLS="jq dtc dragonsecboot"
for TOOL in $REQUIRED_TOOLS; do
	command -v "$TOOL" >/dev/null 2>&1 || {
		echo "Error: Required tool '$TOOL' is not installed or not in PATH..." >&2
		exit 1
	}
done

MODE="$1"
FOLDER="$2"

DEVICE_JSON="$PWD/device.json"

[ -z "$MODE" ] || [ -z "$FOLDER" ] && {
	echo "Usage: $0 <build | extract> device"
	exit 1
}

cd "$PWD/$FOLDER" || exit 1

[ ! -f "$DEVICE_JSON" ] && {
	echo "Missing 'device.json' file..."
	exit 1
}

DEVICE="$FOLDER"

case "$MODE" in
	extract)
		echo "Extracting $DEVICE boot contents..."

		UBOOT_HEX=$(jq -r --arg dev "$DEVICE" '.[] | select(.device == $dev) | .offsets.uboot' "$DEVICE_JSON")
		MONITOR_HEX=$(jq -r --arg dev "$DEVICE" '.[] | select(.device == $dev) | .offsets.monitor' "$DEVICE_JSON")
		P1_HEX=$(jq -r --arg dev "$DEVICE" '.[] | select(.device == $dev) | .offsets.p1' "$DEVICE_JSON")
		SUNXI_HEX=$(jq -r --arg dev "$DEVICE" '.[] | select(.device == $dev) | .offsets.sunxi' "$DEVICE_JSON")

		UBOOT_DEC=$((UBOOT_HEX))
		MONITOR_DEC=$((MONITOR_HEX))
		P1_DEC=$((P1_HEX))
		SUNXI_DEC=$((SUNXI_HEX))

		dd if="$DEVICE/boot_package.fex" of="$DEVICE/u-boot.fex" skip="$UBOOT_DEC" count="$((MONITOR_DEC - UBOOT_DEC))" bs=1
		dd if="$DEVICE/boot_package.fex" of="$DEVICE/monitor.fex" skip="$MONITOR_DEC" count="$((P1_DEC - MONITOR_DEC))" bs=1
		dd if="$DEVICE/boot_package.fex" of="$DEVICE/p1.dtbo" skip="$P1_DEC" count="$((SUNXI_DEC - P1_DEC))" bs=1
		dd if="$DEVICE/boot_package.fex" of="$DEVICE/sunxi.fex" skip="$SUNXI_DEC" bs=1

		dtc -I dtb -O dts -o "$DEVICE/sunxi.dts" "$DEVICE/sunxi.fex"

		echo "Done extracting!"
		;;
	build)
		echo "Building $DEVICE boot contents..."

		rm -f "boot_package.fex"

		dtc -I dts -O dtb -o "sunxi.fex" "sunxi.dts"
		dragonsecboot -pack "boot_package.cfg"

		echo "Done building!"
		;;
	*)
		echo "Invalid mode: $MODE"
		exit 1
		;;
esac

