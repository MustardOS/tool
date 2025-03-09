#!/bin/sh

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
CYAN='\033[36m'
BOLD='\033[1m'
RESET='\033[0m'

for CMD in curl jq md5sum unzip; do
	if ! command -v "$CMD" >/dev/null 2>&1; then
		printf "%bError%b Missing required command '%b%s%b'\n" \
			"$RED" "$RESET" "$BOLD" "$CMD" "$RESET" >&2
		exit 1
	fi
done

REPO_ROOT="${REPO_ROOT:-Repo/MustardOS}"
REPO_FRONTEND="${REPO_FRONTEND:-frontend}"
REPO_INTERNAL="${REPO_INTERNAL:-internal}"

ARCH="aarch64"

PM_RUN_URL="https://github.com/PortsMaster/PortMaster-New/releases/latest/download/ports.json"
PM_ZIP_URL="https://github.com/PortsMaster/PortMaster-GUI/releases/latest/download/muos.portmaster.zip"
PM_MD5_URL="https://github.com/PortsMaster/PortMaster-GUI/releases/latest/download/muos.portmaster.zip.md5"

PM_INTERNAL="$HOME/$REPO_ROOT/$REPO_INTERNAL/share/archive"
PM_INTERNAL_INIT="$HOME/$REPO_ROOT/$REPO_INTERNAL/init/MUOS/PortMaster"
PM_LIB_DIR="$PM_INTERNAL_INIT/libs"

PM_TEMP_DIR=$(mktemp -d)

printf "\n=============== %b%b muOS PortMaster Updater (MUPMU) %b===============\n\n" "$BLUE" "$BOLD" "$RESET"

printf "%b%b- Deleting%b %s\n" "$YELLOW" "$BOLD" "$RESET" "${PM_INTERNAL_INIT#$HOME/$REPO_ROOT/}"
rm -rf "$PM_INTERNAL_INIT"

printf "%b%b- Recreating%b %s\n" "$YELLOW" "$BOLD" "$RESET" "${PM_INTERNAL#$HOME/$REPO_ROOT/}"
rm -rf "$PM_INTERNAL"
mkdir -p "$PM_INTERNAL"

printf "\n%b%b- Downloading ZIP%b %s\n" "$CYAN" "$BOLD" "$RESET" "$PM_ZIP_URL"
curl -fsSL -o "$PM_TEMP_DIR/muos.portmaster.zip" "$PM_ZIP_URL"

printf "%b%b- Downloading MD5%b %s\n\n" "$CYAN" "$BOLD" "$RESET" "$PM_MD5_URL"
curl -fsSL -o "$PM_TEMP_DIR/muos.portmaster.zip.md5" "$PM_MD5_URL"

EXPECTED_MD5=$(cat "$PM_TEMP_DIR/muos.portmaster.zip.md5")
printf "%b%b- Expecting MD5%b\t%s\n" "$BLUE" "$BOLD" "$RESET" "$EXPECTED_MD5"

printf "%b%b- Actual MD5" "$BLUE" "$BOLD"
ACTUAL_MD5=$(md5sum "$PM_TEMP_DIR/muos.portmaster.zip" | awk '{print $1}')
printf "%b\t%s\n" "$RESET" "$ACTUAL_MD5"

if [ "$EXPECTED_MD5" = "$ACTUAL_MD5" ]; then
	printf "%b%b- MD5 checksum verification passed%b\n\n" "$GREEN" "$BOLD" "$RESET"
	printf "%b%b- Extracting PortMaster to %b%s\n" "$CYAN" "$BOLD" "$RESET" "${PM_INTERNAL_INIT#$HOME/$REPO_ROOT/}"

	UZ_TEMP_DIR=$(mktemp -d)
	unzip -q -o "$PM_TEMP_DIR/muos.portmaster.zip" -d "$UZ_TEMP_DIR"

	PM_ARCHIVE_DIR="mnt/mmc/MUOS/PortMaster"
	mv "$UZ_TEMP_DIR/$PM_ARCHIVE_DIR" "$PM_INTERNAL_INIT"

	rm -rf "$UZ_TEMP_DIR"

	PM_SIZE=$(printf "%.2f MB" "$(echo "$(stat -c%s "$PM_TEMP_DIR/muos.portmaster.zip") / 1024 / 1024" | bc -l)")
	printf "\t%b%b- Copying PortMaster archive (%s) to %b%s\n" "$GREEN" "$BOLD" "$PM_SIZE" "$RESET" "${PM_INTERNAL#$HOME/$REPO_ROOT/}"
	cp "$PM_TEMP_DIR/muos.portmaster.zip" "$PM_INTERNAL/."
else
	printf "%b%b- MD5 checksum verification failed%b\n" "$RED" "$BOLD" "$RESET"
	rm -rf "$PM_TEMP_DIR"
	exit 1
fi

printf "\n%b%b- Downloading 'ports.json' from%b %s\n" "$CYAN" "$BOLD" "$RESET" "$PM_RUN_URL"
curl -fsSL -o "$PM_TEMP_DIR/ports.json" "$PM_RUN_URL"

if [ ! -f "$PM_TEMP_DIR/ports.json" ]; then
	printf "%b%b- Failed to download 'ports.json'%b\n" "$RED" "$BOLD" "$RESET"
	rm -rf "$PM_TEMP_DIR"
	exit 1
fi

printf "%b%b- Extracting URLs for '%s' runtimes%b\n" "$CYAN" "$BOLD" "$ARCH" "$RESET"
RUNTIME_URLS=$(jq -r '.utils[] | select(.runtime_arch == "aarch64") | .url' "$PM_TEMP_DIR/ports.json")
COUNT=$(echo "$RUNTIME_URLS" | wc -l)

if [ "$COUNT" -gt 0 ]; then
	printf "%b%b- Found %s runtimes%b\n\n" "$GREEN" "$BOLD" "$COUNT" "$RESET"

	for URL in $RUNTIME_URLS; do
		FILENAME=$(basename "$URL")
		printf "%b%b- Downloading runtime%b %s\n" "$CYAN" "$BOLD" "$RESET" "$FILENAME"
		curl -fsSL -o "$PM_TEMP_DIR/$FILENAME" "$URL"

		if [ -f "$PM_TEMP_DIR/$FILENAME" ]; then
			RUN_SIZE=$(printf "%.2f MB" "$(echo "$(stat -c%s "$PM_TEMP_DIR/$FILENAME") / 1024 / 1024" | bc -l)")
			printf "\t%b%b- Copying runtime %s (%s) to%b %s\n\n" "$GREEN" "$BOLD" "$FILENAME" "$RUN_SIZE" "$RESET" "${PM_LIB_DIR#$HOME/$REPO_ROOT/}"
			cp "$PM_TEMP_DIR/$FILENAME" "$PM_LIB_DIR/"
		else
			printf "\t%b%b- Failed to download%b %s\n\n" "$RED" "$BOLD" "$RESET" "$URL"
		fi
	done
else
	printf "\n%b%b- Found no runtimes for%b '%s'\n\n" "$GREEN" "$BOLD" "$RESET" "$ARCH"
fi

rm -rf "$PM_TEMP_DIR"
printf "%b%b- PortMaster update completed successfully%b\n\n" "$GREEN" "$BOLD" "$RESET"
