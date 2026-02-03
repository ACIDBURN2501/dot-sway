#!/usr/bin/env bash
# Show current display brightness as an icon and percentage (0-100%).
# Designed for Nerd Font / Unicode-friendly bars.
set -euo pipefail

ICON_SUN=""

# Exit quietly if brightnessctl is unavailable
if ! command -v brightnessctl >/dev/null 2>&1; then
  exit 0
fi

# Try to get the percentage directly from machine-readable output.
# brightnessctl -m format: device,class,name,value,max,percent
PCT_RAW=$(brightnessctl -m 2>/dev/null | awk -F, 'NR==1{print $6}' || true)

if [[ -n "${PCT_RAW:-}" ]]; then
  # Normalize: strip whitespace and percent sign
  PCT_RAW=${PCT_RAW//[[:space:]]/}
  PCT=${PCT_RAW%%%}
else
  # Fallback: compute percent from current and max values
  cur=$(brightnessctl get 2>/dev/null || echo 0)
  max=$(brightnessctl max 2>/dev/null || echo 1)
  if [[ "$max" -gt 0 ]]; then
    # Use awk for integer math and rounding
    PCT=$(awk -v c="$cur" -v m="$max" 'BEGIN { if (m<=0) {print 0} else { printf("%d", (c*100)/m) } }')
  else
    PCT=0
  fi
fi

# Clamp to [0,100] just in case
if [[ "$PCT" -lt 0 ]]; then PCT=0; fi
if [[ "$PCT" -gt 100 ]]; then PCT=100; fi

printf "%s %s%%\n" "$ICON_SUN" "$PCT"

