#!/usr/bin/env bash
# ------------------------------------------------------------
# ThinkPad T480 Dual‑Battery: simple time remaining for swaybar
# Uses UPower's aggregated DisplayDevice to compute a single
# status line: icon;label;color;default
# ------------------------------------------------------------

set -euo pipefail

DEV="/org/freedesktop/UPower/devices/DisplayDevice"

# Safely get a field from UPower output
uget() {
  local key="$1"
  upower -i "$DEV" 2>/dev/null | awk -F: -v k="$key" '
    tolower($1) ~ tolower(k) {
      v=$2; gsub(/^[[:space:]]+|[[:space:]]+$/, "", v); print v; exit
    }'
}

# Convert a "<number> <unit>" like "1.7 hours" or "35 minutes" to "Xh Ym"
fmt_time() {
  local num unit minutes total h m
  read -r num unit <<<"$1"
  # Default when empty
  if [[ -z "${num:-}" || -z "${unit:-}" ]]; then
    printf ""
    return 0
  fi
  case "$unit" in
  hour | hours)
    # Round to nearest minute
    minutes=$(awk -v n="$num" 'BEGIN { printf "%d", (n*60)+0.5 }')
    ;;
  minute | minutes)
    minutes=$(awk -v n="$num" 'BEGIN { printf "%d", n+0.5 }')
    ;;
  *)
    minutes=0
    ;;
  esac
  ((minutes < 0)) && minutes=0
  h=$((minutes / 60))
  m=$((minutes % 60))
  if ((h > 0)); then
    printf "%dh %dm" "$h" "$m"
  else
    printf "%dm" "$m"
  fi
}

state=$(uget "state")
perc_raw=$(uget "percentage")
# Strip trailing % and round to integer
perc=${perc_raw%%%}
if [[ "$perc" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  perc=$(awk -v p="$perc" 'BEGIN { printf "%d", p + 0.5 }')
fi

# Prefer aggregated times
empty_raw=$(uget "time to empty")
full_raw=$(uget "time to full")

empty_hm=$(fmt_time "$empty_raw")
full_hm=$(fmt_time "$full_raw")

# Normalize state to lower-case for matching
low_state=$(printf "%s" "$state" | tr '[:upper:]' '[:lower:]')

# Choose icon and semantics
# Map various states seen in UPower:
# - discharging -> 🔋
# - charging -> ⚡
# - fully-charged/full -> 🔌
# - pending-charge/charging-prohibited and when there is a line power present but not charging -> 🔌
icon="❓"
if [[ "$low_state" == *"discharging"* ]]; then
  icon="🔋"
elif [[ "$low_state" == *"charging"* ]]; then
  icon="⚡"
elif [[ "$low_state" == *"fully-charged"* || "$low_state" == *"full"* || "$low_state" == *"pending-charge"* || "$low_state" == *"charging-prohibited"* ]]; then
  icon="🔌"
elif [[ "$low_state" == *"empty"* ]]; then
  icon="🪫"
fi

# Build label text
label=""
if [[ "$low_state" == *"charging"* && -n "$full_hm" ]]; then
  label="$full_hm to full"
elif [[ "$low_state" == *"discharging"* && -n "$empty_hm" ]]; then
  label="$empty_hm remaining"
elif [[ "$low_state" == *"fully-charged"* || "$low_state" == *"full"* || "$low_state" == *"pending-charge"* ]]; then
  label="Full"
elif [[ -n "$perc" ]]; then
  # Fallback to showing rounded percent if no time available
  label="$perc%"
else
  label="Calculating"
fi

# Colour thresholds by percentage
col="green"
if [[ "$perc" =~ ^[0-9]+$ ]]; then
  if ((perc < 20)); then
    col="red"
  elif ((perc < 50)); then
    col="yellow"
  else
    col="green"
  fi
fi

# Emit the single line expected by statusbar.sh: icon;label;color;default
printf "%s;%s;%s;default\n" "$icon" "$label" "$col"
