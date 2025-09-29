#!/bin/sh

# Lines that start with DOC_MAGIC (default "#:]") are interpreted as Markdown.
#   - If the content begins with "#", it opens a new section and flushes any prior code block.
#   - Otherwise it is printed as prose under the current section or file header.
# The line "#:] ~" starts a mute zone that ignores all non-magic lines until the next magic line.
# The script shebang on the first line is never exported.
#
# Variables:
#   DOC_MAGIC       magic prefix (default "#:]")
#   ADD_FILENAME_H1 1 => add "# `path/to/file.sh`" inside the content (default 1)
#   INCLUDE_CODE    1 => per-section collapsible code blocks (default 0)
#   PRELUDE_LINES   N => include last N non-shebang lines before first section (default 0)
#   WRAP_FILE       1 => wrap whole file in a single <details> (default 1)
#   SUMMARY_PREFIX  text before filename in <summary> (default empty)
#   LARRIKIN_ROOT   strip this path prefix when showing filename in summary/H1
#   FOOTER_BADGE    (unused here; add with your Makefile if desired)
#
# Usage:
#   ./larrikin.sh startup.sh > docs/startup.md
#   INCLUDE_CODE=1 PRELUDE_LINES=1 ./larrikin.sh startup.sh > docs/startup.md
#
# Or use the provided Makefile which will do scripts recursively!

set -eu

DOC_MAGIC="${DOC_MAGIC:-#:]}"
ADD_FILENAME_H1="${ADD_FILENAME_H1:-1}"
INCLUDE_CODE="${INCLUDE_CODE:-0}"
PRELUDE_LINES="${PRELUDE_LINES:-0}"
WRAP_FILE="${WRAP_FILE:-1}"
SUMMARY_PREFIX="${SUMMARY_PREFIX:-}"
FOOTER_BADGE="${FOOTER_BADGE:-0}"

if [ "$#" -lt 1 ]; then
	printf "Usage: %s <script.sh> [more.sh ...]\n" "$0" >&2
	exit 1
fi

for SRC in "$@"; do
	[ -f "$SRC" ] || {
		printf "Skip %s (not a file)\n" "$SRC" >&2
		continue
	}

	LARRIKIN_ROOT="${LARRIKIN_ROOT:-}"
	[ -n "$LARRIKIN_ROOT" ] && LARRIKIN_ROOT=${LARRIKIN_ROOT%/}
	if [ -n "$LARRIKIN_ROOT" ] && [ "${SRC#"$LARRIKIN_ROOT"/}" != "$SRC" ]; then
		DISPLAY_PATH=${SRC#"$LARRIKIN_ROOT"/}
	elif [ "${SRC#"$PWD"/}" != "$SRC" ]; then
		DISPLAY_PATH=${SRC#"$PWD"/}
	elif [ "${SRC#./}" != "$SRC" ]; then
		DISPLAY_PATH=${SRC#./}
	else
		DISPLAY_PATH=$(basename "$SRC")
	fi

	awk -v magic="$DOC_MAGIC" \
		-v addh1="$ADD_FILENAME_H1" \
		-v include_code="$INCLUDE_CODE" \
		-v prelude_lines="$PRELUDE_LINES" \
		-v wrap_file="$WRAP_FILE" \
		-v summary_prefix="$SUMMARY_PREFIX" \
		-v fname="$DISPLAY_PATH" '
  function regesc(s, t) {
    t=s
    gsub(/[][(){}.^$*+?|\\-]/, "\\\\&", t)
    return t
  }

  function is_blank(s) {
    return (s ~ /^[[:space:]]*$/)
  }

  function reset_code(i) {
    for(i=1; i<=code_ct; i++) delete code_lines[i]
    code_ct=0
  }

  function push_code(s) {
    code_lines[++code_ct]=s
  }

  function flush_code(first,last,i) {
  	if (!include_code || code_ct==0) {
  	  reset_code()
  	  return
  	}

    first=1
    while(first<=code_ct && is_blank(code_lines[first])) first++

    last=code_ct
    while(last>=first && is_blank(code_lines[last])) last--

    if (last<first) {
      reset_code()
      return
    }

    print("")
    print("```sh")

    for(i=first; i<=last; i++) print code_lines[i]

    print("```")
    print("")

    reset_code()
  }

  function print_file_header_once() {
    if (!printed_header && addh1 == 1) {
      print("# `" fname "`")
      print("")
      printed_header = 1
    }
  }

  function open_section_with_title(title_line, i, start_idx) {
    if (any_section) {
      flush_code()
    } else if (!muted && include_code && prelude_lines > 0 && pre_ct > 0) {
      start_idx = pre_ct - prelude_lines + 1
      if (start_idx < 1) start_idx = 1
      for (i=start_idx; i<=pre_ct; i++) push_code(pre[i])
    }

    any_section = 1

    print("")
    print(title_line)
  }

  function strip_magic_prefix(s, re) {
    re="^" magic_re "[[:space:]]?"
    sub(re, "", s)
    return s
  }

  function open_file_wrapper() {
    if (wrap_file) {
      print("<details>")

      if (summary_prefix != "")
        print("<summary>" summary_prefix " <code>" fname "</code></summary>")
      else
        print("<summary><code>" fname "</code></summary>")

      print("")
    }
  }

  function close_file_wrapper() {
    if (wrap_file) {
      print("</details>")
      print("")
    }
  }

  BEGIN {
    printed_header = 0
    any_section = 0
    magic_re = regesc(magic)
    pre_ct = 0
    code_ct = 0
    muted = 0

    open_file_wrapper()
  }

  {
    line = $0

    # Never export a top-of-file shebang
    if (NR==1 && line ~ /^#!/) { next }

    # Magic-marked lines
    if (index(line, magic) == 1) {
      content = strip_magic_prefix(line)

      # Mute toggle: "#:] ~"
      if (content ~ /^[[:space:]]*~([[:space:]]|$)/) {
        muted = 1
        if (any_section) flush_code()
        next
      }

      # Any other magic line un-mutes
      if (muted) muted = 0

      if (content ~ /^[[:space:]]*#/) {
        open_section_with_title(content)
      } else {
        print(content)
      }

      next
    }

    # While muted, ignore everything until next magic
    if (muted) next

    # Non-magic lines are code
    if (!any_section) {
      pre[++pre_ct] = line
    } else if (include_code) {
      push_code(line)
    }
  }

  END {
    flush_code()
    close_file_wrapper()
  }
  ' "$SRC"
done
