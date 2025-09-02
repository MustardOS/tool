#!/bin/sh

sudo -v || {
	printf "Superuser Authentication Failed\n" >&2
	exit 1
}

(
	while :; do
		sleep 60
		sudo -n true || exit
	done
) &
SUDO_KEEPALIVE_PID=$!

trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null; sudo -k' 0 INT TERM

START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
START_EPOCH=$(date +%s)

printf "Started at: %s\n\n" "$START_TIME"

DEVICES="A133 H700"
ERROR=0

COMPRESS_FLAG=0
for ARG in "$@"; do
	if [ "$ARG" = "compress" ]; then
		COMPRESS_FLAG=1
		break
	fi
done

for DEV in $DEVICES; do
	IMG="${DEV}-ROOTFS.img"

	printf "Updating RootFS for %s...\n" "$DEV"
	./update_rootfs.sh "$DEV" "$IMG" || {
		printf "\n%s RootFS Update Failed\n" "$DEV"
		ERROR=1
	}

	if [ "$COMPRESS_FLAG" -eq 1 ]; then
		printf "Compressing Image for %s...\n" "$DEV"
		./compress_gzip.sh "$DEV" || {
			printf "\n%s Image Compression Failed\n" "$DEV"
			ERROR=1
		}
	else
		printf "Skipping compression for %s...\n" "$DEV"
	fi
done

END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
END_EPOCH=$(date +%s)
DURATION=$((END_EPOCH - START_EPOCH))

if [ "$ERROR" -eq 0 ]; then
	printf "\nFinished at: %s\nTotal duration: %d seconds\n" "$END_TIME" "$DURATION"
else
	printf "\nOne or more commands failed by: %s\nTotal runtime: %d seconds\n" "$END_TIME" "$DURATION"
fi
