#!/usr/bin/env bash
# idle-sandbox.sh — sandboxed assertion suite for the idle/lock stack:
# scripts/idle-manager.sh (host.env parsing, swayidle argv, restart), the
# stay-awake toggle (scripts/toggle-stay-awake.sh) and its waybar
# indicator (waybar/modules/stay-awake.sh).
#
# Runs against a throwaway $HOME with the repo copied in and PATH
# restricted to the stub bin: swayidle logs its argv instead of running
# (the real binary needs a compositor connection CI does not have), and
# notify-send logs to a file. The toggle flag store is the real
# scripts/toggle.sh under the sandbox XDG_RUNTIME_DIR.
#
# The real-swayidle timing behaviour (timeouts fire after N seconds, the
# stay-awake guard suppresses them) is verified live on a machine with a
# session, not here — see the ticket.
#
# Usage: idle-sandbox.sh /path/to/repo
# Exit:  0 when every assertion passes; prints N/M summary.
set -euo pipefail

REPO="${1:?usage: idle-sandbox.sh /path/to/repo}"
[[ -f "$REPO/scripts/idle-manager.sh" ]] || { echo "not a repo root: $REPO" >&2; exit 2; }

pass=0 fail=0
assert() { # assert <desc> <cmd...>
  local desc="$1"
  shift
  if "$@"; then
    pass=$((pass + 1))
    printf 'ok   %s\n' "$desc"
  else
    fail=$((fail + 1))
    printf 'FAIL %s\n' "$desc"
  fi
}
eq() { [[ "${1-}" == "${2-}" ]]; }
grepq() { grep -q -e "$1" "$2" 2>/dev/null; }
no_grepq() { ! grep -q -e "$1" "$2" 2>/dev/null; }
pid_alive() { kill -0 "$1" 2>/dev/null; }
pid_is_swayidle() { grep -qa swayidle "/proc/$1/cmdline" 2>/dev/null; }
not() { if "$@"; then return 1; else return 0; fi; }

