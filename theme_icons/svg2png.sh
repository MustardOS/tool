#!/bin/sh

# Examples:
#   ./svg2png.sh -w 192
#   ./svg2png.sh -w 192,128,48,24
#   ./svg2png.sh -w 192,128 -s ./icons

set -u

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
CYAN='\033[36m'
BOLD='\033[1m'
RESET='\033[0m'

USAGE() {
	printf "Usage: %s -w <width[,width2,...]> [-s|--search <dir>] [-p|--purge]\n" "$0" >&2
	printf "  -w, --width    Widths: a single value or comma/space-separated list (e.g. 24,48)\n"
	printf "  -s, --search   Root directory to search for SVG files (defaults to script dir)\n" >&2
	printf "  -p, --purge    Delete source SVG after successful export\n" >&2
	exit 2
}

FINISH() {
	STOP=1
	[ -n "${INK_PID}" ] && kill -INT "$INK_PID" >/dev/null 2>&1
	[ -n "${TMP_C}" ] && [ -f "${TMP_C}" ] && rm -f "${TMP_C}"
	printf "\nInterrupted. Stopping after the current file.\n" >&2
}
trap FINISH INT

SCRIPT_DIR=$(CDPATH='' cd "$(dirname "$0")" 2>/dev/null && pwd -P)

WIDTHS="256"

PURGE=0
STOP=0

INK_PID=""
TMP_C=""

SEARCH_ROOT=""

while [ "$#" -gt 0 ]; do
	case "$1" in
		-w | --width)
			[ "$#" -ge 2 ] || USAGE
			WIDTHS=$2
			shift 2
			;;
		-s | --search)
			[ "$#" -ge 2 ] || USAGE
			SEARCH_ROOT=$2
			shift 2
			;;
		-p | --purge)
			PURGE=1
			shift
			;;
		-h | --help)
			USAGE
			;;
		*)
			USAGE
			;;
	esac
done

[ -n "$SEARCH_ROOT" ] || SEARCH_ROOT="$SCRIPT_DIR"

SEARCH_ROOT=$(CDPATH='' cd "$SEARCH_ROOT" 2>/dev/null && pwd -P) || {
	printf "Search root does not exist or is not a directory: %s\n" "$SEARCH_ROOT" >&2
	exit 2
}

WIDTH_LIST=$(printf "%s" "$WIDTHS" | tr ',' ' ')
VALIDATED=""
for W in $WIDTH_LIST; do
	case "$W" in
		'' | *[!0-9]*)
			printf "Invalid width: %s (must be a positive integer)\n" "$W" >&2
			exit 2
			;;
		0)
			printf "Invalid width: 0\n" >&2
			exit 2
			;;
		*)
			VALIDATED="$VALIDATED $W"
			;;
	esac
done
WIDTH_LIST=${VALIDATED# }

TOTAL=$(find "$SEARCH_ROOT" -type d -name __MACOSX -prune -o -type f -iname '*.svg' ! -name '._*' -print | wc -l)
if [ "$TOTAL" -eq 0 ]; then
	printf "No SVG files found under: %s\n" "$SEARCH_ROOT"
	exit 0
fi

IDX=0

find "$SEARCH_ROOT" -type d -name __MACOSX -prune -o -type f -iname '*.svg' ! -name '._*' -print0 |
	while IFS= read -r -d '' SVG; do
		[ "$STOP" -ne 0 ] && break
		IDX=$((IDX + 1))

		SVG_DIR=$(dirname "$SVG")
		SVG_BASE_EXT=$(basename "$SVG")
		SVG_BASE=${SVG_BASE_EXT%.*}

		printf "(%d of %d) %b%b%s%b\n" "$IDX" "$TOTAL" "$CYAN" "$BOLD" "$SVG" "$RESET"

		for W in $WIDTH_LIST; do
			[ "$STOP" -ne 0 ] && break
			OUT_DIR="${SVG_DIR}/${W}"

			mkdir -p "$OUT_DIR" || {
				printf "%b%bFailed to create%b: %s\n" "$RED" "$BOLD" "$RESET" "$OUT_DIR" >&2
				continue
			}

			OUT_PNG="${OUT_DIR}/${SVG_BASE}.png"

			if [ -e "$OUT_PNG" ]; then
				printf "  - %b%bSkipping%b [%s]:\t%s Exists\n" "$YELLOW" "$BOLD" "$RESET" "$W" "${SVG_BASE}.png"
				continue
			fi

			printf "  - %b%bExporting%b [%s]:\t%s -> %s\n" "$GREEN" "$BOLD" "$RESET" "$W" "${SVG_BASE_EXT}" "${SVG_BASE}.png"

			INK_PID=""
			inkscape --batch-process \
				--export-type=png \
				--export-width="${W}" \
				--export-filename="${OUT_PNG}" \
				--export-background-opacity=0 \
				--export-area-page \
				"$SVG" >/dev/null 2>&1 &
			INK_PID=$!

			wait "$INK_PID"

			INK_STATUS=$?
			INK_PID=""

			[ "$STOP" -ne 0 ] && break

			if [ $INK_STATUS -ne 0 ] || [ ! -s "$OUT_PNG" ]; then
				printf "    %b%b! Inkscape convert failed%b: %s (width %s)\n" "$RED" "$BOLD" "$RESET" "$SVG" "$W" >&2
				continue
			fi

			if ! mogrify -alpha on -channel RGB -evaluate set 0 +channel "$OUT_PNG" 2>/dev/null; then
				if ! magick "$OUT_PNG" -alpha on -channel RGB -evaluate set 0 +channel "$OUT_PNG" 2>/dev/null; then
					printf "    %b%b! ImageMagick step failed%b: %s\n" "$RED" "$BOLD" "$RESET" "$OUT_PNG" >&2
				fi
			fi

			TMP_C="${OUT_PNG}.crush.$$"
			if pngcrush -q -brute "$OUT_PNG" "$TMP_C" >/dev/null 2>&1; then
				mv -f "$TMP_C" "$OUT_PNG"
			else
				rm -f "$TMP_C"
				printf "    %b%b! PNG crushing failed%b: %s\n" "$RED" "$BOLD" "$RESET" "$OUT_PNG"
			fi
			TMP_C=""
		done

		[ "$PURGE" -eq 1 ] && rm -f "$SVG"
	done
