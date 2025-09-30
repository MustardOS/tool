#!/bin/bash
set -euo pipefail

DEVICE="${1:-}"
if [[ -z "$DEVICE" ]]; then
  echo "Usage: $0 <DEVICE>" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="${SCRIPT_DIR}/mp64-scripts"

scripts=(
  "build_mupen64plus-core.sh"
  "build_mupen64plus-audio-sdl.sh"
  "build_mupen64plus-input-sdl.sh"
  "build_mupen64plus-rsp-hle.sh"
  "build_mupen64plus-ui-console.sh"
  "build_mupen64plus-video-glide64mk2.sh"
  "build_mupen64plus-video-rice.sh"
  "build_mupen64plus-video-gliden64.sh"
)

for s in "${scripts[@]}"; do
  target="${SCRIPTS_DIR}/${s}"
  if [[ ! -x "$target" ]]; then
    echo "Error: script not executable or not found: $target" >&2
    exit 1
  fi
  echo "==> ${s} ${DEVICE}"
  "${target}" "${DEVICE}"
  echo "<== done: ${s}"
done

echo "All builds completed."