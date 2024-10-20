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
mkdir "$MU_UDIR"

STORAGE_LOCS="bios info/catalogue info/name retroarch info/config info/core info/favourite info/history music save screenshot theme language network syncthing"

# Ensure temporary directories are cleaned up on exit - also on ctrl+c and anything else
trap 'rm -rf "$CHANGE_DIR" "$UPDATE_DIR" "$HOME/$REPO_ROOT/$REPO_INTERNAL/update.sh"' EXIT INT TERM

# Check for at least two arguments - commits and then mount points
if [ "$#" -lt 2 ]; then
	printf "Usage: %s <FROM_COMMIT> <MOUNT_POINT>\n" "$0" >&2
	exit 1
fi

MOUNT_POINT="$2"
FROM_COMMIT="$1"

# Get the latest internal commit number - we don't really care much for the frontend commit ID :D
cd "$HOME/$REPO_ROOT/$REPO_INTERNAL"
TO_COMMIT="$(git rev-parse --short HEAD)"
COMMIT_DATE="$(git show -s --format=%ci "$1")"
git log --since="$COMMIT_DATE" --pretty=format:"%s%n%b" >"$MU_UDIR/changelog.txt"
git log --since="$COMMIT_DATE" --pretty=format:"%ae" >"$MU_UDIR/contributor.txt"

# Got to add a new line here otherwise we get some good ol' funky concatenation happening
printf "\n" >>"$MU_UDIR/changelog.txt"
printf "\n" >>"$MU_UDIR/contributor.txt"

# Now that we have the date from the commit given lets go into the frontend repo and grab the changes there too!
cd "$HOME/$REPO_ROOT/$REPO_FRONTEND"
git log --since="$COMMIT_DATE" --pretty=format:"%s%n%b" >>"$MU_UDIR/changelog.txt"
git log --since="$COMMIT_DATE" --pretty=format:"%ae" >>"$MU_UDIR/contributor.txt"
cd "$REL_DIR"

# Update the contributor file with unique users
TMP_CON=$(mktemp)
sed -e 's/[0-9]\{1,\}+//g' -e 's/@users\.noreply\.github\.com//g' "$MU_UDIR/contributor.txt" | sort | uniq >"$TMP_CON"
mv "$TMP_CON" "$MU_UDIR/contributor.txt"

ARCHIVE_NAME="muOS-$VERSION-$TO_COMMIT-UPDATE.zip"

# Create temporary directory structure for both update archive and diff file stuff
mkdir -p "$MU_UDIR" "$CHANGE_DIR" "$UPDATE_DIR/opt/muos/extra" "$UPDATE_DIR/opt/muos/backup/MUOS/info/config" "$UPDATE_DIR/mnt/mmc/MUOS"

# Update frontend binaries
rsync -a "$HOME/$REPO_ROOT/$REPO_FRONTEND/bin/" "$UPDATE_DIR/opt/muos/extra/"

# Update backup configs
rsync -a "$HOME/$REPO_ROOT/$REPO_INTERNAL/init/MUOS/info/config/" "$UPDATE_DIR/opt/muos/backup/MUOS/info/config/"

# Let's go to the internal directory - away we go!
cd "$HOME/$REPO_ROOT/$REPO_INTERNAL"

# Grab the file diff of all changes based on commit to commit
git diff --name-status --no-renames "$FROM_COMMIT" "$TO_COMMIT" >"$CHANGE_DIR/commit.txt"

# Create 'deleted.txt' file containing deleted files
grep '^D' "$CHANGE_DIR/commit.txt" | cut -f2 >"$CHANGE_DIR/deleted.txt"

# Create 'update.sh' file at /opt/ so the archive manager can run it
printf '#!/bin/sh\n' >"update.sh"
printf "\n. /opt/muos/script/var/func.sh\n" >>"update.sh"
printf "\nMUOS_MAIN_PATH=\$(GET_VAR \"device\" \"storage/rom/mount\")\n" >>"update.sh"

