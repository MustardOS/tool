#!/bin/sh

# Usage:
#   ./grow_rootfs.sh <disk image> <rootfs image> [rootfs partition] [buffer] [rom size] [label]
# Defaults:
#   ROOTFS_PARTNUM=5  BUFFER_MB=12  EXFAT_MB=4  EXFAT_LABEL=EXFAT

set -eu

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
CYAN='\033[36m'
BOLD='\033[1m'
RESET='\033[0m'

DISK_IMG="${1:-}"

ROOTFS_IMG="${2:-}"
ROOTFS_NUM="${3:-5}"

BUFFER_MB="${4:-12}"

EXFAT_MB="${5:-4}"
EXFAT_LABEL="${6:-EXFAT}"

if [ -z "$DISK_IMG" ] || [ -z "$ROOTFS_IMG" ]; then
	printf "%bError%b Usage: %s <disk.img> <rootfs.img> [partnum] [buffer_mb] [exfat_mb] [exfat_label]\n" \
		"$RED" "$RESET" "$0" >&2
	exit 2
fi

if [ ! -r "$DISK_IMG" ]; then
	printf "%bError%b Disk image not readable: %b%s%b\n" "$RED" "$RESET" "$BOLD" "$DISK_IMG" "$RESET" >&2
	exit 1
fi

if [ ! -r "$ROOTFS_IMG" ]; then
	printf "%bError%b Rootfs image not readable: %b%s%b\n" "$RED" "$RESET" "$BOLD" "$ROOTFS_IMG" "$RESET" >&2
	exit 1
fi

case "$BUFFER_MB" in *[!0-9]* | "")
	printf "%bError%b BUFFER_MB must be an integer MiB\n" "$RED" "$RESET" >&2
	exit 1
	;;
esac

case "$EXFAT_MB" in *[!0-9]* | "")
	printf "%bError%b EXFAT_MB must be an integer MiB\n" "$RED" "$RESET" >&2
	exit 1
	;;
esac

if [ "$EXFAT_MB" -gt "$BUFFER_MB" ]; then
	printf "%bError%b exFAT size (%b%s MiB%b) must be <= buffer size (%b%s MiB%b)\n" \
		"$RED" "$RESET" "$BOLD" "$EXFAT_MB" "$RESET" "$BOLD" "$BUFFER_MB" "$RESET" >&2
	exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
	if command -v sudo >/dev/null 2>&1; then
		printf "%bRe-exec as root%b (sudo)\n" "$YELLOW" "$RESET"
		sudo -v || exit 1
		exec sudo -- "$0" "$@"
	else
		printf "%bError%b This script requires root privileges\n" "$RED" "$RESET" >&2
		exit 1
	fi
fi

for CMD in sgdisk losetup blockdev dd e2fsck resize2fs awk sed wc; do
	if ! command -v "$CMD" >/dev/null 2>&1; then
		printf "%bError%b Missing required command '%b%s%b'\n" "$RED" "$RESET" "$BOLD" "$CMD" "$RESET" >&2
		exit 1
	fi
done

MKFS_EXFAT_BIN=""

if command -v mkfs.exfat >/dev/null 2>&1; then
	MKFS_EXFAT_BIN="mkfs.exfat"
elif command -v mkexfatfs >/dev/null 2>&1; then
	MKFS_EXFAT_BIN="mkexfatfs"
fi

REREAD_PARTS() {
	DEV="$1"
	if command -v partprobe >/dev/null 2>&1; then partprobe "$DEV" 2>/dev/null || true; fi
	losetup -c "$DEV" 2>/dev/null || true
	if command -v partx >/dev/null 2>&1; then partx -u "$DEV" 2>/dev/null || true; fi
}

GET_LAST_USABLE() {
	sgdisk -p "$1" | sed -n 's/.*last usable sector is \([0-9][0-9]*\).*/\1/p'
}

CEIL_DIV() {
	A="$1"
	B="$2"

	echo $(((A + B - 1) / B))
}

TYPE_CODE_FROM_INFO() {
	INFO_LINE="$1"
	printf "%s\n" "$INFO_LINE" |
		awk -F: '/Partition GUID code/ {gsub(/^[ \t]+/,"",$2); print $2; exit}' | awk '{print $1}'
}

