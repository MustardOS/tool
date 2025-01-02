#!/bin/sh

for CMD in jq mv; do
	if ! command -v "$CMD" >/dev/null 2>&1; then
		printf "Error: Missing required command '%s'\n" "$CMD" >&2
		exit 1
	fi
done

set -e

REPO_ROOT="Repo/MustardOS"
REPO_INTERNAL="internal"
REPO_FRONTEND="frontend"

LANGUAGE_FILE="$HOME/$REPO_ROOT/$REPO_FRONTEND/common/language.c"
RESULT_JSON="$HOME/$REPO_ROOT/$REPO_INTERNAL/init/MUOS/language/English.json"
TRANSLATIONS_FILE="$(mktemp)"

echo '{}' >"$TRANSLATIONS_FILE"

PROCESS_LANGUAGE_FILE() {
	FILE="$1"
	CONTENT=$(sed ':a;N;$!ba;s/\\" *\\n *\\"//g' "$FILE")

	printf "Processing language entries...\n"
	echo "$CONTENT" | grep -oP '(GENERIC_FIELD|SPECIFIC_FIELD)\(lang->\w+(\.\w+)*,\s*"[^"]+"\)' | while read -r MATCH; do
		SECTION=$(echo "$MATCH" | grep -oP 'lang->\K\w+')
		JSON_KEY=$(echo "$SECTION" | tr '[:upper:]' '[:lower:]')

		VALUE=$(echo "$MATCH" | grep -oP '"[^"]+"' | sed 's/"//g')
		printf "\tSection: %s, String: %s\n" "$JSON_KEY" "$VALUE"

		jq --arg KEY "$VALUE" --arg VAL "$VALUE" --arg SECTION "$JSON_KEY" \
			'.[$SECTION][$KEY] = $VAL' "$TRANSLATIONS_FILE" >"$TRANSLATIONS_FILE.tmp" &&
			mv "$TRANSLATIONS_FILE.tmp" "$TRANSLATIONS_FILE"
	done
}

ADD_MUXAPP_SCRIPTS() {
	APP_DIRECTORY="$HOME/$REPO_ROOT/$REPO_INTERNAL/init/MUOS/application"
	printf "Processing Application Scripts: %s\n" "$APP_DIRECTORY"

	find "$APP_DIRECTORY" -type f -name "*.sh" | while read -r SCRIPT_PATH; do
		SCRIPT_NAME=$(basename "$SCRIPT_PATH" .sh)
		printf "\tAdding '%s' to 'muxapp'\n" "$SCRIPT_NAME"

		jq --arg KEY "$SCRIPT_NAME" --arg VAL "$SCRIPT_NAME" \
			'.muxapp[$KEY] = $VAL' "$TRANSLATIONS_FILE" >"$TRANSLATIONS_FILE.tmp" &&
			mv "$TRANSLATIONS_FILE.tmp" "$TRANSLATIONS_FILE"
	done
}

PROCESS_LANGUAGE_FILE "$LANGUAGE_FILE"
ADD_MUXAPP_SCRIPTS

jq -S '.' "$TRANSLATIONS_FILE" >"$RESULT_JSON"
printf "Generated translations JSON: %s\n" "$RESULT_JSON"
rm "$TRANSLATIONS_FILE"
