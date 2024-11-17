#!/bin/sh

REPO_ROOT="${REPO_ROOT:-Repo/MustardOS}"
REPO_INTERNAL="${REPO_INTERNAL:-internal}"

# Check for all the required commands we'll be using from here on in
for CMD in aarch64-linux-strip aarch64-linux-objcopy file readelf; do
	if ! command -v "$CMD" >/dev/null 2>&1; then
		printf "Error: Missing required command '%s'\n" "$CMD" >&2
		exit 1
	fi
done

# Exit immediately if a command exits with a non-zero status
set -e

printf "\n=============== \033[1mmuOS RetroArch Core Stripper (MURCS)\033[0m ==============\n\n"

cd "$HOME/$REPO_ROOT/$REPO_INTERNAL/init/MUOS/core" || {
	printf "Internal RetroArch core directory missing (%s)\n" "$REPO_ROOT/$REPO_INTERNAL/init/MUOS/core"
	exit 1
}

for CORE in *.so; do
	if [ -f "$CORE" ]; then
		printf "Processing %s..." "$CORE"

		# Check if the CORE is not stripped
		if file "$CORE" | grep -q 'not stripped'; then
			aarch64-linux-strip -sx "$CORE"
			printf "\tStripped debug symbols..."
		else
			printf "\tCore is already stripped..."
		fi

		# Check if the BuildID section is present
		if readelf -S "$CORE" | grep -Fq '.note.gnu.build-id'; then
			aarch64-linux-objcopy --remove-section=.note.gnu.build-id "$CORE"
			printf "\tRemoved BuildID section..."
		else
			printf "\tBuildID section not present..."
		fi

		printf "\n\tFile Information: %s\n\n" "$(file "$CORE")"
	fi
done
