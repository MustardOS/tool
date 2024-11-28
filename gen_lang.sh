#!/bin/sh

for CMD in jq mv; do
	if ! command -v "$CMD" >/dev/null 2>&1; then
		printf "Error: Missing required command '%s'\n" "$CMD" >&2
		exit 1
	fi
done

# Exit immediately if a command exits with a non-zero status
set -e

REPO_ROOT="Repo/MustardOS"
REPO_INTERNAL="internal"
REPO_FRONTEND="frontend"

TRANSLATIONS_FILE="$(mktemp)"

echo '{}' >"$TRANSLATIONS_FILE"

SEARCH_TRANSLATIONS_IN_DIRECTORY() {
	DIRECTORY="$1"

	find "$DIRECTORY" -type f -name "*.c" | while read -r FILE; do
		printf "Processing: %s\n" "$FILE"
		CONTENT=$(sed ':a;N;$!ba;s/\" *\n *\"//g' "$FILE")

		echo "$CONTENT" | grep -oP 'TG\("([^"]+)"\)' | sed 's/TG("\(.*\)")/\1/' | while read -r MATCH; do
			if ! echo "$MATCH" | grep -qE '^[0-9]+$'; then
				printf "\tGeneric: %s\n" "$MATCH"
				jq --arg KEY "$MATCH" --arg VAL "$MATCH" --arg SECTION "generic" \
					'.[$SECTION][$KEY] = $VAL' "$TRANSLATIONS_FILE" >"$TRANSLATIONS_FILE.tmp" &&
					mv "$TRANSLATIONS_FILE.tmp" "$TRANSLATIONS_FILE"
			fi
		done

		echo "$CONTENT" | grep -oP 'TS\("([^"]+)"\)' | sed 's/TS("\(.*\)")/\1/' | while read -r MATCH; do
			if ! echo "$MATCH" | grep -qE '^[0-9]+$'; then
				SECTION="$(basename "$FILE" .c)"
				printf "\tModule %s: %s\n" "$SECTION" "$MATCH"
				jq --arg KEY "$MATCH" --arg VAL "$MATCH" --arg SECTION "$SECTION" \
					'.[$SECTION][$KEY] = $VAL' "$TRANSLATIONS_FILE" >"$TRANSLATIONS_FILE.tmp" &&
					mv "$TRANSLATIONS_FILE.tmp" "$TRANSLATIONS_FILE"
			fi
		done
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

UPDATE_JSON_FILE() {
	JSON_PATH="$1"
	TRANSLATIONS="$TRANSLATIONS_FILE"

	TEMP_JSON=$(mktemp)
	MERGED_JSON=$(mktemp)

	jq '.' "$JSON_PATH" >"$TEMP_JSON"
	jq -s 'reduce .[] as $item ({}; . * $item)' "$TEMP_JSON" "$TRANSLATIONS" >"$MERGED_JSON"

	jq -S '.' "$MERGED_JSON" >"$JSON_PATH"
	rm "$TEMP_JSON" "$MERGED_JSON"
}

TR_FOLDER="$HOME/$REPO_ROOT/$REPO_FRONTEND"
for FOLDER in common module; do
	if [ -d "$TR_FOLDER/$FOLDER" ]; then
		SEARCH_TRANSLATIONS_IN_DIRECTORY "$TR_FOLDER/$FOLDER"
	fi
done

ADD_MUXAPP_SCRIPTS
UPDATE_JSON_FILE "$HOME/$REPO_ROOT/$REPO_INTERNAL/init/MUOS/language/English.json"
