#!/bin/sh

OUTDIR="BASECORE"
REPO="MustardOS/extra"

rm -rf "$OUTDIR"
mkdir -p "$OUTDIR"

URLS=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" |
	grep '"browser_download_url"' |
	sed -E 's/.*"browser_download_url": "(.*)".*/\1/' |
	grep '/Base')

TOTAL=$(printf "%s\n" "$URLS" | wc -l)

CURRENT=0
printf "%s\n" "$URLS" | while IFS= read -r URL; do
	CURRENT=$((CURRENT + 1))
	FILE=$(basename "$URL")

	printf "\r\033[K(%d/%d) Downloading %s" "$CURRENT" "$TOTAL" "$FILE"

	curl -L --fail -s "$URL" -o "$OUTDIR/$FILE"
done

printf "\n%d base cores downloaded...\n" "$TOTAL"
