#!/usr/bin/env bash
# Brightness control for external monitors via DDC/CI.
set -euo pipefail

STEP="${EXTERNAL_BRIGHTNESS_STEP:-10}"
ACTION="${1:-}"

if ! command -v ddcutil >/dev/null 2>&1; then
  exit 0
fi

# Read current brightness (VCP 0x10). Output line looks like:
#   VCP code 0x10 (Brightness                    ): current value =    85, max value =   100
CUR=$(ddcutil getvcp 10 --terse 2>/dev/null | awk '{print $4}')
MAX=$(ddcutil getvcp 10 --terse 2>/dev/null | awk '{print $5}')

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

ddcutil setvcp 10 "$NEW" >/dev/null 2>&1 || true
