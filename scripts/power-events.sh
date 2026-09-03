#!/usr/bin/env bash
# Battery and AC power event watcher.
#
# Polls UPower every 30s and fires one notification plus one hook per
# power transition:
#
#   battery-low      discharge reached LOW_PCT (once per discharge episode)
#   battery-charged  the battery reached "fully-charged" (once per episode)
#   power-plugged    AC connected
#   power-unplugged  AC disconnected
#
# Inputs:  UPower's DisplayDevice (percentage and state)
# Outputs: notify-send (ordinary urgency; mako DND suppresses them like
#          every notification), scripts/hooks.sh events, and a state file
#          under $XDG_RUNTIME_DIR/sway/ so each episode fires exactly once.
#
# Degradation: without upower, without a battery (desktops), or without a
# usable session runtime dir, the watcher exits 0 at the first probe.
#
# Tuning (also how the episode logic is tested):
#   POWER_EVENTS_INTERVAL  seconds between polls (default 30)
#   POWER_EVENTS_LOW_PCT   low threshold in percent (default 20)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INTERVAL="${POWER_EVENTS_INTERVAL:-30}"
LOW_PCT="${POWER_EVENTS_LOW_PCT:-20}"
DISPLAY_DEVICE="/org/freedesktop/UPower/devices/DisplayDevice"
STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/sway/power-events.state"

command -v upower >/dev/null 2>&1 || exit 0
T=(timeout 5)
command -v timeout >/dev/null 2>&1 || T=()

# Only the first probe needs the device list: without a battery there is
# nothing to watch, so a desktop stays silent forever.
if ! "${T[@]}" upower -e 2>/dev/null | grep -q battery; then
  exit 0
fi
mkdir -p "${STATE_FILE%/*}" 2>/dev/null || exit 0

# Never run twice (a stray manual start must not double-notify): the pid
# file lives next to the state file and only counts as "running" when the
# pid is alive and still points at this script.
PID_FILE="${STATE_FILE%.state}.pid"
if [[ -s "$PID_FILE" ]]; then
  OLD_PID="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [[ -n "$OLD_PID" && "$OLD_PID" != "$$" ]] \
    && grep -q 'power-events' "/proc/$OLD_PID/cmdline" 2>/dev/null; then
    exit 0
  fi
fi
printf '%s\n' "$$" > "$PID_FILE"

# classify <upower-state>: "battery" while discharging, "plugged" while the
# AC is in the picture, empty for states we do not act on (unknown).
classify() {
  case "$1" in
    discharging | empty) printf 'battery' ;;
    charging | fully-charged | pending-charge) printf 'plugged' ;;
    *) printf '' ;;
  esac
}

# fire <event> <icon> <summary> <body>
fire() {
  "${T[@]}" "$SCRIPT_DIR/hooks.sh" "$1" >/dev/null 2>&1 || true
  command -v notify-send >/dev/null 2>&1 || return 0
  "${T[@]}" notify-send -i "$2" "$3" "$4" || true
}

# read_device: prints "<pct> <state>" from the DisplayDevice, or nothing.
read_device() {
  "${T[@]}" upower -i "$DISPLAY_DEVICE" 2>/dev/null | awk -F': *' '
    /^ *state:/      { state = $2 }
    /^ *percentage:/ { gsub(/[^0-9.]/, "", $2); pct = $2 }
    END { if (state != "" && pct != "") print pct, state }'
}

PREV_CLASS=""
LOW_FIRED=0
FULL_FIRED=0
if [[ -s "$STATE_FILE" ]]; then
  read -r PREV_CLASS LOW_FIRED FULL_FIRED < "$STATE_FILE" || true
  LOW_FIRED="${LOW_FIRED:-0}"
  FULL_FIRED="${FULL_FIRED:-0}"
fi

while sleep "$INTERVAL"; do
  sample="$(read_device || true)"
  [[ -n "$sample" ]] || continue
  read -r PCT STATE <<< "$sample"
  CLASS="$(classify "$STATE")"
  [[ -n "$CLASS" ]] || continue
  PCT_INT="${PCT%%.*}"
  [[ "$PCT_INT" =~ ^[0-9]+$ ]] || continue

  if [[ -z "$PREV_CLASS" ]]; then
    # Seed on the first sample: never notify for the state we woke up in.
    printf '%s %s %s\n' "$CLASS" "$LOW_FIRED" "$FULL_FIRED" > "$STATE_FILE"
    PREV_CLASS="$CLASS"
    continue
  fi

  if [[ "$PREV_CLASS" == battery && "$CLASS" == plugged ]]; then
    fire power-plugged battery-full-charging-symbolic "AC connected" "Charging ($PCT%)."
  elif [[ "$PREV_CLASS" == plugged && "$CLASS" == battery ]]; then
    fire power-unplugged battery-symbolic "AC disconnected" "Running on battery ($PCT%)."
  fi

  # A fresh charge resets the low episode; a fresh discharge resets "full".
  [[ "$CLASS" == plugged ]] && LOW_FIRED=0
  [[ "$STATE" == discharging || "$STATE" == empty ]] && FULL_FIRED=0

  if [[ "$CLASS" == battery && "$LOW_FIRED" == 0 && "$PCT_INT" -le "$LOW_PCT" ]]; then
    fire battery-low battery-low-symbolic "Battery low" "At $PCT% — plug in."
    LOW_FIRED=1
  fi

  if [[ "$STATE" == fully-charged && "$FULL_FIRED" == 0 ]]; then
    fire battery-charged battery-full-symbolic "Battery full" "Fully charged — you can unplug."
    FULL_FIRED=1
  fi

  PREV_CLASS="$CLASS"
  printf '%s %s %s\n' "$CLASS" "$LOW_FIRED" "$FULL_FIRED" > "$STATE_FILE"
done
