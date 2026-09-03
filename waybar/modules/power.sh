#!/usr/bin/env bash
set -euo pipefail

# power.sh: static power pill for the Waybar bar.
#
# Prints the lightning bolt (⚡, U+26A1, emoji presentation) once; the pill
# carries no state of its own. It renders in the same size class as the
# theme pill's moon (19x18px ink at the bar's 11pt font).
#
# Left-click opens the native power dropdown (waybar/menus/power.xml,
# wired via "menu" in waybar/config.jsonc). The wofi power menu
# ($super+Ctrl+p → scripts/quick-menu.sh power) stays for the dynamic path.

printf "⚡"
