#!/usr/bin/env bash
# Notification status indicator for status bar
# Shows 🧘 when DND (Focus mode) is active

set -euo pipefail

# Check for makoctl
if ! command -v makoctl >/dev/null 2>&1; then
    exit 0
fi

# Check DND status using makoctl mode
DND_ACTIVE=$(makoctl mode 2>/dev/null | grep -q "DoNDisturb" && echo "1" || echo "0")

if [[ "$DND_ACTIVE" == "1" ]]; then
    echo "🧘"
fi
