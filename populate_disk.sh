#!/bin/sh

if [ $# -ne 2 ]; then
	printf "Usage: %s <usage_percent> <target_directory>\n" "$0"
	exit 1
fi

MAX_USAGE_PERCENT="$1"
TARGET_DIR="$2"

mkdir -p "$TARGET_DIR" || {
	printf "Error: Could not create or access directory: %s\n" "$TARGET_DIR"
	exit 1
}

PV="/opt/muos/bin/pv"
if [ ! -x "$PV" ]; then
	printf "Error: pv not found at %s\n" "$PV"
	exit 1
fi

# Get free space of the partition the target directory is on
TOTAL_FREE_KB=$(df -k "$TARGET_DIR" | awk 'NR==2 {print $4}')
TARGET_USE_KB=$((TOTAL_FREE_KB * MAX_USAGE_PERCENT / 100))

USED_KB=0
FILE_NUM=1

SIZE_OPTIONS="1024 2048 4096 8192 16384 32768 65536 131072 262144 524288"

C_1MB=0
C_2MB=0
C_4MB=0
C_8MB=0
C_16MB=0
C_32MB=0
C_64MB=0
C_128MB=0
C_256MB=0
C_512MB=0

while [ "$USED_KB" -lt "$TARGET_USE_KB" ]; do
	FILE_SIZE_KB=$(printf "%s\n" $SIZE_OPTIONS | awk -v r=$((RANDOM % 10)) 'NR==r+1')

	REMAINING_KB=$((TARGET_USE_KB - USED_KB))
	[ "$FILE_SIZE_KB" -gt "$REMAINING_KB" ] && break

	FILE_NAME="$TARGET_DIR/fill_${FILE_NUM}.bin"
	FILE_SIZE_BYTES=$((FILE_SIZE_KB * 1024))

	printf "Creating %s (%d KB)...\n" "$FILE_NAME" "$FILE_SIZE_KB"
	dd if=/dev/urandom bs=1024 count="$FILE_SIZE_KB" 2>/dev/null | "$PV" -s "$FILE_SIZE_BYTES" >"$FILE_NAME"

	USED_KB=$((USED_KB + FILE_SIZE_KB))
	FILE_NUM=$((FILE_NUM + 1))

	case "$FILE_SIZE_KB" in
		1024) C_1MB=$((C_1MB + 1)) ;;
		2048) C_2MB=$((C_2MB + 1)) ;;
		4096) C_4MB=$((C_4MB + 1)) ;;
		8192) C_8MB=$((C_8MB + 1)) ;;
		16384) C_16MB=$((C_16MB + 1)) ;;
		32768) C_32MB=$((C_32MB + 1)) ;;
		65536) C_64MB=$((C_64MB + 1)) ;;
		131072) C_128MB=$((C_128MB + 1)) ;;
		262144) C_256MB=$((C_256MB + 1)) ;;
		524288) C_512MB=$((C_512MB + 1)) ;;
	esac
done

printf "\nFinished creating files up to %s%% of free space in %s\n\n" "$MAX_USAGE_PERCENT" "$TARGET_DIR"
printf "Files Created:\n"
[ "$C_1MB" -gt 0 ] && printf "1MB     - %d\n" "$C_1MB"
[ "$C_2MB" -gt 0 ] && printf "2MB     - %d\n" "$C_2MB"
[ "$C_4MB" -gt 0 ] && printf "4MB     - %d\n" "$C_4MB"
[ "$C_8MB" -gt 0 ] && printf "8MB     - %d\n" "$C_8MB"
[ "$C_16MB" -gt 0 ] && printf "16MB    - %d\n" "$C_16MB"
[ "$C_32MB" -gt 0 ] && printf "32MB    - %d\n" "$C_32MB"
[ "$C_64MB" -gt 0 ] && printf "64MB    - %d\n" "$C_64MB"
[ "$C_128MB" -gt 0 ] && printf "128MB   - %d\n" "$C_128MB"
[ "$C_256MB" -gt 0 ] && printf "256MB   - %d\n" "$C_256MB"
[ "$C_512MB" -gt 0 ] && printf "512MB   - %d\n" "$C_512MB"
