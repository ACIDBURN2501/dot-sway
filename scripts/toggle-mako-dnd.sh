#!/usr/bin/env bash
# Toggle Mako DND mode (Focus mode)
# Shows notification when toggling state

set -euo pipefail

# Check for makoctl
if ! command -v makoctl >/dev/null 2>&1; then
    exit 0
fi

# Check current DND status using makoctl mode
# makoctl mode lists active modes
DND_ACTIVE=$(makoctl mode 2>/dev/null | grep -q "DoNDisturb" && echo "1" || echo "0")

if [[ "$DND_ACTIVE" == "1" ]]; then
    # Turn OFF DND
    makoctl mode -r DoNDisturb
    # Show notification
    notify-send --replace-id=999 --app-name="Focus Mode" "🧘 Focus Mode Deactivated" "Notifications are back" --expire-time=3000
else
    # Turn ON DND
    makoctl mode -a DoNDisturb
    # Show notification
    notify-send --replace-id=999 --app-name="Focus Mode" "🧘 Focus Mode Activated" "Notifications muted" --expire-time=3000
fi
