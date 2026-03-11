#!/usr/bin/env bash
# Portable brightness controls for laptop backlights.
set -euo pipefail

STEP="${BRIGHTNESS_STEP:-5%}"
ACTION="${1:-}"

if ! command -v brightnessctl >/dev/null 2>&1; then
  exit 0
fi

if ! compgen -G "/sys/class/backlight/*" >/dev/null; then
  exit 0
fi

case "$ACTION" in
  down)
    brightnessctl -q set "${STEP}-" >/dev/null 2>&1 || true
    ;;
  up)
    brightnessctl -q set "${STEP}+" >/dev/null 2>&1 || true
    ;;
  *)
    exit 0
    ;;
esac
