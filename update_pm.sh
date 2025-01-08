#!/bin/sh

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
CYAN='\033[36m'
BOLD='\033[1m'
RESET='\033[0m'

REPO_ROOT="${REPO_ROOT:-Repo/MustardOS}"
REPO_FRONTEND="${REPO_FRONTEND:-frontend}"
REPO_INTERNAL="${REPO_INTERNAL:-internal}"

for CMD in curl md5sum unzip; do
	if ! command -v "$CMD" >/dev/null 2>&1; then
		printf "%bError%b Missing required command '%b%s%b'\n" \
			"$RED" "$RESET" "$BOLD" "$CMD" "$RESET" >&2
		exit 1
	fi
done

printf "\n=============== %b%b muOS PortMaster Update Utility (MUPUU) %b===============\n\n" "$BLUE" "$BOLD" "$RESET"

PM_ZIP_URL="https://github.com/PortsMaster/PortMaster-GUI/releases/latest/download/muos.portmaster.zip"
PM_MD5_URL="https://github.com/PortsMaster/PortMaster-GUI/releases/latest/download/muos.portmaster.zip.md5"
PM_INTERNAL="$HOME/$REPO_ROOT/$REPO_INTERNAL/PortMaster"
PM_INTERNAL_INIT="$HOME/$REPO_ROOT/$REPO_INTERNAL/init/MUOS/PortMaster"
PM_TEMP_DIR=$(mktemp -d)

printf "%b%b- Deleting%b %s\n" "$YELLOW" "$BOLD" "$RESET" "$PM_INTERNAL_INIT"
rm -rf "$PM_INTERNAL_INIT"

printf "%b%b- Recreating%b %s\n" "$YELLOW" "$BOLD" "$RESET" "$PM_INTERNAL"
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

	ZIP_SIZE=$(stat -c%s "$PM_TEMP_DIR/muos.portmaster.zip")
	printf "%b%b- Extracting PortMaster (%s bytes) to %b%s\n" "$CYAN" "$BOLD" "$ZIP_SIZE" "$RESET" "$PM_INTERNAL_INIT"

	UZ_TEMP_DIR=$(mktemp -d)
	unzip -q -o "$PM_TEMP_DIR/muos.portmaster.zip" -d "$UZ_TEMP_DIR"

	PM_ARCHIVE_DIR="mnt/mmc/MUOS/PortMaster"
	mv "$UZ_TEMP_DIR/$PM_ARCHIVE_DIR" "$PM_INTERNAL_INIT"

	rm -rf "$UZ_TEMP_DIR"

	printf "%b%b- Copying PortMaster archive (%s bytes) to %b%s\n" "$CYAN" "$BOLD" "$ZIP_SIZE" "$RESET" "$PM_INTERNAL"
	cp "$PM_TEMP_DIR/muos.portmaster.zip" "$PM_INTERNAL/."
else
	printf "%b%b- MD5 checksum verification failed%b\n" "$RED" "$BOLD" "$RESET"
	rm -rf "$PM_TEMP_DIR"
	exit 1
fi

rm -rf "$PM_TEMP_DIR"
printf "\n%b%b- PortMaster update completed successfully%b\n\n" "$GREEN" "$BOLD" "$RESET"
