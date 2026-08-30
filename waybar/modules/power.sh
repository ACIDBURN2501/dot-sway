#!/usr/bin/env bash
set -euo pipefail

# power.sh — static power pill for the Waybar bar.
#
# Prints the Nerd Font power icon (md-power, U+F0425) once; the pill
# carries no state of its own. The NF PUA icon is used instead of the IEC
# symbol U+23FB (⏻) because SauceCodePro's U+23FB ink measures 13px wide
# in a 9px character cell and the label clips the overflow; md-power fits
# the cell (10x11px ink).
#
# Left-click opens the native power dropdown (waybar/menus/power.xml,
# wired via "menu" in waybar/config.jsonc). The wofi power menu
# ($super+Ctrl+p → scripts/quick-menu.sh power) stays for the dynamic path.

printf '\U000f0425'
