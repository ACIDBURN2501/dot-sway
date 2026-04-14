#!/usr/bin/env bash
# Show current display brightness as an icon and percentage (0-100%).
# Prefers laptop backlight (brightnessctl); falls back to external monitor (ddcutil).
set -euo pipefail

ICON_INTERNAL=""
ICON_EXTERNAL="󰖨"

PCT=""
ICON=""

# Prefer laptop backlight if a backlight device exists and brightnessctl is available.
if command -v brightnessctl >/dev/null 2>&1 && compgen -G "/sys/class/backlight/*" >/dev/null; then
  PCT_RAW=$(brightnessctl -m 2>/dev/null | awk -F, 'NR==1{print $6}' || true)
  if [[ -n "${PCT_RAW:-}" ]]; then
    PCT_RAW=${PCT_RAW//[[:space:]]/}
    PCT=${PCT_RAW%%%}
  else
    cur=$(brightnessctl get 2>/dev/null || echo 0)
    max=$(brightnessctl max 2>/dev/null || echo 1)
    if [[ "$max" -gt 0 ]]; then
      PCT=$(awk -v c="$cur" -v m="$max" 'BEGIN { printf("%d", (c*100)/m) }')
    fi
  fi
  ICON="$ICON_INTERNAL"
fi

# Fall back to external monitor via DDC/CI.
if [[ -z "${PCT:-}" ]] && command -v ddcutil >/dev/null 2>&1; then
  read -r _ _ _ cur max < <(ddcutil getvcp 10 --terse 2>/dev/null || true)
  if [[ -n "${cur:-}" && -n "${max:-}" && "$max" -gt 0 ]]; then
    PCT=$(awk -v c="$cur" -v m="$max" 'BEGIN { printf("%d", (c*100)/m) }')
    ICON="$ICON_EXTERNAL"
  fi
fi

[[ -z "${PCT:-}" ]] && exit 0

if [[ "$PCT" -lt 0 ]]; then PCT=0; fi
if [[ "$PCT" -gt 100 ]]; then PCT=100; fi

printf "%s %s%%\n" "$ICON" "$PCT"
