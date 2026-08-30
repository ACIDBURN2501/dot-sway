#!/usr/bin/env bash
set -euo pipefail

# power.sh — static power pill for the Waybar bar.
#
# Prints the power icon (⏻) once; the pill carries no state of its own.
# Left-click opens the native power dropdown (waybar/menus/power.xml,
# wired via "menu" in waybar/config.jsonc). The wofi power menu
# ($super+Ctrl+p → scripts/quick-menu.sh power) stays for the dynamic path.

printf "⏻"
