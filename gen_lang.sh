#!/bin/sh

for CMD in find jq mv; do
	command -v "$CMD" >/dev/null 2>&1 || {
		printf "Error: Missing required command '%s'\n" "$CMD" >&2
		exit 1
	}
done

set -e

REPO_ROOT="Repo/MustardOS"
REPO_INTERNAL="internal"
REPO_FRONTEND="frontend"
REPO_LANGUAGE="language"

LANGUAGE_FILE="$HOME/$REPO_ROOT/$REPO_FRONTEND/common/language.c"
RESULT_JSON="$HOME/$REPO_ROOT/$REPO_LANGUAGE/mux/en.json"
APP_DIRECTORY="$HOME/$REPO_ROOT/$REPO_INTERNAL/share/application"

LANG_JSON_TMP="$(mktemp)"
APPS_JSON_TMP="$(mktemp)"

jq -cRs '
  def collapse: gsub("\\\\\"\\s*\\\\n\\s*\\\\\""; "");
  def entries:
    match("(GENERIC_FIELD|SPECIFIC_FIELD)\\(lang->(?<section>[A-Za-z0-9_]+)(?:\\.[A-Za-z0-9_]+)*,\\s*(?<q>\"(?:[^\"\\\\]|\\\\.)*\")\\)"; "g")
    | { section: (.captures[] | select(.name=="section").string | ascii_downcase),
        text:    (.captures[] | select(.name=="q").string | fromjson) };

  collapse
  | [ entries ]
  | reduce .[] as $e ({}; .[$e.section][$e.text] = $e.text)
' "$LANGUAGE_FILE" >"$LANG_JSON_TMP" &
PID_LANG=$!

find "$APP_DIRECTORY" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | jq -Rsc '
    split("\n")
    | map(select(length>0 and . != "application"))
    | reduce .[] as $d ({}; .muxapp[$d] = $d)
' >"$APPS_JSON_TMP" &
PID_APPS=$!

wait "$PID_LANG" "$PID_APPS"

jq -sS 'reduce .[] as $x ({}; . * $x)' "$LANG_JSON_TMP" "$APPS_JSON_TMP" >"$RESULT_JSON"

printf "Generated translations JSON: %s\n" "$RESULT_JSON"

rm -f "$LANG_JSON_TMP" "$APPS_JSON_TMP"
