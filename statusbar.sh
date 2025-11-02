#!/usr/bin/env bash
# Simple sway status script
# Outputs only non-empty sections separated by " | "
# Left: concise battery (e.g., "⚡4h 54m", "🔋4h 54m", or "🔌")
# Center: current time in HH:MM

set -euo pipefail

# If BAR_ASCII=1 is set in the environment, replace emoji with ASCII fallbacks
icon_fallback() {
  local icon="$1"
  if [[ "${BAR_ASCII:-0}" == "1" ]]; then
    case "$icon" in
    "🔌") echo -n "AC" ;;
    "⚡") echo -n "CHG" ;;
    "🔋") echo -n "BAT" ;;
    "🪫") echo -n "LOW" ;;
    "❓") echo -n "?" ;;
    *) echo -n "$icon" ;;
    esac
  else
    echo -n "$icon"
  fi
}

batt_short() {
  local line icon label color rest short iout
  line="$1"
  IFS=';' read -r icon label color rest <<<"$line"
  # Normalise icon via fallback if needed
  iout=$(icon_fallback "$icon")
  # If label has trailing markers, trim to just time
  # Examples: "5h 6m remaining" -> "5h 6m", "1h 2m to full" -> "1h 2m"
  if [[ "$label" == *" remaining" ]]; then
    label="${label% remaining}"
  elif [[ "$label" == *" to full" ]]; then
    label="${label% to full}"
  fi
  # If fully charged, just show plug icon
  if [[ "$label" == "Full" || "$icon" == "🔌" ]]; then
    short="$iout"
  else
    short="${iout}${label}"
  fi
  printf "%s" "$short"
}

join_non_empty() {
  # Join non-empty args with " | " without leading/trailing pipes
  local out="" part
  for part in "$@"; do
    if [[ -n "$part" ]]; then
      if [[ -n "$out" ]]; then
        out+=" | "
      fi
      out+="$part"
    fi
  done
  printf "%s\n" "$out"
}

while true; do
  NOW=$(date +'%H:%M')
  LEFT=""
  if [ -x "$HOME/.config/sway/battery.sh" ]; then
    B_RAW=$("$HOME/.config/sway/battery.sh")
    LEFT=$(batt_short "$B_RAW")
  fi

  # Bluetooth status
  if [ -x "$HOME/.config/sway/bluetooth.sh" ]; then
    BLUE=$("$HOME/.config/sway/bluetooth.sh")
    LEFT="$BLUE"
  fi

  CENTER="$NOW"
  # Only print non-empty sections;
  join_non_empty "$LEFT" "$CENTER"
  sleep 1
done
