#!/usr/bin/env bash
set -euo pipefail
target="${1:-}"
[ -n "$target" ] || exit 1
for ws in $(swaymsg -t get_workspaces -r | jq -r '.[].name'); do
  swaymsg "workspace $ws; move workspace to output $target" >/dev/null
done
