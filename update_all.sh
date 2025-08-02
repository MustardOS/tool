#!/bin/sh

sudo -v

START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
START_EPOCH=$(date +%s)

printf "Started at: %s\n\n" "$START_TIME"

DEVICES="A133 H700"
ERROR=0

for DEV in $DEVICES; do
	IMG="${DEV}-ROOTFS.img"

	printf "Updating RootFS for %s...\n" "$DEV"
	./update_rootfs.sh "$DEV" "$IMG" || {
		printf "\n%s RootFS Update Failed\n" "$DEV"
		ERROR=1
	}

	printf "Compressing Image for %s...\n" "$DEV"
	./compress_gzip.sh "$DEV" || {
		printf "\n%s Image Compression Failed\n" "$DEV"
		ERROR=1
	}
done

END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
END_EPOCH=$(date +%s)
DURATION=$((END_EPOCH - START_EPOCH))

if [ "$ERROR" -eq 0 ]; then
	printf "\nFinished at: %s\nTotal duration: %d seconds\n" "$END_TIME" "$DURATION"
else
	printf "\nOne or more commands failed by: %s\nTotal runtime: %d seconds\n" "$END_TIME" "$DURATION"
fi