SB=""
new_sandbox() { # sets HOME_ RUNTIME_ BIN_ LOG_ ARGV_ SB
  SB=$(mktemp -d)
  HOME_="$SB/home"
  RUNTIME_="$SB/runtime"
  BIN_="$SB/bin"
  LOG_="$SB/notify.log"
  ARGV_="$SB/swayidle.argv"
  Sway="$HOME_/.config/sway"
  mkdir -p "$HOME_/.config" "$RUNTIME_" "$BIN_" "$Sway"
  # Copy without .git and the wallpaper pool — heavy, and no suite needs them.
  tar -C "$REPO" --exclude=./.git --exclude=./images/wallpapers -cf - . | tar -C "$Sway" -xf -
  : > "$LOG_"
  : > "$ARGV_"
  # Real externals the manager and toggle need; PATH is the stub bin ONLY.
  for b in bash dirname grep cat sleep mkdir rm chmod sh; do
    cp "$(command -v "$b")" "$BIN_/$b" 2>/dev/null || true
  done
  # swayidle: log the full argv (one call per line), then optionally hold
  # so the restart test has something to kill.
  printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s"\nif [ -n "${IDLE_STUB_HOLD:-}" ]; then sleep 300; fi\nexit 0\n' "$ARGV_" > "$BIN_/swayidle"
  # notify-send: logs the full invocation.
  printf '#!/bin/sh\necho "notify-send $*" >> "%s"\nexit 0\n' "$LOG_" > "$BIN_/notify-send"
  chmod +x "$BIN_"/*
}

# Run a sandbox script with the sandboxed HOME / XDG_RUNTIME_DIR / PATH.
# NEVER call these scripts with the suite's own environment: the real
# swayidle would attach to the caller's session.
run_sandbox() { # run_sandbox <script> [args...]
  env HOME="$HOME_" XDG_CONFIG_HOME="$HOME_/.config" XDG_RUNTIME_DIR="$RUNTIME_" PATH="$BIN_" IDLE_STUB_HOLD="${IDLE_STUB_HOLD:-}" \
    /bin/bash "$@"
}

# --- conf parsing and argv construction ---------------------------------

new_sandbox
run_sandbox "$Sway/scripts/idle-manager.sh" start >/dev/null 2>&1
assert "defaults: swayidle started with -w" grepq '^-w ' "$ARGV_"
assert "defaults: lock at 600s" grepq 'timeout 600 ' "$ARGV_"
assert "defaults: screen off at 900s" grepq 'timeout 900 ' "$ARGV_"
assert "defaults: screen-off has a resume that powers the display back on" grepq 'resume timeout 5 swaymsg' "$ARGV_"
assert "defaults: before-sleep lock present" grepq 'before-sleep ' "$ARGV_"
assert "guards consult the stay-awake flag" grepq 'stay-awake' "$ARGV_"
assert "lock command uses the wallpaper" grepq 'swaylock -f -i .*/images/wp.png' "$ARGV_"

new_sandbox
printf 'LOCK_TIMEOUT=60\nSCREEN_OFF_TIMEOUT=120\n' > "$Sway/host.env"
run_sandbox "$Sway/scripts/idle-manager.sh" start >/dev/null 2>&1
assert "host.env: lock timing applied" grepq 'timeout 60 ' "$ARGV_"
assert "host.env: screen-off timing applied" grepq 'timeout 120 ' "$ARGV_"
assert "host.env: defaults no longer used" no_grepq 'timeout 600 ' "$ARGV_"

new_sandbox
printf 'LOCK_TIMEOUT=0\n' > "$Sway/host.env"
run_sandbox "$Sway/scripts/idle-manager.sh" start >/dev/null 2>&1
assert "host.env: 0 disables the lock timeout" no_grepq 'timeout 600 ' "$ARGV_"
assert "host.env: screen-off still active when only the lock is disabled" grepq 'timeout 900 ' "$ARGV_"
assert "host.env: before-sleep lock survives a disabled idle lock" grepq 'before-sleep ' "$ARGV_"

new_sandbox
printf 'LOCK_TIMEOUT=banana\nBOGUS_KEY=1\nSCREEN_OFF_TIMEOUT=42 # trailing comment\n' > "$Sway/host.env"
run_sandbox "$Sway/scripts/idle-manager.sh" start >/dev/null 2>&1
assert "host.env: invalid value falls back to the default" grepq 'timeout 600 ' "$ARGV_"
assert "host.env: unknown key ignored" no_grepq 'BOGUS_KEY' "$ARGV_"
assert "host.env: trailing comments stripped" grepq 'timeout 42 ' "$ARGV_"

new_sandbox
printf 'LOCK_TIMEOUT=60\n' > "$Sway/host.env"
LOCK_TIMEOUT=30 run_sandbox "$Sway/scripts/idle-manager.sh" start >/dev/null 2>&1
assert "precedence: env var beats host.env" grepq 'timeout 30 ' "$ARGV_"
assert "precedence: host.env value not used when env is set" no_grepq 'timeout 60 ' "$ARGV_"

# --- restart semantics ---------------------------------------------------

new_sandbox
IDLE_STUB_HOLD=1 run_sandbox "$Sway/scripts/idle-manager.sh" start >/dev/null 2>&1 &
FIRST=$!
sleep 0.5
FIRST_PID="$(cat "$RUNTIME_/sway/idle-manager.pid" 2>/dev/null || true)"
IDLE_STUB_HOLD=1 run_sandbox "$Sway/scripts/idle-manager.sh" start >/dev/null 2>&1 &
SECOND=$!
sleep 0.5
SECOND_PID="$(cat "$RUNTIME_/sway/idle-manager.pid" 2>/dev/null || true)"
assert "restart: a previous instance is replaced, not duplicated" not eq "$FIRST_PID" "$SECOND_PID"
assert "restart: pid file tracks a live swayidle" pid_is_swayidle "$SECOND_PID"
assert "restart: the old process is gone" not pid_alive "$FIRST_PID"
assert "restart: both invocations logged" eq "$(wc -l < "$ARGV_")" "2"
pkill -f "$SB" 2>/dev/null || true
wait "$FIRST" "$SECOND" 2>/dev/null || true

new_sandbox
run_sandbox "$Sway/scripts/idle-manager.sh" stop >/dev/null 2>&1
assert "stop without a previous instance is a no-op (exit 0)" eq "$?" "0"

# --- stay-awake toggle and indicator -------------------------------------

new_sandbox
run_sandbox "$Sway/scripts/toggle-stay-awake.sh" >/dev/null 2>&1
assert "toggle: sets the flag" run_sandbox "$Sway/scripts/toggle.sh" get stay-awake
assert "toggle: notifies when activating" grepq 'Stay awake on' "$LOG_"
assert "toggle: activation notification is ordinary urgency (DND-suppressible)" no_grepq '-u critical' "$LOG_"
run_sandbox "$Sway/scripts/toggle-stay-awake.sh" >/dev/null 2>&1
assert "toggle: clears the flag" not run_sandbox "$Sway/scripts/toggle.sh" get stay-awake
assert "toggle: notifies when deactivating" grepq 'Stay awake off' "$LOG_"

new_sandbox
OUT="$(run_sandbox "$Sway/waybar/modules/stay-awake.sh")"
assert "indicator: hidden while stay-awake is off" eq "$OUT" ""
run_sandbox "$Sway/scripts/toggle.sh" set stay-awake
OUT="$(run_sandbox "$Sway/waybar/modules/stay-awake.sh")"
assert "indicator: shows ☕ while stay-awake is on" eq "$OUT" "☕"

printf '%d/%d assertions passed\n' "$pass" "$((pass + fail))"
[[ "$fail" -eq 0 ]]
