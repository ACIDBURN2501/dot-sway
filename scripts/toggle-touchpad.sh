#!/usr/bin/env bash
# Requires: jq, swaymsg, notify-send
set -euo pipefail
state="$(swaymsg -t get_inputs)"
if echo "$state" | jq -e '.[] | select(.type=="touchpad") | .libinput.send_events=="enabled"' >/dev/null; then
  swaymsg 'input type:touchpad events disabled'
  notify-send "Touchpad disabled" 2>/dev/null || true
else
  swaymsg 'input type:touchpad events enabled'
  notify-send "Touchpad enabled" 2>/dev/null || true
fi