GROW_FILE_MIB() {
	INC_MB="${1:-1}"

	if command -v truncate >/dev/null 2>&1; then
		truncate -s +"${INC_MB}"M "$DISK_IMG"
	else
		BYTES_ADD=$((INC_MB * 1024 * 1024))
		CUR_SIZE=$(wc -c <"$DISK_IMG")
		NEW_END=$((CUR_SIZE + BYTES_ADD - 1))

		dd if=/dev/zero of="$DISK_IMG" bs=1 count=1 seek="$NEW_END" conv=notrunc >/dev/null 2>&1
	fi
}

COPY_WITH_PROGRESS() {
	IN="$1"  # source file
	OUT="$2" # target block device
	BYTES="$3"

	if command -v pv >/dev/null 2>&1; then
		pv -s "$BYTES" "$IN" | dd of="$OUT" bs=4M iflag=fullblock conv=fsync,nocreat,notrunc status=none
	else
		if dd --version >/dev/null 2>&1; then
			dd if="$IN" of="$OUT" bs=4M conv=fsync status=progress
		else
			dd if="$IN" of="$OUT" bs=4M conv=fsync 2>&1 &

			DD_PID=$!
			while kill -0 "$DD_PID" 2>/dev/null; do
				kill -USR1 "$DD_PID" 2>/dev/null || true
				sleep 2
			done

			wait "$DD_PID"
		fi
	fi
}

printf "\n=============== %b%b MustardOS RootFS Injector (MURI) %b===============\n\n" "$BLUE" "$BOLD" "$RESET"

ROOTFS_BYTES="$(wc -c <"$ROOTFS_IMG")"
printf "%b%b- Rootfs image%b %s (%s bytes)\n" "$BLUE" "$BOLD" "$RESET" "$ROOTFS_IMG" "$ROOTFS_BYTES"

LOOP_DEV="$(losetup -f)"
losetup "$LOOP_DEV" "$DISK_IMG"

trap 'losetup -d "$LOOP_DEV" 2>/dev/null || true' EXIT INT TERM

REREAD_PARTS "$LOOP_DEV"
sgdisk -e "$LOOP_DEV" >/dev/null

SECTOR_SIZE="$(blockdev --getss "$LOOP_DEV")"
SECT_PER_MIB=$((1024 * 1024 / SECTOR_SIZE))

BUFFER_SECT=$((BUFFER_MB * SECT_PER_MIB))

EXFAT_SECT=$((EXFAT_MB * SECT_PER_MIB))
ROOTFS_SECT="$(CEIL_DIV "$ROOTFS_BYTES" "$SECTOR_SIZE")"

BASE="$(basename "$LOOP_DEV")"
SYS_P="/sys/block/$BASE/${BASE}p${ROOTFS_NUM}"

if [ ! -r "$SYS_P/start" ]; then
	REREAD_PARTS "$LOOP_DEV"
fi

if [ ! -r "$SYS_P/start" ]; then
	printf "%bError%b Cannot find partition %b%s%b on %b%s%b\n" \
		"$RED" "$RESET" "$BOLD" "p$ROOTFS_NUM" "$RESET" "$BOLD" "$LOOP_DEV" "$RESET" >&2
	exit 1
fi

P_START="$(tr -d '\r' <"$SYS_P/start")"
P_SIZE_CUR="$(tr -d '\r' <"$SYS_P/size")"
P_END_CUR=$((P_START + P_SIZE_CUR - 1))

printf "%b%b- Current rootfs%b p%s: start=%s end=%s\n" "$BLUE" "$BOLD" "$RESET" "$ROOTFS_NUM" "$P_START" "$P_END_CUR"

INFO="$(sgdisk -i "$ROOTFS_NUM" "$LOOP_DEV" 2>/dev/null || true)"
P_TYPE="$(TYPE_CODE_FROM_INFO "$INFO")"

[ -n "$P_TYPE" ] || P_TYPE="8300"

P_GUID="$(printf "%s\n" "$INFO" | awk -F: '/Partition unique GUID/ {gsub(/^[ \t]+/,"",$2); print $2; exit}')"
P_NAME="$(printf "%s\n" "$INFO" | awk -F: '/Partition name/ {gsub(/^[ \t]+/,"",$2); gsub(/^'\''|'\''$/,"",$2); print $2; exit}')"

[ -n "${P_NAME:-}" ] || P_NAME="rootfs"

ROOTFS_END=$((P_START + ROOTFS_SECT - 1))

