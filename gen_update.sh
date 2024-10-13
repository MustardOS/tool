#!/bin/sh

for CMD in git zip unzip; do
	if ! command -v "$CMD" >/dev/null 2>&1; then
		printf "Error: Missing required command '%s'\n" "$CMD" >&2
		exit 1
	fi
done

# Exit immediately if a command exits with a non-zero status
set -e

VERSION="2410.2-BANANA"

REPO_ROOT="Repo/MustardOS"
REPO_FRONTEND="frontend"
REPO_INTERNAL="internal"

REL_DIR="$(pwd)"
CHANGE_DIR="$REL_DIR/.CHANGE.$$"
UPDATE_DIR="$REL_DIR/.UPDATE.$$"
MU_UDIR="$REL_DIR/UPDATE"

# Ensure temporary directories are cleaned up on exit - also on ctrl+c and anything else
trap 'rm -rf "$CHANGE_DIR" "$UPDATE_DIR" "$HOME/$REPO_ROOT/$REPO_INTERNAL/update.sh"' EXIT INT TERM

# Check for at least two arguments - commits and then mount points
if [ "$#" -lt 2 ]; then
	printf "Usage: %s <FROM_COMMIT> <TO_COMMIT> <MOUNT_POINT> [MOUNT_POINT ...]\n" "$0" >&2
	exit 1
fi

FROM_COMMIT="$1"
TO_COMMIT="$2"
shift 2

# Collect remaining arguments as mount points
if [ "$#" -ge 1 ]; then
	:
else
	printf "Error: Missing mount points!\n" >&2
	exit 1
fi

ARCHIVE_NAME="muOS-$VERSION-$TO_COMMIT-UPDATE.zip"

# Create temporary directory structure for both update archive and diff file stuff
mkdir -p "$MU_UDIR" "$CHANGE_DIR" "$UPDATE_DIR/opt/muos/extra" "$UPDATE_DIR/mnt/mmc/MUOS"

# Update frontend binaries
rsync -a "$HOME/$REPO_ROOT/$REPO_FRONTEND/bin/" "$UPDATE_DIR/opt/muos/extra/"

# Let's go to the internal directory - away we go!
cd "$HOME/$REPO_ROOT/$REPO_INTERNAL"

# Grab the file diff of all changes based on commit to commit
git diff --name-status "$FROM_COMMIT" "$TO_COMMIT" >"$CHANGE_DIR/commit.txt"

# Create 'deleted.txt' file containing deleted files
grep '^D' "$CHANGE_DIR/commit.txt" | cut -f2 >"$CHANGE_DIR/deleted.txt"

# Create 'update.sh' file at /opt/ so the archive manager can run it
printf '#!/bin/sh\n' >"update.sh"
printf "\n. /opt/muos/script/var/func.sh\n" >>"update.sh"
printf "\nMUOS_MAIN_PATH=\$(GET_VAR \"device\" \"storage/rom/mount\")\n" >>"update.sh"

# Check if there are any deleted files
if [ -s "$CHANGE_DIR/deleted.txt" ]; then
	{
		while IFS= read -r FILE; do
			case "$FILE" in
				init/*)
					# Generate deletion commands for both /mnt/mmc and /mnt/sdcard - or whatever is set in device config
					for MOUNT_POINT in "$@"; do
						D_PATH="/mnt/$MOUNT_POINT/MUOS/${FILE#init/}"
						SAFE_D_PATH=$(printf '%s' "$D_PATH" | sed 's/["\\]/\\&/g')
						printf '\n[ -e "%s" ] && rm -f "%s"\n' "$SAFE_D_PATH" "$SAFE_D_PATH"
					done
					;;
				*)
					D_PATH="/opt/muos/$FILE"
					SAFE_D_PATH=$(printf '%s' "$D_PATH" | sed 's/["\\]/\\&/g')
					printf '\n[ -e "%s" ] && rm -f "%s"\n' "$SAFE_D_PATH" "$SAFE_D_PATH"
					;;
			esac
		done <"$CHANGE_DIR/deleted.txt"
	} >>"update.sh"
fi

{
	printf "\nsed -i '2s/.*/%s/' /opt/muos/config/version.txt" "$TO_COMMIT"
	printf "\n/opt/muos/script/system/halt.sh reboot"
} >>"update.sh"

# Make the 'update.sh' executable and copy it to the archive structure
chmod +x "update.sh"
mkdir -p "$UPDATE_DIR/opt"
cp "update.sh" "$UPDATE_DIR/opt/update.sh"

# Copy added and modified files into the '.update' directory
grep -E '^(A|M)' "$CHANGE_DIR/commit.txt" | cut -f2 >"$CHANGE_DIR/archived.txt"
while IFS= read -r FILE; do
	if [ -e "$FILE" ]; then
		case "$FILE" in
			init/*)
				for MOUNT_POINT in "$@"; do
					D_PATH="$UPDATE_DIR/mnt/$MOUNT_POINT/${FILE#init/}"
					mkdir -p "$(dirname "$D_PATH")"
					cp "$FILE" "$D_PATH"
				done
				;;
			*)
				D_PATH="$UPDATE_DIR/opt/muos/$FILE"
				mkdir -p "$(dirname "$D_PATH")"
				cp "$FILE" "$D_PATH"

				;;
		esac
	else
		printf "Warning: File '%s' does not exist and will not be copied!\n" "$FILE"
	fi
done <"$CHANGE_DIR/archived.txt"

cd "$UPDATE_DIR" || exit 1
find . -name ".gitkeep" -delete
chmod -R 755 .
chown -R "$(whoami):$(whoami)" ./*
zip -r "$MU_UDIR/$ARCHIVE_NAME" .
cd ..

printf "Archive Created: %s\n" "$MU_UDIR/$ARCHIVE_NAME"
unzip -l "$MU_UDIR/$ARCHIVE_NAME"
