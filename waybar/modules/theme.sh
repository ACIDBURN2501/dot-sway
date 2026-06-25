#!/bin/bash
# Theme indicator for status bar
# Shows current theme: ☀️ (light) or 🌙 (dark)

THEME_STATE_FILE="$HOME/.config/sway/.theme_state"
TOGGLE_SCRIPT="$HOME/.config/sway/scripts/toggle_theme.sh"

# Function to detect if running under Gnome
is_gnome_available() {
    command -v gsettings &>/dev/null && \
    gsettings get org.gnome.desktop.interface color-scheme &>/dev/null 2>&1
}

# Get current theme
if is_gnome_available; then
    gnome_scheme=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null)
    if [[ "$gnome_scheme" == *"dark"* ]]; then
        echo "🌙"
    else
        echo "☀️"
    fi
elif [[ -f "$THEME_STATE_FILE" ]]; then
    theme=$(cat "$THEME_STATE_FILE")
    if [[ "$theme" == "dark" ]]; then
        echo "🌙"
    else
        echo "☀️"
    fi
else
    echo "🌙"  # Default to dark
fi
