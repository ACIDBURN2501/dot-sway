#!/usr/bin/env bash
# Show current sink volume, mute icon when muted.
set -euo pipefail

# Default values if pactl fails
VOL=""
MUTED=""

# Try getting default sink.  pactl uses @DEFAULT_SINK@ which works on most systems.
if [ -x "$(command -v pactl)" ]; then
  # Pseudo‑sink might not exist; fallback to first sink
  SINK=$(pactl list sinks short | awk 'NR==1{print $1}' 2>/dev/null || echo "")
  [ -z "$SINK" ] && exit 0

  # Mute status
  MUTED=$(pactl get-sink-mute "$SINK" 2>/dev/null | grep -q 'yes' && echo "yes" || echo "")

  # Volume (the first channel – usually the master channel)
  VOL=$(pactl get-sink-volume "$SINK" 2>/dev/null | awk 'NR==1{print $5}' | tr -d ' ')

  # Clean up % if present
  VOL=${VOL%\%}
else
  exit 0
fi

if [[ "$MUTED" == "yes" ]]; then
  echo " "
else
  echo " $VOL%"
fi