EXFAT_START=$((ROOTFS_END + 1))
EXFAT_END=$((EXFAT_START + EXFAT_SECT - 1))

REQUIRED_LAST_USABLE=$((ROOTFS_END + BUFFER_SECT - 1))
LAST_USABLE="$(GET_LAST_USABLE "$LOOP_DEV")"

if [ -z "$LAST_USABLE" ]; then
	printf "%bError%b Could not read GPT last usable sector\n" "$RED" "$RESET" >&2
	exit 1
fi

if [ "$LAST_USABLE" -lt "$REQUIRED_LAST_USABLE" ]; then
	DEFICIT=$((REQUIRED_LAST_USABLE - LAST_USABLE))

	GROW_MB="$(CEIL_DIV "$DEFICIT" "$SECT_PER_MIB")"
	GROW_MB=$((GROW_MB + 2))

	printf "%b%b- Growing%b %s by +%s MiB to fit rootfs + %s MiB buffer ...\n" \
		"$YELLOW" "$BOLD" "$RESET" "$DISK_IMG" "$GROW_MB" "$BUFFER_MB"

	GROW_FILE_MIB "$GROW_MB"
	REREAD_PARTS "$LOOP_DEV"

	sgdisk -e "$LOOP_DEV" >/dev/null

	LAST_USABLE="$(GET_LAST_USABLE "$LOOP_DEV")"
fi

EXFAT_START=$((ROOTFS_END + 1))
EXFAT_END=$((EXFAT_START + EXFAT_SECT - 1))

if [ $((ROOTFS_END + BUFFER_SECT - 1)) -lt "$EXFAT_END" ]; then
	printf "%bError%b exFAT does not fit inside the %s MiB buffer\n" "$RED" "$RESET" "$BUFFER_MB" >&2
	exit 1
fi

if [ "$EXFAT_END" -gt "$LAST_USABLE" ]; then
	printf "%bError%b exFAT end exceeds GPT last usable sector\n" "$RED" "$RESET" >&2
	exit 1
fi

USED_LIST="$(sgdisk -p "$LOOP_DEV" | awk '/^[ ]*[0-9]+/ {print $1}')"

for N in $USED_LIST; do
	case "$N" in
		'' | *[!0-9]*) ;;
		*)
			if [ "$N" -gt "$ROOTFS_NUM" ]; then
				printf "%b%b- Deleting%b partition %s\n" "$YELLOW" "$BOLD" "$RESET" "$N"
				sgdisk -d "$N" "$LOOP_DEV" >/dev/null || true
			fi
			;;
	esac
done

REREAD_PARTS "$LOOP_DEV"

printf "%b%b- Deleting%b current rootfs (p%s)\n" "$YELLOW" "$BOLD" "$RESET" "$ROOTFS_NUM"
sgdisk -d "$ROOTFS_NUM" "$LOOP_DEV" >/dev/null
REREAD_PARTS "$LOOP_DEV"

printf "%b%b- Creating%b rootfs (p%s) %s-%s (exact match to image)\n" \
	"$CYAN" "$BOLD" "$RESET" "$ROOTFS_NUM" "$P_START" "$ROOTFS_END"
sgdisk -n "${ROOTFS_NUM}:${P_START}:${ROOTFS_END}" \
	-t "${ROOTFS_NUM}:${P_TYPE}" \
	-c "${ROOTFS_NUM}:${P_NAME}" \
	"$LOOP_DEV" >/dev/null
[ -n "${P_GUID:-}" ] && sgdisk -u "${ROOTFS_NUM}:${P_GUID}" "$LOOP_DEV" >/dev/null || true

sgdisk -e "$LOOP_DEV" >/dev/null
REREAD_PARTS "$LOOP_DEV"

sleep 1 # Slow down!

DEV_ROOT="/dev/${BASE}p${ROOTFS_NUM}"

printf "%b%b- Writing%b %s %b→%b %s\n" "$BLUE" "$BOLD" "$RESET" "$ROOTFS_IMG" "$BOLD" "$RESET" "$DEV_ROOT"
COPY_WITH_PROGRESS "$ROOTFS_IMG" "$DEV_ROOT" "$ROOTFS_BYTES"

printf "%b%b- Checking%b EXT4 and ensuring it fills the partition\n" "$BLUE" "$BOLD" "$RESET"
e2fsck -pf "$DEV_ROOT" || e2fsck -fy "$DEV_ROOT"
resize2fs "$DEV_ROOT" >/dev/null 2>&1 || true

