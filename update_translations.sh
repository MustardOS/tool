#!/bin/sh

for CMD in curl unzip; do
	if ! command -v "$CMD" >/dev/null 2>&1; then
		printf "Missing '%s' command\n" "$CMD"
		exit 1
	fi
done

if [ ! -f "$HOME/.weblate" ]; then
	printf "No Weblate token found\n"
	exit 1
fi

REPO_LANG_DIR="Repo/MustardOS/internal/init/MUOS/language"
WEBLATE_URL="https://hosted.weblate.org/api/projects/muos/file/"
TOKEN="$(cat "$HOME/.weblate")"
FORMAT="zip"

tr_rename() {
	TR_DEST="$HOME/$REPO_LANG_DIR/$2"
	printf "\033[1mMoving '\033[0m%s\033[1m' to '\033[0m%s\033[1m'\033[0m\n" "$1" "$TR_DEST"
	mv "$1" "$TR_DEST" || printf "\033[1m\t- Failed on '%s'\033[0m\n" "$1"
}

printf "\n=============== \033[1mUpdating Languages\033[0m ==============\n\n"
printf "\033[1mDownloading Translations\033[0m\n"

if curl -H "Authorization: Token ${TOKEN}" -o "translations.${FORMAT}" "${WEBLATE_URL}?format=${FORMAT}"; then
	printf "\t\033[1m- Downloaded translations successfully\033[0m\n"
else
	printf "\t\033[1m- Failed to download translations\033[0m\n"
	exit 1
fi

printf "\033[1mDecompressing translations\033[0m\n"
unzip -j translations.zip

tr_rename "ca.json" "Catalan.json"
tr_rename "ca@valencia.json" "Valencian.json"
tr_rename "cs.json" "Czech.json"
tr_rename "de.json" "German.json"
tr_rename "en.json" "English.json"
tr_rename "en_US.json" "English (American).json"
tr_rename "es.json" "Spanish.json"
tr_rename "fr.json" "French.json"
tr_rename "hi.json" "Hindi.json"
tr_rename "it.json" "Italian.json"
tr_rename "ja.json" "Japanese.json"
tr_rename "ko.json" "Korean.json"
tr_rename "nl.json" "Dutch.json"
tr_rename "pl.json" "Polish.json"
tr_rename "pt_BR.json" "Portuguese (BR).json"
tr_rename "pt_PT.json" "Portuguese (PT).json"
tr_rename "ru.json" "Russian.json"
tr_rename "tr.json" "Turkish.json"
tr_rename "vi.json" "Vietnamese.json"
tr_rename "zh_Hans.json" "Chinese (Simplified).json"
tr_rename "zh_Hant.json" "Chinese (Traditional).json"

printf "\033[1mCleaning up!\033[0m\n"
rm -f translations.zip

printf "\n=============== \033[1mLanguages Updated\033[0m ==============\n\n"
