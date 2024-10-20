#!/bin/sh

for CMD in git mv; do
	if ! command -v "$CMD" >/dev/null 2>&1; then
		printf "Missing '%s' command\n" "$CMD"
		exit 1
	fi
done

CURR_DIR=$(pwd)

REPO_LANG_DIR="Repo/MustardOS/language"
REPO_INTERNAL_DIR="Repo/MustardOS/internal/init/MUOS/language"

tr_rename() {
	TR_DEST="$HOME/$REPO_INTERNAL_DIR/$2"
	printf "\033[1mUpdating '\033[0m%s\033[1m' to '\033[0m%s\033[1m'\033[0m\n" "$1" "$TR_DEST"
	cp "$1" "$TR_DEST" || printf "\033[1m\t- Failed on '%s'\033[0m\n" "$1"
}

cd "$HOME/$REPO_LANG_DIR" || (printf "Language repository missing (%s)" "$REPO_LANG_DIR" && exit)

printf "\n=============== \033[1mUpdating Languages\033[0m ==============\n\n"
printf "\033[1mDownloading Translations\033[0m\n"

git pull
echo ""

cd "mux" || (printf "Languages for component 'muX' missing (%s)" "$REPO_LANG_DIR" && exit)

tr_rename "ca.json" "Catalan.json"
tr_rename "ca@valencia.json" "Valencian.json"
tr_rename "cs.json" "Czech.json"
tr_rename "de.json" "German.json"
tr_rename "en.json" "English.json"
tr_rename "en_US.json" "English (American).json"
tr_rename "es.json" "Spanish.json"
tr_rename "fr.json" "French.json"
tr_rename "hi.json" "Hindi.json"
tr_rename "hr.json" "Croatian.json"
tr_rename "it.json" "Italian.json"
tr_rename "ja.json" "Japanese.json"
tr_rename "ko.json" "Korean.json"
tr_rename "nl.json" "Dutch.json"
tr_rename "pl.json" "Polish.json"
tr_rename "pt_BR.json" "Portuguese (BR).json"
tr_rename "pt_PT.json" "Portuguese (PT).json"
tr_rename "ru.json" "Russian.json"
tr_rename "sr.json" "Serbian.json"
tr_rename "sv.json" "Swedish.json"
tr_rename "tr.json" "Turkish.json"
tr_rename "uk.json" "Ukrainian.json"
tr_rename "vi.json" "Vietnamese.json"
tr_rename "zh_Hans.json" "Chinese (Simplified).json"
tr_rename "zh_Hant.json" "Chinese (Traditional).json"

cd "$CURR_DIR" || exit

printf "\n=============== \033[1mLanguages Updated\033[0m ==============\n\n"