MAX_ENTRIES="$(sgdisk -p "$LOOP_DEV" | sed -n 's/.*holds up to \([0-9][0-9]*\) entries.*/\1/p')"

[ -n "$MAX_ENTRIES" ] || MAX_ENTRIES=128
USED_LIST="$(sgdisk -p "$LOOP_DEV" | awk '/^[ ]*[0-9]+/ {print $1}')"
USED_MAP=","

for N in $USED_LIST; do
	USED_MAP="${USED_MAP}${N},"
done

EXFAT_NUM=""

I=1
while [ "$I" -le "$MAX_ENTRIES" ]; do
	case "$USED_MAP" in *,"$I",*) : ;; *)
		EXFAT_NUM="$I"
		break
		;;
	esac

	I=$((I + 1))
done

if [ -z "$EXFAT_NUM" ]; then
	printf "%bError%b No free GPT entry available for exFAT\n" "$RED" "$RESET" >&2
	exit 1
fi

printf "%b%b- Creating%b exFAT (p%s) %s-%s (%s MiB)\n" \
	"$CYAN" "$BOLD" "$RESET" "$EXFAT_NUM" "$EXFAT_START" "$EXFAT_END" "$EXFAT_MB"

sgdisk -n "${EXFAT_NUM}:${EXFAT_START}:${EXFAT_END}" \
	-t "${EXFAT_NUM}:0700" \
	-c "${EXFAT_NUM}:${EXFAT_LABEL}" \
	"$LOOP_DEV" >/dev/null

sgdisk -e "$LOOP_DEV" >/dev/null
REREAD_PARTS "$LOOP_DEV"

sleep 1 # Slow down again!

DEV_EXFAT="/dev/${BASE}p${EXFAT_NUM}"
if [ -n "$MKFS_EXFAT_BIN" ]; then
	printf "%b%b- Formatting%b %s as exFAT (label: %s)\n" "$BLUE" "$BOLD" "$RESET" "$DEV_EXFAT" "$EXFAT_LABEL"

	if [ "$MKFS_EXFAT_BIN" = "mkfs.exfat" ]; then
		mkfs.exfat -n "$EXFAT_LABEL" "$DEV_EXFAT" >/dev/null
	else
		mkexfatfs -n "$EXFAT_LABEL" "$DEV_EXFAT" >/dev/null
	fi
else
	printf "%bNote%b exFAT tools not found; partition created but not formatted\n" "$YELLOW" "$RESET"
fi

ROOTFS_PART_SECT="$(tr -d '\r' <"/sys/block/$BASE/${BASE}p${ROOTFS_NUM}/size")"
EXFAT_PART_SECT="$(tr -d '\r' <"/sys/block/$BASE/${BASE}p${EXFAT_NUM}/size")"

OK=1
if [ "$ROOTFS_PART_SECT" -ne "$ROOTFS_SECT" ]; then
	printf "%bVerify FAIL%b rootfs sectors=%s expected=%s\n" "$RED" "$RESET" "$ROOTFS_PART_SECT" "$ROOTFS_SECT" >&2
	OK=0
else
	printf "%b%b- Verified%b rootfs size matches image (%s sectors)\n" "$GREEN" "$BOLD" "$RESET" "$ROOTFS_SECT"
fi

if [ "$EXFAT_PART_SECT" -ne "$EXFAT_SECT" ]; then
	printf "%bVerify FAIL%b exFAT sectors=%s expected=%s\n" "$RED" "$RESET" "$EXFAT_PART_SECT" "$EXFAT_SECT" >&2
	OK=0
else
	printf "%b%b- Verified%b exFAT size is %s MiB (%s sectors)\n" \
		"$GREEN" "$BOLD" "$RESET" "$EXFAT_MB" "$EXFAT_PART_SECT"
fi

printf "\n%bFinal layout%b\n" "$BLUE" "$RESET"
sgdisk -p "$LOOP_DEV"

if [ "$OK" -eq 1 ]; then
	printf "\n%b%b- Completed successfully%b 🎉\n\n" "$GREEN" "$BOLD" "$RESET"
else
	printf "\n%b%b- Completed with verification errors%b\n\n" "$YELLOW" "$BOLD" "$RESET"
	exit 1
fi
