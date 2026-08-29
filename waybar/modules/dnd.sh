#!/usr/bin/env bash
# Notification status indicator for status bar
# Shows 🧘 when DND (Focus mode) is active
#
# Reads the `dnd` flag from the per-session flag store (scripts/toggle.sh).
# The flag is owned by scripts/toggle-mako-dnd.sh: written on every
# successful flip, absent at session start, which is mako's fresh state
# (modes do not survive a mako restart, so no seeding is needed).
# Empty output hides the module while DND is off.

set -euo pipefail

# makoctl absent means DND can never be on on this box; hide.
if ! command -v makoctl >/dev/null 2>&1; then
    exit 0
fi

TOGGLE="$HOME/.config/sway/scripts/toggle.sh"

# Flag store missing (e.g. pre-deploy box); hide rather than error.
if [[ ! -x "$TOGGLE" ]]; then
    exit 0
fi

if "$TOGGLE" get dnd; then
    echo "🧘"
fi
