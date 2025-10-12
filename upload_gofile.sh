#!/bin/sh

set -eu

DIR="$2"
FOLDER_ID="$3"
UPLOAD_URL="https://upload.gofile.io/uploadFile"
API_TOKEN="$1"
IMG_EXT=".img.gz"

[ -z "$API_TOKEN" ] || [ -z "$DIR" ] || [ -z "$FOLDER_ID" ] && {
	printf "\nUsage: %s <API_TOKEN> <DIRNAME> <FOLDER_ID>\n" "$0"
	exit 1
}

TARGET_DIR="./$DIR/compress"

[ ! -d "$TARGET_DIR" ] && {
	printf "\nError: Directory '%s' not found\n" "$TARGET_DIR"
	exit 1
}

FOUND=0

for FILE in "$TARGET_DIR"/*"$IMG_EXT"; do
	[ -f "$FILE" ] || continue
	FOUND=1

	printf "\nUploading: %s\n" "$FILE"

	RESPONSE=$(curl --progress-bar \
		-H "Authorization: Bearer $API_TOKEN" \
		-F "file=@$FILE" \
		-F "folderId=$FOLDER_ID" \
		"$UPLOAD_URL")

	SUCCESS=$(printf "%s" "$RESPONSE" | grep -c '"status":"ok"')

	if [ "$SUCCESS" -eq 0 ]; then
		printf "Failed to upload '%s'\nResponse: %s\n" "$FILE" "$RESPONSE"
	fi
done

printf "\n"

[ "$FOUND" -eq 0 ] && {
	printf "No compressed images (%s) found in '%s'\n" "$IMG_EXT" "$TARGET_DIR"
	exit 1
}
