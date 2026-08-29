#!/usr/bin/env bash
# Portable brightness controls for laptop backlights.
# After every change the new level is pushed to the wob OSD pipe
# (scripts/osd-bar.sh); without wob the change is simply silent.
set -euo pipefail

STEP="${BRIGHTNESS_STEP:-5%}"
ACTION="${1:-}"
# Overridable for tests: the CI runner has no /sys/class/backlight.
BACKLIGHT_DIR="${BACKLIGHT_DIR:-/sys/class/backlight}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OSD="$SCRIPT_DIR/osd-bar.sh"

report_level() {
  local cur max
  cur=$(brightnessctl get 2>/dev/null || true)
  max=$(brightnessctl max 2>/dev/null || true)
  [ -n "$cur" ] && [ -n "$max" ] && [ "$max" -gt 0 ] 2>/dev/null || return 0
  "$OSD" "$((cur * 100 / max))"
}

if ! command -v brightnessctl >/dev/null 2>&1; then
  exit 0
fi

if ! compgen -G "$BACKLIGHT_DIR/*" >/dev/null; then
  exit 0
fi

case "$ACTION" in
  down)
    brightnessctl -q set "${STEP}-" >/dev/null 2>&1 || true
    report_level
    ;;
  up)
    brightnessctl -q set "${STEP}+" >/dev/null 2>&1 || true
    report_level
    ;;
  *)
    exit 0
    ;;
esac
