#!/usr/bin/env bash
# Toggle stay-awake mode: while set, idle-manager.sh's lock and screen-off
# timeouts no-op (the guards inside their command strings consult this
# flag). Locking before a manual suspend still happens; that is a
# deliberate act, not idle.
#
# Owns the `stay-awake` flag in the per-session flag store
# (scripts/toggle.sh), written on every flip. The runtime dir is wiped on
# logout, so an absent flag is exactly the fresh state: stay-awake never
# survives a session.
#
# Bound to $super+Ctrl+s and the waybar stay-awake indicator's click.

set -euo pipefail

TOGGLE="$HOME/.config/sway/scripts/toggle.sh"

if "$TOGGLE" get stay-awake 2>/dev/null; then
  "$TOGGLE" unset stay-awake
  notify-send --replace-id=998 --app-name="Stay Awake" "☕ Stay awake off" "Idle lock and screen-off are back" --expire-time=3000
else
  "$TOGGLE" set stay-awake
  notify-send --replace-id=998 --app-name="Stay Awake" "☕ Stay awake on" "Idle lock and screen-off suspended" --expire-time=3000
fi
