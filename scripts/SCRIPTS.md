# Utility scripts

The following scripts are used in some of the Swayfx configuration or supporting status scripts. They should be placed into:

```bash
$HOME/.local/bin/
```

- `move-ws-to-active.sh`: Moves all workspaces to the currently focused output.
- `move-ws-to-output.sh`: Moves all workspaces to a specific output (arg 1).
- `toggle-touchpad.sh`: Toggles the touchpad on/off and sends a notification.
- `monitor-hotplug.sh`: **(New)** Auto-switches between "Mobile" (internal screen only) and "Docked" (external screen only) modes.
    - **Logic:**
        - If an external monitor is connected:
            - Enables the external monitor.
            - Moves all workspaces to it.
            - Disables the internal display (`eDP-1`) by default (configurable via `DISABLE_INTERNAL_ON_EXTERNAL="true"` in the script).
            - If `DISABLE_INTERNAL_ON_EXTERNAL` is set to "false" and the lid is open, enables the internal display in extended mode.
        - If no external monitor is connected:
            - Enables the internal display.
            - Moves all workspaces to it.
            - If the laptop lid is closed, **suspends** the system (ensures it doesn't stay awake in your bag).
    - **Hardware Support:** Uses `/proc/acpi/button/lid/LID/state` to detect lid status. Optimized for ThinkPad T480.
    - **Logging:** Logs actions to `/tmp/sway-monitor-hotplug.log`.

- `toggle_theme.sh`: **(New)** Toggles between Dark and Light themes for Sway.
    - **Features:**
        - Syncs with Gnome theme settings when running under Gnome (uses `gsettings`)
        - Falls back to Sway-only theming when Gnome is not available
        - Generates theme configuration dynamically in `/tmp/sway_theme_config`
        - Updates bar colors, window borders, and workspace indicators
        - Sends desktop notifications when theme changes
    - **Usage:**
        - `toggle_theme.sh toggle` - Toggle between dark and light themes
        - `toggle_theme.sh init` - Initialize theme on startup
        - `toggle_theme.sh get` - Get current theme (dark/light)
    - **Keybind:** Mod+Shift+t
    - **Status Bar:** Shows theme indicator (🌙 for dark, ☀️ for light) via `status.d/40-theme.sh`
    - **Gnome Compatibility:** When running under Gnome, automatically syncs with system theme preferences
