#!/bin/sh

USAGE() {
	echo "Usage: $0 [CONTENT_DIR] [SORT_ORDER] [OUTPUT_MODE] [FILTER/DEPTH]"
	echo ""
	echo "Options:"
	echo "  CONTENT_DIR       Directory to list contents (default: current directory)"
	echo "  SORT_ORDER        Sorting order:"
	echo "                      name     - Alphabetical order"
	echo "                      ntime    - Newest first (by modification time)"
	echo "                      otime    - Oldest first (by modification time)"
	echo "                      lsize    - Largest files first"
	echo "                      ssize    - Smallest files first"
	echo "                      reverse  - Reverse alphabetical order"
	echo "                      files    - List only files"
	echo "                      dirs     - List only directories"
	echo "                      sumsize  - Show total size of files"
	echo "                      count    - Show count of files and directories"
	echo "                      hidden   - Include hidden files"
	echo "                      recursive - Recursive listing (optional depth)"
	echo ""
	echo "  OUTPUT_MODE       Output format:"
	echo "                      long     - Detailed output (default)"
	echo "                      short    - Short filenames only"
	echo "                      color    - Enable colored output (if supported)"
	echo ""
	echo "  FILTER/DEPTH      Optional:"
	echo "                      - Filter files by extension (e.g., txt, png)"
	echo "                      - Specify recursion depth for 'files', 'dirs', or 'recursive'"
	echo ""
	echo "Examples:"
	echo "  $0 ./content name              # List contents alphabetically (default long format)"
	echo "  $0 ./content name short        # Short filenames only"
	echo "  $0 ./content name long txt     # List only '.txt' files"
	echo "  $0 ./content files short 2     # List files with max depth of 2"
	echo "  $0 ./content dirs short        # List directories only"
	echo "  $0 ./content count             # Show file and directory count"
	echo "  $0 ./content sumsize           # Display total file size"
	echo "  $0 ./content recursive 3       # Recursive listing up to depth 3"
	echo ""
	exit 1
}

VALIDATE_DEPTH() {
	case "$1" in
		'' | *[!0-9]*) printf "Error: Depth must be a positive integer\n" && exit 1 ;;
		*) [ "$1" -lt 1 ] && printf "Error: Depth cannot be zero or negative\n" && exit 1 ;;
	esac
}

[ "$1" = "--help" ] || [ "$1" = "-h" ] && USAGE

CONTENT_DIR="${1:-.}"
SORT_ORDER="${2:-name}"
OUTPUT_MODE="long"
case "$3" in
	long | short | color)
		OUTPUT_MODE="$3"
		FILTER_OR_DEPTH="$4"
		;;
	*) FILTER_OR_DEPTH="$3" ;;
esac

[ ! -d "$CONTENT_DIR" ] && printf "Error: '%s' is not a valid directory.\n" "$CONTENT_DIR"

LS_FLAG="-l"
[ "$OUTPUT_MODE" = "short" ] && LS_FLAG="-1"
[ "$OUTPUT_MODE" = "color" ] && LS_FLAG="$LS_FLAG --color=auto"

case "$SORT_ORDER" in
	name)
		DEPTH="${FILTER_OR_DEPTH:-1}"
		VALIDATE_DEPTH "$DEPTH"
		EXT_FILTER="${5:-}"
		if [ -n "$EXT_FILTER" ]; then
			find "$CONTENT_DIR" -maxdepth "$DEPTH" -type f -name "*.$EXT_FILTER"
		else
			find "$CONTENT_DIR" -maxdepth "$DEPTH" -type f
		fi
		;;
	ntime) ls "$LS_FLAG" -t "$CONTENT_DIR" ;;
	otime) ls "$LS_FLAG" -tr "$CONTENT_DIR" ;;
	lsize) ls "$LS_FLAG" -S "$CONTENT_DIR" ;;
	ssize) ls "$LS_FLAG" -Sr "$CONTENT_DIR" ;;
	reverse) ls "$LS_FLAG" -r "$CONTENT_DIR" ;;
	files)
		DEPTH="${FILTER_OR_DEPTH:-1}"
		VALIDATE_DEPTH "$DEPTH"
		find "$CONTENT_DIR" -maxdepth "$DEPTH" -type f | sort
		;;
	dirs)
		DEPTH="${FILTER_OR_DEPTH:-1}"
		VALIDATE_DEPTH "$DEPTH"
		find "$CONTENT_DIR" -maxdepth "$DEPTH" -type d | sort
		;;
	sumsize)
		DEPTH="${FILTER_OR_DEPTH:-1}"
		VALIDATE_DEPTH "$DEPTH"
		find "$CONTENT_DIR" -maxdepth "$DEPTH" -type f -exec du -h {} + |
			awk '{sum += $1} END {printf "Total size: %d bytes\n", sum}'
		;;
	count)
		DEPTH="${FILTER_OR_DEPTH:-1}"
		VALIDATE_DEPTH "$DEPTH"
		C_FILE=$(find "$CONTENT_DIR" -maxdepth "$DEPTH" -type f | wc -l)
		C_DIR=$(find "$CONTENT_DIR" -maxdepth "$DEPTH" -type d | wc -l)
		printf "Files: %d\nDirectories: %d\n" "$C_FILE" "$C_DIR"
		;;
	hidden) ls "$LS_FLAG" -A "$CONTENT_DIR" ;;
	recursive)
		DEPTH="${FILTER_OR_DEPTH:-}"
		if [ -n "$DEPTH" ]; then
			VALIDATE_DEPTH "$DEPTH"
			find "$CONTENT_DIR" -maxdepth "$DEPTH"
		else
			find "$CONTENT_DIR"
		fi
		;;
	*)
		printf "Error: Invalid sorting order\n" >&2
		USAGE
		;;
esac
