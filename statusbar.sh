#!/usr/bin/env bash
# Simple sway status script (generic)
# Layout: <Battery> | <Status Icons> | <Time>
# - Battery (left): concise output from battery.sh (e.g., "⚡4h 54m", "🔋4h 54m", or "🔌")
# - Status Icons (center): aggregated outputs from executable scripts in ~/.config/sway/status.d
# - Time (right): current time in HH:MM

set -euo pipefail

# Convert battery semicolon-separated line into a concise left section
batt_short() {
  local line icon label color rest short
  line="$1"
  IFS=';' read -r icon label color rest <<<"$line"
  # If label has trailing markers, trim to just time
  # Examples: "5h 6m remaining" -> "5h 6m", "1h 2m to full" -> "1h 2m"
  if [[ "$label" == *" remaining" ]]; then
    label="${label% remaining}"
  elif [[ "$label" == *" to full" ]]; then
    label="${label% to full}"
  fi
  # If fully charged, just show plug icon
  if [[ "$label" == "Full" || "$icon" == "🔌" ]]; then
    short="$icon"
  else
    short="${icon}${label}"
  fi
  printf "%s" "$short"
}

# Join non-empty args with " | " without leading/trailing pipes
join_non_empty() {
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

# Run all executable scripts in a status directory and join their non-empty outputs with spaces
status_icons() {
  local dir="${STATUS_DIR:-$HOME/.config/sway/status.d}"
  local outputs=()
  if [[ -d "$dir" ]]; then
    # Iterate in lexical order for predictable placement
    local s out
    for s in "$dir"/*; do
      if [[ -f "$s" && -x "$s" ]]; then
        # Execute each script; ignore errors from individual scripts
        out="$("$s" 2>/dev/null || true)"
        # Trim trailing newline(s)
        out=${out//$'\n'/}
        if [[ -n "$out" ]]; then
          outputs+=("$out")
        fi
      fi
    done
  fi
  # Join with single spaces
  local joined="" item
  for item in "${outputs[@]:-}"; do
    if [[ -n "$joined" ]]; then
      joined+=" "
    fi
    joined+="$item"
  done
  printf "%s" "$joined"
}

while true; do
  NOW=$(date +'%H:%M')

  # Left: battery concise summary
  LEFT=""
  if [[ -x "$HOME/.config/sway/battery.sh" ]]; then
    B_RAW=$("$HOME/.config/sway/battery.sh" || true)
    if [[ -n "$B_RAW" ]]; then
      LEFT=$(batt_short "$B_RAW")
    fi
  fi

  # Center: generic status icons aggregated from scripts
  CENTER="$(status_icons)"

  # Right: time
  RIGHT="$NOW"

  # Only print non-empty sections
  join_non_empty "$LEFT" "$CENTER" "$RIGHT"
  sleep 1
done
