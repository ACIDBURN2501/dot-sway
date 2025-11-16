#!/usr/bin/env bash
set -euo pipefail
active="$(swaymsg -t get_outputs -r | jq -r '.[] | select(.active) | .name' | head -n1)"
[ -n "$active" ] || exit 0
for ws in $(swaymsg -t get_workspaces -r | jq -r '.[].name'); do
  swaymsg "workspace $ws; move workspace to output $active" >/dev/null
done
