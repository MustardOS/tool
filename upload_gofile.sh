#!/bin/sh

DIR="$1"
FOLDER_ID="$2"
UPLOAD_URL="https://upload.gofile.io/uploadFile"
API_TOKEN=""
IMG_EXT=".img.gz"

[ -z "$DIR" ] || [ -z "$FOLDER_ID" ] && {
	printf "\nUsage: %s <DIRNAME> <FOLDER_ID>\n" "$0"
	exit 1
}

[ -z "$API_TOKEN" ] && {
	printf "\nError: API_TOKEN not provided\n"
	exit 1
}

TARGET_DIR="./$DIR/compress"

[ ! -d "$TARGET_DIR" ] && {
	printf "\nError: Directory '%s' not found\n" "$TARGET_DIR"
	exit 1
}

FOUND=0

# This is so that the curl progress bar stays within a small
# range, otherwise if you have a super long terminal it will
# stretch to the entire width and progress indicator is lost
ORIGINAL_COLS=$(stty size 2>/dev/null | awk '{print $2}')
stty cols 100 2>/dev/null

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

[ -n "$ORIGINAL_COLS" ] && stty cols "$ORIGINAL_COLS" 2>/dev/null

[ "$FOUND" -eq 0 ] && {
	printf "No compressed images (%s) found in '%s'\n" "$IMG_EXT" "$TARGET_DIR"
	exit 1
}
