#!/bin/sh

set -eu

MEGA_USER="$1"
MEGA_PASS="$2"
DIR="$3"
MEGA_PATH="$4"
IMG_EXT=".img.gz"

[ -z "$DIR" ] || [ -z "$MEGA_PATH" ] && {
	printf "\nUsage: %s <MEGA_USER> <MEGA_PASS> <DIRNAME> <MEGA_PATH>\n" "$0"
	exit 1
}

if ! command -v mega-whoami >/dev/null 2>&1; then
	printf "Error: MEGAcmd not installed or missing 'mega-whoami'\n"
	exit 1
fi

TARGET_DIR="./$DIR/compress"

[ -d "$TARGET_DIR" ] || {
	printf "\nError: Directory '%s' not found\n" "$TARGET_DIR"
	exit 1
}

FOUND=0

if ! mega-whoami >/dev/null 2>&1; then
	if [ -n "$MEGA_USER" ] && [ -n "$MEGA_PASS" ]; then
		mega-login "$MEGA_USER" "$MEGA_PASS"
	else
		printf "Error: Not logged into MEGA or MEGA_USER/MEGA_PASS not set\n"
		exit 1
	fi
fi

for FILE in "$TARGET_DIR"/*"$IMG_EXT"; do
	[ -f "$FILE" ] || continue
	FOUND=1

	printf "\nUploading: %s\n" "$FILE"

	mega-put "$FILE" "$MEGA_PATH"
done

printf "\n"

[ "$FOUND" -eq 0 ] && {
	printf "No compressed images (%s) found in '%s'\n" "$IMG_EXT" "$TARGET_DIR"
	exit 1
}
