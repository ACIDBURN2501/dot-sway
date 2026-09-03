#!/usr/bin/env bash
# Idle session manager: builds the swayidle command line from the user's
# idle settings and execs swayidle.
#
# Inputs:  host.env at the repo root (optional — copy host.env.example),
#          loaded via scripts/lib/host-env.sh:
#            LOCK_TIMEOUT=<seconds>        lock after this much idle (0 disables)
#            SCREEN_OFF_TIMEOUT=<seconds>  power the display off after this much
#                                          idle (0 disables)
#            Non-numeric values are reported on stderr and ignored.
#          Precedence: env var > host.env > default (600 / 900).
#          $XDG_RUNTIME_DIR/sway/idle-manager.pid: restart marker. Starting
#          again stops the previous instance first, so "edit host.env, run
#          again" applies the new timings without a session reload.
# Outputs: one long-running swayidle process (this script execs into it).
#
# Events wired:
#   timeout <lock>        swaylock with the wallpaper image — skipped while
#                         the stay-awake flag is set (toggle-stay-awake.sh)
#   timeout <screen off>  swaymsg "output * power off", resumed on activity
#                         with "output * power on" — same stay-awake guard
#   before-sleep          swaylock -w: always locks before suspend, even in
#                         stay-awake mode (manual sleep is a deliberate act)
#
# swayidle runs each command in a shell, so the guards are embedded in the
# command strings themselves. swaylock deliberately has no timeout wrapper:
# it must block until the session is unlocked.
#
# Usage:
#   idle-manager.sh          start (restarts a previous instance)
#   idle-manager.sh stop     stop a running instance

set -euo pipefail

DEFAULT_LOCK_TIMEOUT=600
DEFAULT_SCREEN_OFF_TIMEOUT=900

SWAY_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/sway"
# shellcheck disable=SC1091
. "$SWAY_DIR/scripts/lib/host-env.sh"
PID_FILE="${XDG_RUNTIME_DIR:-/tmp}/sway/idle-manager.pid"
WALLPAPER="$HOME/.config/sway/images/wp.png"
TOGGLE="$HOME/.config/sway/scripts/toggle.sh"

LOCK_CMD="swaylock -f -i $WALLPAPER"
SCREEN_OFF_CMD="timeout 5 swaymsg \"output * power off\""
RESUME_CMD="timeout 5 swaymsg \"output * power on\""

# The stay-awake guard: swayidle executes timeout commands in a shell, so
# each command consults the flag store first. A missing toggle.sh fails
# open (the real command still runs — locking beats not locking).
stay_guard() {
  printf '%s get stay-awake >/dev/null 2>&1 || %s' "$TOGGLE" "$1"
}

# Resolve the timeouts: env var > host.env > default. Values must be a
# number of seconds; anything else is a warning and the default stands.
read_conf() {
  load_host_env
  LOCK_TIMEOUT="${LOCK_TIMEOUT:-$DEFAULT_LOCK_TIMEOUT}"
  SCREEN_OFF_TIMEOUT="${SCREEN_OFF_TIMEOUT:-$DEFAULT_SCREEN_OFF_TIMEOUT}"
  if [[ ! "$LOCK_TIMEOUT" =~ ^[0-9]+$ ]]; then
    printf 'idle-manager: LOCK_TIMEOUT must be a number of seconds, got: %s\n' "$LOCK_TIMEOUT" >&2
    LOCK_TIMEOUT=$DEFAULT_LOCK_TIMEOUT
  fi
  if [[ ! "$SCREEN_OFF_TIMEOUT" =~ ^[0-9]+$ ]]; then
    printf 'idle-manager: SCREEN_OFF_TIMEOUT must be a number of seconds, got: %s\n' "$SCREEN_OFF_TIMEOUT" >&2
    SCREEN_OFF_TIMEOUT=$DEFAULT_SCREEN_OFF_TIMEOUT
  fi
}

stop_running() {
  [[ -s "$PID_FILE" ]] || return 0
  local old
  old="$(cat "$PID_FILE" 2>/dev/null || true)"
  # Only kill the pid when it still is a swayidle process (pid files can
  # outlive the process they name).
  if [[ -n "$old" ]] && grep -qa 'swayidle' "/proc/$old/cmdline" 2>/dev/null; then
    kill "$old" 2>/dev/null || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      kill -0 "$old" 2>/dev/null || break
      sleep 0.1
    done
    kill -9 "$old" 2>/dev/null || true
  fi
  rm -f "$PID_FILE"
}

case "${1:-start}" in
  stop)
    stop_running
    ;;
  start)
    read_conf
    stop_running
    mkdir -p "${PID_FILE%/*}"
    printf '%s\n' "$$" > "$PID_FILE"
    args=(-w)
    if (( LOCK_TIMEOUT > 0 )); then
      args+=(timeout "$LOCK_TIMEOUT" "$(stay_guard "$LOCK_CMD")")
    fi
    if (( SCREEN_OFF_TIMEOUT > 0 )); then
      args+=(timeout "$SCREEN_OFF_TIMEOUT" "$(stay_guard "$SCREEN_OFF_CMD")" resume "$RESUME_CMD")
    fi
    args+=(before-sleep "$(stay_guard "$LOCK_CMD")")
    exec swayidle "${args[@]}"
    ;;
  *)
    printf 'Usage: %s [start|stop]\n' "$0" >&2
    exit 2
    ;;
esac
