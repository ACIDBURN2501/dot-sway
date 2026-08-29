#!/usr/bin/env bash
# Capture a screenshot with grim, save it, and put it on the clipboard.
#
# Usage: screenshot.sh [region|screen|output|window]
#   region  select an area with slurp (default)
#   screen  the whole output layout
#   output  the focused output
#   window  the focused window
#
# Saves to $SCREENSHOT_DIR (default ~/Pictures/Screenshots) and copies the
# PNG to the Wayland clipboard when wl-copy is present, so a capture can be
# pasted straight into a chat or editor without attaching the file.
set -euo pipefail

SCREENSHOT_DIR="${SCREENSHOT_DIR:-$HOME/Pictures/Screenshots}"

command -v grim >/dev/null 2>&1 || exit 0

have_sway_query() {
  command -v swaymsg >/dev/null 2>&1 && command -v jq >/dev/null 2>&1
}

# Geometry of the focused window, as grim's -g expects ("X,Y WxH"). Exactly one
# node in the tree carries focused=true, and it is the focused container.
focused_window_geometry() {
  have_sway_query || return 1
  swaymsg -t get_tree -r 2>/dev/null |
    jq -r 'first(.. | select(.focused? == true) | .rect
           | "\(.x),\(.y) \(.width)x\(.height)")' 2>/dev/null
}

# Name of the focused output. Output nodes in the tree always report
# focused=false (focus lives on a leaf), so this has to come from get_outputs.
focused_output_name() {
  have_sway_query || return 1
  swaymsg -t get_outputs -r 2>/dev/null |
    jq -r 'first(.[] | select(.focused) | .name)' 2>/dev/null
}

notify() {
  command -v notify-send >/dev/null 2>&1 || return 0
  notify-send --app-name="Screenshot" -i "$2" "$1" "$(basename "$2")" \
    --expire-time=3000 2>/dev/null || true
}

MODE="${1:-region}"

GRIM_ARGS=()
case "$MODE" in
  region)
    command -v slurp >/dev/null 2>&1 || exit 0
    # A cancelled selection (Escape) gives a non-zero exit or empty output.
    GEOMETRY="$(slurp 2>/dev/null)" || exit 0
    [ -n "$GEOMETRY" ] || exit 0
    GRIM_ARGS=(-g "$GEOMETRY")
    ;;
  window)
    GEOMETRY="$(focused_window_geometry)" || exit 0
    [ -n "$GEOMETRY" ] || exit 0
    GRIM_ARGS=(-g "$GEOMETRY")
    ;;
  output)
    # -o keeps the output's own scale, which a geometry crop would flatten.
    OUTPUT="$(focused_output_name)" || exit 0
    [ -n "$OUTPUT" ] || exit 0
    GRIM_ARGS=(-o "$OUTPUT")
    ;;
  screen) ;;
  *) exit 0 ;;
esac

mkdir -p "$SCREENSHOT_DIR" || exit 0
FILE="$SCREENSHOT_DIR/screenshot-$(date +'%Y-%m-%d-%H%M%S').png"

grim "${GRIM_ARGS[@]}" "$FILE" || exit 0

# wl-copy forks a process that serves the selection until it is replaced, so
# the image stays pastable after this script exits.
if command -v wl-copy >/dev/null 2>&1; then
  wl-copy --type image/png <"$FILE" 2>/dev/null || true
fi

notify "󰄄 Screenshot saved" "$FILE"
