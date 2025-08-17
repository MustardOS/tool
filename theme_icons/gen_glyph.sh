#!/bin/sh

# Examples:
#   ./svg2png.sh -m glyph.csv -w 192
#   ./svg2png.sh -m glyph.csv -w 192,128,48,24 -o ./theme
#   ./svg2png.sh -m glyph.csv -w 192,128 -s ./icons

set -u

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
CYAN='\033[36m'
BOLD='\033[1m'
RESET='\033[0m'

USAGE() {
	printf "Usage: %s -m <mapping.csv> -w <width[,width2,...]> [-s <dir>] [-o <output_dir>]\n" "$0"
	printf "  -m, --map      CSV mapping file with columns: MUX_MODULE,MUX_GLYPH,PNG_ICONS (relative to script dir)\n"
	printf "  -w, --width    Widths: a single value or comma/space-separated list (e.g. 24,48)\n"
	printf "  -s, --search   Root directory to search for PNG files (defaults to script dir)\n" >&2
	printf "  -o, --output   Output directory root (defaults to <script_dir>/output)\n"
	printf "  -h, --help     Show this help and exit\n"
}

SCRIPT_DIR=$(CDPATH='' cd "$(dirname "$0")" 2>/dev/null && pwd -P)

CSV_FILE=
WIDTHS=
SEARCH_ROOT=
OUT_DIR=

while [ $# -gt 0 ]; do
	case "$1" in
		-m | --map)
			[ $# -ge 2 ] || {
				printf "Error: %s requires a value\n" "$1"
				USAGE
				exit 1
			}
			CSV_FILE=$2
			shift 2
			;;
		-w | --width)
			[ $# -ge 2 ] || {
				printf "Error: %s requires a value\n" "$1"
				USAGE
				exit 1
			}
			WIDTHS=$2
			shift 2
			;;
		-s | --search)
			[ $# -ge 2 ] || {
				printf "Error: %s requires a value\n" "$1"
				USAGE
				exit 1
			}
			SEARCH_ROOT=$2
			shift 2
			;;
		-o | --output)
			[ $# -ge 2 ] || {
				printf "Error: %s requires a value\n" "$1"
				USAGE
				exit 1
			}
			OUT_DIR=$2
			shift 2
			;;
		-h | --help)
			USAGE
			exit 0
			;;
		--)
			shift
			break
			;;
		*)
			printf "Unknown option: %s\n" "$1"
			USAGE
			exit 1
			;;
	esac
done

[ -n "$SEARCH_ROOT" ] || SEARCH_ROOT=$SCRIPT_DIR
[ -n "$OUT_DIR" ] || OUT_DIR="$SCRIPT_DIR/output"

case "$CSV_FILE" in
	/*) : ;;
	*) CSV_FILE="$SCRIPT_DIR/$CSV_FILE" ;;
esac

SEARCH_ROOT=$(CDPATH='' cd "$SEARCH_ROOT" 2>/dev/null && pwd -P)

if [ -z "$CSV_FILE" ] || [ -z "$WIDTHS" ]; then
	printf "Error: -m/--map and -w/--width are required\n"
	USAGE
	exit 1
fi

[ -r "$CSV_FILE" ] || {
	printf "Error: cannot read mapping file %s\n" "$CSV_FILE"
	exit 1
}

[ -d "$SEARCH_ROOT" ] || {
	printf "Error: search root %s does not exist or is not a directory\n" "$SEARCH_ROOT"
	exit 1
}

mkdir -p "$OUT_DIR" || {
	printf "Error: cannot create output root %s\n" "$OUT_DIR"
	exit 1
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

for W in $WIDTH_LIST; do
	mkdir -p "$OUT_DIR/$W" || {
		printf "Error: cannot create width directory %s/%s\n" "$OUT_DIR" "$W"
		exit 1
	}
done

for W in $WIDTH_LIST; do
	printf "%bProcessing width %s%b\n" "$BLUE" "$W" "$RESET"

	OLDIFS=$IFS
	IFS=,

	(
		cd "$SEARCH_ROOT" || exit 1

		while read -r MUX_MODULE MUX_GLYPH PNG_ICONS; do
			MUX_MODULE=$(printf "%s" "$MUX_MODULE" | tr -d '\r')
			MUX_GLYPH=$(printf "%s" "$MUX_GLYPH" | tr -d '\r')
			PNG_ICONS=$(printf "%s" "$PNG_ICONS" | tr -d '\r')

			[ -n "$MUX_MODULE" ] || continue
			case "$MUX_MODULE" in \#* | "MUX_MODULE") continue ;; esac

			DST_DIR="$OUT_DIR/$W/$MUX_MODULE"
			mkdir -p "$DST_DIR" || {
				printf "%b%bWARN%b [w=%s]\tCannot create %s\n" "$YELLOW" "$BOLD" "$RESET" "$W" "$DST_DIR"
				continue
			}

			ICON_PATH=$(find . -type f -name "${PNG_ICONS}.png" -path "*/$W/*" 2>/dev/null | head -n 1)

			if [ -n "$ICON_PATH" ] && [ -f "$ICON_PATH" ]; then
				if cp "$ICON_PATH" "$DST_DIR/${MUX_GLYPH}.png"; then
					printf "%b%bOKAY%b [w=%s]\t%s/%s <= %s\n" "$GREEN" "$BOLD" "$RESET" "$W" "$MUX_MODULE" "${MUX_GLYPH}.png" "$ICON_PATH"
				else
					printf "%b%bFAIL%b [w=%s]\tCannot copy %s to %s\n" "$CYAN" "$BOLD" "$RESET" "$W" "$ICON_PATH" "$DST_DIR/${MUX_GLYPH}.png"
				fi
			else
				printf "%b%bMISS%b [w=%s]\tCannot find %s (looked for */%s/*/%s.png under %s)\n" "$RED" "$BOLD" "$RESET" "$W" "$PNG_ICONS" "$W" "$PNG_ICONS" "$SEARCH_ROOT"
			fi
		done <"$CSV_FILE"
	)

	IFS=$OLDIFS
done
