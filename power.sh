#!/usr/bin/env bash
# Power status script for sway status bar

# Check if battery script exists and is executable
if [ -x "$HOME/.config/sway/battery.sh" ]; then
  B_RAW=$("$HOME/.config/sway/battery.sh")
  # Use the same batt_short function logic
  IFS=';' read -r icon label color rest <<<"$B_RAW"
  # Return just the icon + label part (like "🔋4h 54m" or "🔌")
  if [[ "$label" == "Full" || "$icon" == "🔌" ]]; then
    echo "$icon"
  else
    echo "${icon}${label}"
  fi
else
  echo "❓"
fi
