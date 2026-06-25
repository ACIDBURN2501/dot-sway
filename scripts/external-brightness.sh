#!/usr/bin/env bash
# Brightness control for external monitors via DDC/CI.
set -euo pipefail

STEP="${EXTERNAL_BRIGHTNESS_STEP:-10}"
ACTION="${1:-}"

if ! command -v ddcutil >/dev/null 2>&1; then
  exit 0
fi

# A getvcp I2C round-trip is slow, so we cache "CUR MAX" in a file that the
# Waybar brightness module (waybar/modules/brightness.sh) also reads. Prefer
# the cache; only fall back to a single getvcp if the cache is missing.
CACHE="${XDG_RUNTIME_DIR:-/tmp}/sway-brightness-ext"
CUR=""
MAX=""
if [[ -s "$CACHE" ]]; then
  read -r CUR MAX < "$CACHE" || true
fi
if [[ -z "${CUR:-}" || -z "${MAX:-}" ]]; then
  read -r _ _ _ CUR MAX < <(ddcutil getvcp 10 --terse 2>/dev/null || true)
fi

if [[ -z "${CUR:-}" || -z "${MAX:-}" ]]; then
  exit 0
fi

case "$ACTION" in
  down)
    NEW=$(( CUR - STEP ))
    (( NEW < 0 )) && NEW=0
    ;;
  up)
    NEW=$(( CUR + STEP ))
    (( NEW > MAX )) && NEW=MAX
    ;;
  *)
    exit 0
    ;;
esac

if ddcutil setvcp 10 "$NEW" >/dev/null 2>&1; then
  printf "%s %s\n" "$NEW" "$MAX" > "$CACHE"
fi
