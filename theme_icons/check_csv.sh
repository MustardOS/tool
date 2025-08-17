#!/bin/sh

C_FILE=$1
CSV_FILE=$2

if [ ! -r "$C_FILE" ] || [ ! -r "$CSV_FILE" ]; then
    printf "Usage: %s <path/to/file.c> <path/to/file.csv>\n" "$0" >&2
    exit 2
fi

awk -F',' '
BEGIN { miss = 0 }

NR == FNR {
    if (FNR == 1 && $1 ~ /^[[:space:]]*MUX_MODULE[[:space:]]*$/) next

    mod = tolower($1); gsub(/^[ \t]+|[ \t]+$/, "", mod)
    gly = tolower($2); gsub(/^[ \t]+|[ \t]+$/, "", gly)
    if (mod != "" && gly != "") present[mod SUBSEP gly] = 1
    next
}

{
    if ($0 ~ /^#[[:space:]]*define[[:space:]]+[A-Za-z0-9_]+_ELEMENTS([[:space:]]*\\)?[[:space:]]*$/) {
        inblock = 1
        next
    }
    if (inblock && $0 ~ /^#[[:space:]]*define[[:space:]]+/) inblock = 0
    if (!inblock) next

    if (match($0, /^[[:space:]]*([A-Z][A-Za-z0-9_]*)[[:space:]]*\([[:alnum:]_]+[[:space:]]*,[[:space:]]*"([^"]+)"/, m)) {
        macro = tolower(m[1])
        glyph = tolower(m[2])
        mod   = "mux" macro
        key   = mod SUBSEP glyph
        if (!(key in present)) {
            printf("[%s]\tMissing Icon: %s\n", mod, glyph)
            miss++
        }
    }
}
' "$CSV_FILE" "$C_FILE"
