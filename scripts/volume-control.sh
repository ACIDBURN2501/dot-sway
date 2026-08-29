#!/usr/bin/env bash
# Portable volume controls for PulseAudio and PipeWire sessions.
# After every change the new level is pushed to the wob OSD pipe (via
# scripts/osd-bar.sh); mic mute gets a notification instead — it has no
# numeric level worth a bar.
set -euo pipefail

STEP="${VOLUME_STEP:-5%}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OSD="$SCRIPT_DIR/osd-bar.sh"

# Report the sink level to the OSD. Muted reports 0.
report_level() {
  if command -v wpctl >/dev/null 2>&1; then
    local out
    out=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || true)
    case "$out" in
    *MUTED*) "$OSD" 0 ;;
    *) "$OSD" "$(awk '{printf "%d", $2 * 100}' <<<"$out" 2>/dev/null || true)" ;;
    esac
  elif command -v pactl >/dev/null 2>&1; then
    local vol mute
    vol=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -om1 '[0-9]*%' | tr -d '%' || true)
    mute=$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | awk '{print $2}' || true)
    if [ "$mute" = "yes" ]; then
      "$OSD" 0
    else
      "$OSD" "$vol"
    fi
  fi
}

# Mic mute has no level worth a bar — notify instead.
report_mic() {
  command -v notify-send >/dev/null 2>&1 || return 0
  local state="unmuted"
  if wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | grep -q MUTED; then
    state="muted"
  elif pactl get-source-mute @DEFAULT_SOURCE@ 2>/dev/null | grep -q yes; then
    state="muted"
  fi
  notify-send -t 1500 "Microphone $state" || true
}

run_wpctl() {
  case "$1" in
    mute)
      wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
      ;;
    down)
      wpctl set-volume @DEFAULT_AUDIO_SINK@ "${STEP}-"
      ;;
    up)
      wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ "${STEP}+"
      ;;
    mic-mute)
      wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
      ;;
    *)
      exit 0
      ;;
  esac
}

run_pactl() {
  case "$1" in
    mute)
      pactl set-sink-mute @DEFAULT_SINK@ toggle
      ;;
    down)
      pactl set-sink-volume @DEFAULT_SINK@ "-${STEP}"
      ;;
    up)
      pactl set-sink-volume @DEFAULT_SINK@ "+${STEP}"
      ;;
    mic-mute)
      pactl set-source-mute @DEFAULT_SOURCE@ toggle
      ;;
    *)
      exit 0
      ;;
  esac
}

ACTION="${1:-}"
[ -n "$ACTION" ] || exit 0

if command -v wpctl >/dev/null 2>&1; then
  run_wpctl "$ACTION" >/dev/null 2>&1 || true
  case "$ACTION" in
    mute | down | up) report_level ;;
    mic-mute) report_mic ;;
  esac
  exit 0
fi

if command -v pactl >/dev/null 2>&1; then
  run_pactl "$ACTION" >/dev/null 2>&1 || true
  case "$ACTION" in
    mute | down | up) report_level ;;
    mic-mute) report_mic ;;
  esac
  exit 0
fi

exit 0
