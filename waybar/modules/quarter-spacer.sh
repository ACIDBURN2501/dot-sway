#!/usr/bin/env bash
# Quarter-point spacer for the status bar.
#
# Parks the toggle group (theme, DND) at the bar's 1/4 (or 3/4) point.
# Waybar and GTK3 CSS have no percentage anchoring, so the gap is a px
# min-width chosen in bands from the active output width. The module
# emits a class; style.css maps the band to a min-width:
#   gap-s (output < 2200 px)  gap-m (< 3000 px)  gap-l (else)
#
# The module re-runs on its interval, so a hotplug or a profile switch
# between the panel and a docked external picks up the new width within
# one tick. Emits one JSON line: {"text": " ", "class": "gap-<band>"}.
# Empty output (no swaymsg/jq, no active output) hides the module.
set -euo pipefail

command -v swaymsg >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

# Custom modules don't see their own bar's output, so use the focused
# active output. Exact on the single-output desktops this config targets
# (mobile and docked profiles); a reasonable proxy otherwise.
width="$(swaymsg -t get_outputs 2>/dev/null | jq -r '
  [ .[] | select(.active == true) ] as $act
  | ( [ $act[] | select(.focused == true) ] | first ) // $act[0]
  | .rect.width' 2>/dev/null)" || exit 0

[[ "$width" =~ ^[0-9]+$ ]] || exit 0

if (( width < 2200 )); then
  band="gap-s"
elif (( width < 3000 )); then
  band="gap-m"
else
  band="gap-l"
fi

printf '{"text": " ", "class": "%s"}\n' "$band"
