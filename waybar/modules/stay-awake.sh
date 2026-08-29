#!/usr/bin/env bash
# Stay-awake indicator for the status bar
# Shows ☕ while stay-awake mode is active
#
# Reads the `stay-awake` flag from the per-session flag store
# (scripts/toggle.sh). The flag is owned by scripts/toggle-stay-awake.sh:
# written on every flip, absent at session start (the runtime dir is wiped
# on logout, so stay-awake never survives a session). Empty output hides
# the module while stay-awake is off.

set -euo pipefail

TOGGLE="$HOME/.config/sway/scripts/toggle.sh"

# Flag store missing (e.g. pre-deploy box); hide rather than error.
if [[ ! -x "$TOGGLE" ]]; then
    exit 0
fi

if "$TOGGLE" get stay-awake 2>/dev/null; then
    echo "☕"
fi
