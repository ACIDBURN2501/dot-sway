#!/usr/bin/env bash
# Re-sync mako's DoNDisturb mode from the dnd toggle flag.
#
# Mako modes are runtime-only: `makoctl reload` (run by toggle_theme.sh on
# every theme flip) restarts the daemon and silently drops any active custom
# mode. This helper re-applies the mode the flag records: flag set -> ensure
# DoNDisturb is active, flag unset -> ensure it is not.
#
# Read-then-act: the active mode list comes from `makoctl mode`, so the
# script is idempotent and never depends on makoctl's exit codes for
# add/remove against an inactive mode.
#
# Silent no-op when makoctl or the flag store is absent.
set -euo pipefail

MODE="DoNDisturb"
TOGGLE="$HOME/.config/sway/scripts/toggle.sh"

command -v makoctl >/dev/null 2>&1 || exit 0
[[ -x "$TOGGLE" ]] || exit 0

active() { makoctl mode 2>/dev/null | grep -q "$MODE"; }

if "$TOGGLE" get dnd; then
  if ! active; then
    makoctl mode -a "$MODE" >/dev/null 2>&1 || true
  fi
else
  if active; then
    makoctl mode -r "$MODE" >/dev/null 2>&1 || true
  fi
fi

exit 0
