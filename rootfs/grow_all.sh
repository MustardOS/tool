#!/bin/sh

set -eu

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
CYAN='\033[36m'
BOLD='\033[1m'
RESET='\033[0m'

GROW="${GROW:-./grow_rootfs.sh}"
VERSION="${VERSION:-2508.1_CANADA_GOOSE}"

ROOTFS_PART="${ROOTFS_PART:-5}"
BUFFER_MIB="${BUFFER_MIB:-12}"
EXFAT_MIB="${EXFAT_MIB:-4}"
LABEL="${LABEL:-ROMS}"

H700_ROOTFS="${H700_ROOTFS:-H700-ROOTFS.img}"
A133_ROOTFS="${A133_ROOTFS:-A133-ROOTFS.img}"

H700_MODELS="${H700_MODELS:-\
RG28XX-H
RG34XX-H
RG34XX-SP
RG35XX-2024
RG35XX-H
RG35XX-PLUS
RG35XX-PRO
RG35XX-SP
RG40XX-H
RG40XX-V
RGCUBEXX-H
}"

A133_MODELS="${A133_MODELS:-\
GCS-H36S
MGX-ZERO28
TUI-BRICK
TUI-SPOON
}"

printf "\n=============== %b%b MustardOS RootFS Grower (MURG) %b===============\n\n" "$BLUE" "$BOLD" "$RESET"

if [ ! -x "$GROW" ]; then
	printf "%bError%b Cannot execute '%b%s%b'\n" "$RED" "$RESET" "$BOLD" "$GROW" "$RESET" >&2
	exit 1
fi

for REQ in "$H700_ROOTFS" "$A133_ROOTFS"; do
	if [ ! -r "$REQ" ]; then
		printf "%bError%b Missing required file '%b%s%b'\n" "$RED" "$RESET" "$BOLD" "$REQ" "$RESET" >&2
		exit 1
	fi
done

printf "%b%b- Using Version%b     %s\n" "$BLUE" "$BOLD" "$RESET" "$VERSION"
printf "%b%b- Common Grow Args%b  part=%s buffer=%sMiB exfat=%sMiB label=%s\n\n" \
	"$BLUE" "$BOLD" "$RESET" "$ROOTFS_PART" "$BUFFER_MIB" "$EXFAT_MIB" "$LABEL"

SUCC=0
FAIL=0
FAILS=""

COMMON_ARGS="$ROOTFS_PART $BUFFER_MIB $EXFAT_MIB $LABEL"

RUN_ONE() {
	IMG="$1"
	ROOTFS="$2"

	if [ ! -r "$IMG" ]; then
		printf "%b%b- Skipping%b       %s\n" "$YELLOW" "$BOLD" "$RESET" "$IMG"
		printf "\t%bReason%b Missing image file\n" "$YELLOW" "$RESET"
		FAIL=$((FAIL + 1))
		FAILS="$FAILS\n$IMG (missing)"
		return 1
	fi

	printf "%b%b- Processing%b     %s\n" "$CYAN" "$BOLD" "$RESET" "$IMG"
	printf "\t%bRootFS%b   %s\n" "$BLUE" "$RESET" "$ROOTFS"
	printf "\t%bArgs%b     %s\n" "$BLUE" "$RESET" "$COMMON_ARGS"

	"$GROW" "$IMG" "$ROOTFS" $COMMON_ARGS
	RC=$?

	if [ "$RC" -eq 0 ]; then
		printf "\t%b%b- Completed OK%b\n" "$GREEN" "$BOLD" "$RESET"
		SUCC=$((SUCC + 1))
	else
		printf "\t%b%b- Failed%b Exit %d\n" "$RED" "$BOLD" "$RESET" "$RC"
		FAIL=$((FAIL + 1))
		FAILS="$FAILS\n$IMG (exit $RC)"
	fi

	printf "\n"
	return "$RC"
}

printf "%b%b- Group%b H700 (%s)\n\n" "$YELLOW" "$BOLD" "$RESET" "$H700_ROOTFS"
for MODEL in $H700_MODELS; do
	IMG_PATH="H700/MustardOS_${MODEL}_${VERSION}.img"
	RUN_ONE "$IMG_PATH" "$H700_ROOTFS"
done

printf "%b%b- Group%b A133 (%s)\n\n" "$YELLOW" "$BOLD" "$RESET" "$A133_ROOTFS"
for MODEL in $A133_MODELS; do
	IMG_PATH="A133/MustardOS_${MODEL}_${VERSION}.img"
	RUN_ONE "$IMG_PATH" "$A133_ROOTFS"
done

printf "=============== %b%b Summary %b===============\n" "$BLUE" "$BOLD" "$RESET"
printf "%b%b- Success%b %d\n" "$GREEN" "$BOLD" "$RESET" "$SUCC"

if [ "$FAIL" -eq 0 ]; then
	printf "%b%b- Failed%b  %d\n\n" "$GREEN" "$BOLD" "$RESET" "$FAIL"
else
	printf "%b%b- Failed%b  %d\n" "$RED" "$BOLD" "$RESET" "$FAIL"
	printf "%bFailures:%b%s\n\n" "$RED" "$RESET" "$FAILS"
fi
