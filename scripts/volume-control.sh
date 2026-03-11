#!/usr/bin/env bash
# Portable volume controls for PulseAudio and PipeWire sessions.
set -euo pipefail

STEP="${VOLUME_STEP:-5%}"

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
  exit 0
fi

if command -v pactl >/dev/null 2>&1; then
  run_pactl "$ACTION" >/dev/null 2>&1 || true
  exit 0
fi

exit 0
