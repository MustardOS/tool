#!/bin/sh

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
CYAN='\033[36m'
BOLD='\033[1m'
RESET='\033[0m'

for CMD in curl md5sum; do
	if ! command -v "$CMD" >/dev/null 2>&1; then
		printf "%bError%b Missing required command '%b%s%b'\n" \
			"$RED" "$RESET" "$BOLD" "$CMD" "$RESET" >&2
		exit 1
	fi
done

REPO_ROOT="${REPO_ROOT:-Repo/MustardOS}"
REPO_INTERNAL="${REPO_INTERNAL:-internal}"

PM_ZIP_URL="https://github.com/PortsMaster/PortMaster-GUI/releases/latest/download/muos.portmaster.zip"
PM_MD5_URL="https://github.com/PortsMaster/PortMaster-GUI/releases/latest/download/muos.portmaster.zip.md5"

PM_INTERNAL="$HOME/$REPO_ROOT/$REPO_INTERNAL/share/archive"

PM_TEMP_DIR=$(mktemp -d)

printf "\n=============== %b%b MustardOS PortMaster Updater (MUPMU) %b===============\n\n" "$BLUE" "$BOLD" "$RESET"

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
	printf "\t%b%b- Copying PortMaster archive (%s) to %b%s\n" "$GREEN" "$BOLD" "$PM_SIZE" "$RESET" "${PM_INTERNAL#$HOME/$REPO_ROOT/}"
	cp "$PM_TEMP_DIR/muos.portmaster.zip" "$PM_INTERNAL/."
else
	printf "%b%b- MD5 checksum verification failed%b\n" "$RED" "$BOLD" "$RESET"
	rm -rf "$PM_TEMP_DIR"
	exit 1
fi

rm -rf "$PM_TEMP_DIR"
printf "%b%b- PortMaster update completed successfully%b\n\n" "$GREEN" "$BOLD" "$RESET"
