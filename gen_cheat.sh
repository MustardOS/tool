#!/bin/sh

for CMD in git zip; do
	command -v "$CMD" >/dev/null 2>&1 || {
		printf "Error: Missing required command '%s'\n" "$CMD" >&2
		exit 1
	}
done

set -e

ARC_EXT="muxzip"
ARC_PREFIX="MustardOS_Cheats_"
LIBRETRO_DB="libretro-database"
REPO_URL="https://github.com/libretro/$LIBRETRO_DB.git"
REPO_DIR="/tmp/repo/$LIBRETRO_DB"
CHT_REL="cht"
OUT_DIR="${1:-./CHEATS}"

[ -d "$OUT_DIR" ] && rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

PWD_OLD=$PWD
cd "$OUT_DIR" || exit 1

OUT_ABS=$PWD
cd "$PWD_OLD" || exit 1

printf "\n=============== \033[1mMustardOS Cheat Updater (MUCU)\033[0m ==============\n\n"

printf "\033[1mCloning latest '%s' repository\033[0m\n" "$LIBRETRO_DB"
N_PROC=$(nproc 2>/dev/null || printf "1")
git clone --recurse-submodules --jobs "$N_PROC" "$REPO_URL" "$REPO_DIR"
printf "\n"

CHT_DIR="$REPO_DIR/$CHT_REL"
[ -d "$CHT_DIR" ] || {
	printf "Error: Not found: %s\n" "$CHT_DIR" >&2
	rm -rf "$REPO_DIR"
	exit 1
}

TMP_ROOT=$(mktemp -d)
STAGE_ROOT="$TMP_ROOT/stage"
mkdir -p "$STAGE_ROOT/cheats"

printf "\033[1mCreating Individual Archives\033[0m\n"
find "$CHT_DIR" -mindepth 1 -maxdepth 1 -type d -print | while IFS= read -r DIR; do
	NAME=$(basename "$DIR")

	mkdir -p "$STAGE_ROOT/cheats/$NAME"
	cp -R "$DIR"/. "$STAGE_ROOT/cheats/$NAME"/ 2>/dev/null || true

	NEW_ARC_NAME=$(printf "%s" "$NAME" | sed 's/[()]//g; s/ - /_/g; s/ +/_/g; s/[^A-Za-z0-9_]/_/g')
	ARCHIVE_SYS="$OUT_ABS/${ARC_PREFIX}${NEW_ARC_NAME}.${ARC_EXT}"
	printf "\t%s\n" "${ARC_PREFIX}${NEW_ARC_NAME}.${ARC_EXT}"

	(
		cd "$STAGE_ROOT" || exit 1
		zip -rq9 "$ARCHIVE_SYS" "cheats/$NAME"
	) || {
		printf "\tError: zip failed for %s\n" "$ARCHIVE_SYS" >&2
		exit 1
	}
done

if ! find "$CHT_DIR" -mindepth 1 -maxdepth 1 -type d -print -quit | grep -q .; then
	printf "\nWarning: No systems found in %s\n" "$CHT_DIR" >&2
fi

EV="${ARC_PREFIX}Everything.${ARC_EXT}"
printf "\n\033[1mCreating Everything Archive\033[0m\n\t%s\n" "$EV"

ARCHIVE_ALL="$OUT_ABS/${EV}"

(
	cd "$STAGE_ROOT" || exit 1
	zip -rq9 "$ARCHIVE_ALL" "cheats"
) || {
	printf "Error: zip failed for %s\n" "$ARCHIVE_ALL" >&2
	rm -rf "$TMP_ROOT"
	exit 1
}

rm -rf "$TMP_ROOT" "$REPO_DIR"

printf "\n\033[1mArchives Created: \033[0m%s\n\n" "$OUT_ABS"
