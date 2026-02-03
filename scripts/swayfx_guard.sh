#!/usr/bin/env bash
# Generates a temporary config snippet for SwayFX features if it detects 'fx' in the version string.

set -euo pipefail

CONFIG_SNIPPET="/tmp/swayfx_config_snippet"

# Clear any previous snippet to ensure clean state (important for 'include' logic)
echo "" > "$CONFIG_SNIPPET"

# Check if SwayFX is running
if swaymsg -t get_version 2>/dev/null | grep -iq "fx"; then
    cat << EOF > "$CONFIG_SNIPPET"
# --- SwayFX Specific Settings (Generated) ---
# Enable blur effects (SwayFX)
blur enable
blur_xray enable

# Rounded corners (SwayFX)
corner_radius 10

# Gaps
gaps inner 5
gaps outer 5

# Dim inactive
default_dim_inactive 0.15
EOF
fi
