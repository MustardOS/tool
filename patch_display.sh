#!/bin/sh

for CMD in dtc xxd; do
	if ! command -v "$CMD" >/dev/null 2>&1; then
		printf "Missing '%s' command\n" "$CMD"
		exit 1
	fi
done

if [ "$#" -ne 1 ]; then
	echo "Usage: $0 <image>"
	exit 1
fi

IMAGE="$1"
printf "Using Image: %s\n" "$IMAGE"

DT_NAME=device
BOOT_OFFSET=$((16400 * 1024))
DTB_OFFSET=$((BOOT_OFFSET + 1161216))
SIZE_OFFSET=$((DTB_OFFSET + 4))

DTB_SIZE=$(printf '%d' 0x"$(dd if="$IMAGE" bs=1 skip="$SIZE_OFFSET" count=4 2>/dev/null | xxd -ps)")
dd if="$IMAGE" of="$DT_NAME.dtb" bs=1 skip="$DTB_OFFSET" count="$DTB_SIZE" 2>/dev/null

if ! dtc -I dtb -O dts -o "$DT_NAME.dts" "$DT_NAME.dtb" 2>/dev/null; then
	printf "Unable to decompile DTB, aborting!\n"
	exit 1
fi

printf "Parsing values from DTS... "
while read -r LINE; do
	KEY=$(echo "$LINE" | awk '{print $1}')
	HEX=$(echo "$LINE" | sed -n 's/.*<\([0-9a-fA-Fx]*\)>.*/\1/p')
	DEC=$((HEX))

	case $KEY in
		lcd_dclk_freq)
			CF=$DEC
			;;
		lcd_ht)
			HT=$DEC
			;;
		lcd_vt)
			VT=$DEC
			;;
		lcd_backlight)
			BL=$DEC
			;;
	esac
done <<EOF
$(grep -E 'lcd_backlight|lcd_dclk_freq|lcd_ht|lcd_vt' "$DT_NAME.dts")
EOF

printf "Parsed Values: CF=%s, HT=%s, VT=%s, BL=%s\n" "$CF" "$HT" "$VT" "$BL"

CF_OFFSET=0
HT_OFFSET=0
VT_OFFSET=0

case $CF-$HT-$VT in
	24-770-526)   # 35xx2024/35xxPLUS
		HT_OFFSET=-2 # 768
		VT_OFFSET=-5 # 521
		;;
	24-770-528)   # 35xxH
		HT_OFFSET=-2 # 768
		VT_OFFSET=-7 # 521
		;;
	24-770-525)   # 35xxSP
		HT_OFFSET=-2 # 768
		VT_OFFSET=-4 # 521
		;;
	24-770-522)   # 40xxH/V
		HT_OFFSET=-2 # 768
		VT_OFFSET=-1 # 521
		;;
	24-586-686)   # 28xx
		HT_OFFSET=-2 # 584
		VT_OFFSET=-1 # 685
		;;
	24-606-686)    # 28xx MOD
		HT_OFFSET=-22 # 584
		VT_OFFSET=-4  # 682
		;;
	25-728-568)    # 35xxSP MOD
		CF_OFFSET=-1  # 24
		HT_OFFSET=-12 # 716
		VT_OFFSET=-10 # 558
		;;
	36-812-756)  # CUBExx
		CF_OFFSET=1 # 37
		;;
	*)
		printf "Unrecognized panel configuration! Stopping!\n"
		exit 0
		;;
esac

BL_OFFSET=$((CF_OFFSET + HT_OFFSET + VT_OFFSET))
if [ "$BL_OFFSET" -ne 0 ]; then
	CF=$((CF + CF_OFFSET))
	HT=$((HT + HT_OFFSET))
	VT=$((VT + VT_OFFSET))
	BL=$((BL - BL_OFFSET))
fi

printf "Updated Values: CF=%s, HT=%s, VT=%s, BL=%s\n" "$CF" "$HT" "$VT" "$BL"

MOD_PATH="$DT_NAME-mod.dts"
cp "$DT_NAME.dts" "$MOD_PATH"
sed -i "s/lcd_dclk_freq = <0x[0-9A-Fa-f]\+>/lcd_dclk_freq = <0x$(printf '%x' "$CF")>/" "$MOD_PATH"
sed -i "s/lcd_ht = <0x[0-9A-Fa-f]\+>/lcd_ht = <0x$(printf '%x' "$HT")>/" "$MOD_PATH"
sed -i "s/lcd_vt = <0x[0-9A-Fa-f]\+>/lcd_vt = <0x$(printf '%x' "$VT")>/" "$MOD_PATH"
sed -i "s/lcd_backlight = <0x[0-9A-Fa-f]\+>/lcd_backlight = <0x$(printf '%x' "$BL")>/" "$MOD_PATH"

dtc -I dts -O dtb -o "$DT_NAME-mod.dtb" "$MOD_PATH" 2>/dev/null

dd if="$DT_NAME.dtb" of="$DT_NAME-mod.dtb" bs=1 skip=4 seek=4 count=4 conv=notrunc 2>/dev/null
truncate -s "$DTB_SIZE" "$DT_NAME-mod.dtb" 2>/dev/null

VC_SUM() {
	xxd -p -c 1 "$1" | awk '{sum+=strtonum("0x"$0)} END{print sum}'
}

A_SUM=$(VC_SUM "$DT_NAME.dtb")
B_SUM=$(VC_SUM "$DT_NAME-mod.dtb")

if [ "$A_SUM" != "$B_SUM" ]; then
	printf "Checksum Mismatch!\n\tOriginal is: %s\n\tModified is: %s\nStopping!\n" "$A_SUM" "$B_SUM"
	exit 1
else
	printf "Checksum Match Success!\n\tOriginal is: %s\n\tModified is: %s\n" "$A_SUM" "$B_SUM"
fi

dd if="$DT_NAME-mod.dtb" of="$IMAGE" bs=1 seek=$DTB_OFFSET conv=notrunc 2>/dev/null
rm -f "$DT_NAME.dtb" "$DT_NAME.dts" "$MOD_PATH" "$DT_NAME-mod.dtb" 2>/dev/null

printf "Image Patched Successfully!\n"
