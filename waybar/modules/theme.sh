#!/usr/bin/env bash
# Theme indicator for status bar
# Shows current theme: ☀️ (light) or 🌙 (dark)
#
# Resolution order:
#   1. GNOME gsettings — the live source of truth in hybrid (GNOME)
#      sessions; checked first so an external GNOME toggle keeps working
#   2. the per-session `theme` flag — written by scripts/toggle_theme.sh
#      on every flip and at session start (`init`). The flag carries the
#      value, so it is read as text rather than via `toggle.sh get`
#      (presence only)
#   3. .theme_state (source file; predates the flag)
#   4. dark (default)

THEME_STATE_FILE="$HOME/.config/sway/.theme_state"
THEME_FLAG="${XDG_RUNTIME_DIR:-/tmp}/sway/toggles/theme"

# Function to detect if running under Gnome
is_gnome_available() {
    command -v gsettings &>/dev/null && \
    gsettings get org.gnome.desktop.interface color-scheme &>/dev/null 2>&1
}

flag_value=""
if [[ -f "$THEME_FLAG" ]]; then
    flag_value="$(cat "$THEME_FLAG" 2>/dev/null || true)"
fi

# Get current theme
if is_gnome_available; then
    gnome_scheme=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null)
    if [[ "$gnome_scheme" == *"dark"* ]]; then
        theme="dark"
    else
        theme="light"
    fi
elif [[ "$flag_value" == "dark" || "$flag_value" == "light" ]]; then
    theme="$flag_value"
elif [[ -f "$THEME_STATE_FILE" ]]; then
    theme=$(cat "$THEME_STATE_FILE")
    if [[ "$theme" == "dark" ]]; then
        theme="dark"
    else
        theme="light"
    fi
else
    theme="dark"  # Default to dark
fi

if [[ "$theme" == "dark" ]]; then
    echo "🌙"
else
    echo "☀️"
fi