# Check for any deleted files
if [ -s "$CHANGE_DIR/deleted.txt" ]; then
	{
		while IFS= read -r FILE; do
			case "$FILE" in
				init/*)
					# Generate deletion commands for both /mnt/mmc and /mnt/sdcard - or whatever is set in device config
					MATCH_FOUND=0
					for S_LOC in $STORAGE_LOCS; do
						# Check if the directory part of the file matches STORAGE_LOCS
						if dirname "$FILE" | grep -q "$S_LOC"; then
							# If matched, generate deletion command with the storage path
							D_PATH="/run/muos/storage/$S_LOC/${FILE#init/MUOS/$S_LOC}"
							SAFE_D_PATH=$(printf '%s' "$D_PATH" | sed 's/["\\]/\\&/g')
							printf '\n[ -e "%s" ] && rm -f "%s"\n' "$SAFE_D_PATH" "$SAFE_D_PATH"
							MATCH_FOUND=1
							break
						fi
					done

					# If no match in STORAGE_LOCS, fall back to the default path
					if [ "$MATCH_FOUND" -eq 0 ]; then
						D_PATH="/mnt/$MOUNT_POINT/${FILE#init/}"
						SAFE_D_PATH=$(printf '%s' "$D_PATH" | sed 's/["\\]/\\&/g')
						printf '\n[ -e "%s" ] && rm -f "%s"\n' "$SAFE_D_PATH" "$SAFE_D_PATH"
					fi
					;;
				*)
					# For non-init files, default deletion path
					D_PATH="/opt/muos/$FILE"
					SAFE_D_PATH=$(printf '%s' "$D_PATH" | sed 's/["\\]/\\&/g')
					printf '\n[ -e "%s" ] && rm -f "%s"\n' "$SAFE_D_PATH" "$SAFE_D_PATH"
					;;
			esac
		done <"$CHANGE_DIR/deleted.txt"
	} >>"update.sh"
fi

# Add the halt reboot method - we want to reboot after the update!
printf "\n/opt/muos/script/system/halt.sh reboot" >>"update.sh"

# Update version.txt and copy update.sh to the correct directories
mkdir -p "$UPDATE_DIR/opt/muos/config"
printf '%s\n%s' "$(printf %s "$VERSION" | tr - ' ')" "$TO_COMMIT" >"$UPDATE_DIR/opt/muos/config/version.txt"
chmod +x "update.sh"
cp "update.sh" "$UPDATE_DIR/opt/update.sh"

# Copy added and modified files into the '.update' directory
grep -E '^(A|M)' "$CHANGE_DIR/commit.txt" | cut -f2 >"$CHANGE_DIR/archived.txt"
while IFS= read -r FILE; do
	if [ -e "$FILE" ]; then
		case "$FILE" in
			init/*)
				FILE_COPIED=0
				S_=0
				for _ in $STORAGE_LOCS; do
					S_LOC=$(echo "$STORAGE_LOCS" | cut -d' ' -f$((S_ + 1)))

					# Check if the directory part of the file matches STORAGE_LOCS
					if dirname "$FILE" | grep -q "$S_LOC"; then
						# Replace only the directory part, not the file name!
						D_PATH="$UPDATE_DIR/run/muos/storage/$S_LOC/${FILE#init/MUOS/$S_LOC}"
						mkdir -p "$(dirname "$D_PATH")"
						cp "$FILE" "$D_PATH"
						FILE_COPIED=1
						break
					fi

					S_=$((S_ + 1))
				done

				# If nothing matches in STORAGE_LOCS then fall back to the default path of the given mount
				if [ "$FILE_COPIED" -eq 0 ]; then
					D_PATH="$UPDATE_DIR/mnt/$MOUNT_POINT/${FILE#init/}"
					mkdir -p "$(dirname "$D_PATH")"
					cp "$FILE" "$D_PATH"
				fi
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
