#!/bin/sh

for CMD in zstdmt sha256sum transmission-create; do
	if ! command -v "$CMD" >/dev/null 2>&1; then
		printf "Missing '%s' command\n" "$CMD"
		exit 1
	fi
done

if [ "$#" -ne 1 ]; then
	printf "Usage: %s <image_dir>\n" "$0"
	exit 1
fi

DIR=$1
if [ ! -d "$DIR" ]; then
	printf "Directory '%s' does not exist\n" "$DIR"
	exit 1
fi

IMG_TOTAL=$(find "$DIR" -maxdepth 1 -name '*.img' -type f | wc -l)
if [ "$IMG_TOTAL" -eq 0 ]; then
	printf "No image files found in '%s'\n" "$DIR"
	exit 1
fi

BUILD_ID="$(cat "$DIR/buildID.txt")"
COMPRESS_DIR="$DIR/compress"
rm -rf "$COMPRESS_DIR" >/dev/null 2>&1
mkdir -p "$COMPRESS_DIR/Torrent" >/dev/null 2>&1

printf "===============\033[1m Image Compressing \033[0m ===============\n\n"

find "$DIR" -maxdepth 1 -name '*.img' -type f | while IFS= read -r IMG; do
	IMAGE_FILE="$(basename -s ".img" "$IMG")-$BUILD_ID.img"

	COMPRESSED_FILE="$COMPRESS_DIR/$IMAGE_FILE.gz"
	IMAGE_SIZE=$(echo "$(stat -c%s "$IMG") / 1024 / 1024" | bc)

	printf "\033[1mCompressing:\033[0m %s (%s MB)\n" "$IMAGE_FILE" "$IMAGE_SIZE"
	pv -bep --width 75 "$IMG" | pigz --best -k >"$COMPRESSED_FILE"

	printf "\n\033[1mGenerating Torrent:\033[0m "
	transmission-create --anonymize \
		-t "udp://tracker.opentrackr.org:1337/announce" \
		-t "udp://tracker.torrent.eu.org:451/announce" \
		-t "udp://tracker-udp.gbitt.info:80/announce" \
		-t "udp://tracker.0x7c0.com:6969/announce" \
		-t "udp://open.tracker.cl:1337/announce" \
		-t "udp://opentracker.io:6969/announce" \
		-o "$COMPRESS_DIR/Torrent/$(basename -s ".img" "$IMAGE_FILE").torrent" "$COMPRESSED_FILE"

	printf "\n\033[1mCalculating Hash:\033[0m "
	C_HASH=$(sha256sum "$COMPRESSED_FILE" | awk -v name="$IMAGE_FILE.gz" '{print $1, name}')
	printf "%s\n\n" "$(printf "%s" "$C_HASH" | awk '{print $1}')"
	echo "$C_HASH" >>"$COMPRESS_DIR/hash.txt"
done

printf "==========\033[1m Image Compressing Complete \033[0m===========\n\n"
