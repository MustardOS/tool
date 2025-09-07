#!/bin/sh

set -eu

SRC="${1:-rootfs.img}"
DST="${2:-expanded-rootfs.img}"
SIZE_MB="${3:-8192}"

[ -r "$SRC" ] || {
	echo "Source $SRC not readable"
	exit 1
}

MAX_BYTES=$((SIZE_MB * 1024 * 1024))
SRC_BYTES=$(wc -c <"$SRC")

[ "$SRC_BYTES" -le "$MAX_BYTES" ] || {
	echo "Source image is larger than ${SIZE_MB} MB"
	exit 1
}

if [ "$(id -u)" -ne 0 ]; then
	if command -v sudo >/dev/null 2>&1; then
		sudo -v || exit 1
		exec sudo -- "$0" "$@"
	else
		printf "This script requires root privileges\n" >&2
		exit 1
	fi
fi

echo "Creating ${SIZE_MB} MB file at $DST"
dd if=/dev/zero of="$DST" bs=1M count="$SIZE_MB"

echo "Copying $SRC into $DST"
dd if="$SRC" of="$DST" conv=notrunc,fsync

LOOP="$(losetup -f)"

CLEANUP() {
	losetup -d "$LOOP" 2>/dev/null || true
}

trap CLEANUP EXIT INT TERM

echo "Attaching $DST to $LOOP"
losetup "$LOOP" "$DST"

echo "Checking filesystem"
e2fsck -pf "$LOOP" || e2fsck -fy "$LOOP"

echo "Resizing filesystem to fill image"
resize2fs "$LOOP"
