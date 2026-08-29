#!/usr/bin/env bash
# Toggle Mako DND mode (Focus mode)
# Shows notification when toggling state
#
# Also owns the `dnd` flag in the per-session flag store
# (scripts/toggle.sh), written on every successful flip. No session-start
# seeding is needed: the runtime dir is wiped on logout, and mako starts
# modeless, so an absent flag is exactly the fresh state.

set -euo pipefail

# Check for makoctl
if ! command -v makoctl >/dev/null 2>&1; then
    exit 0
fi

TOGGLE="$HOME/.config/sway/scripts/toggle.sh"

# Check current DND status using makoctl mode
# makoctl mode lists active modes
DND_ACTIVE=$(makoctl mode 2>/dev/null | grep -q "DoNDisturb" && echo "1" || echo "0")

if [[ "$DND_ACTIVE" == "1" ]]; then
    # Turn OFF DND
    makoctl mode -r DoNDisturb
    # Drop the flag: DND is off now, and the flag must never outlive the
    # session state it mirrors.
    "$TOGGLE" unset dnd
    # Show notification
    notify-send --replace-id=999 --app-name="Focus Mode" "🧘 Focus Mode Deactivated" "Notifications are back" --expire-time=3000
else
    # Turn ON DND
    makoctl mode -a DoNDisturb
    # Record the flip for the waybar indicator.
    "$TOGGLE" set dnd
    # Show notification
    notify-send --replace-id=999 --app-name="Focus Mode" "🧘 Focus Mode Activated" "Notifications muted" --expire-time=3000
fi
