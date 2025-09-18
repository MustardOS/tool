#!/bin/bash
set -euo pipefail

DEVICE="${1:-}"
if [[ -z "$DEVICE" ]]; then
  echo "Usage: $0 <DEVICE>" >&2
  exit 1
fi

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
  if [[ ! -x "$s" ]]; then
    echo "Error: script not executable or not found: $s" >&2
    exit 1
  fi
  echo "==> $s $DEVICE"
  "./$s" "$DEVICE"
  echo "<== done: $s"
done

echo "All builds completed."