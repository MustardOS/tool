#!/bin/sh

for CMD in git mv; do
	if ! command -v "$CMD" >/dev/null 2>&1; then
		printf "Missing '%s' command\n" "$CMD"
		exit 1
	fi
done

CURR_DIR=$(pwd)

REPO_ROOT="${REPO_ROOT:-Repo/MustardOS}"
REPO_INTERNAL="${REPO_INTERNAL:-internal}"
REPO_LANGUAGE="${REPO_LANGUAGE:-language}"

TR_RENAME() {
	TR_DEST="$HOME/$REPO_ROOT/$REPO_INTERNAL/share/language/$2"
	printf "\033[1mUpdating '\033[0m%s\033[1m' to '\033[0m%s\033[1m'\033[0m\n" "$1" "$TR_DEST"
	cp "$1" "$TR_DEST" || printf "\033[1m\t- Failed on '%s'\033[0m\n" "$1"
}

printf "\n=============== \033[1mUpdating Languages\033[0m ==============\n\n"

cd "$HOME/$REPO_ROOT/$REPO_LANGUAGE" || {
	printf "Language repository missing (%s)\n" "$REPO_ROOT/$REPO_LANGUAGE"
	exit 1
}

printf "\033[1mUpdating languages from '%s' repository\033[0m\n" "$REPO_LANGUAGE"
git pull
printf "\n"

cd "mux" || {
	printf "Languages for component 'muX' missing (%s)\n" "$REPO_ROOT/$REPO_LANGUAGE/mux"
	exit 1
}

# Read the mappings from the file and call TR_RENAME for each entry
while IFS=":" read -r WL_SOURCE FULL_NAME; do
	[ -z "$WL_SOURCE" ] && continue
	TR_RENAME "${WL_SOURCE}.json" "${FULL_NAME}.json"
done <"$HOME/$REPO_ROOT/$REPO_LANGUAGE/tr_map.txt"

cd "$CURR_DIR" || exit

printf "\n=============== \033[1mLanguages Updated\033[0m ==============\n\n"
