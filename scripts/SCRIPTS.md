# Utility scripts

The following scripts are used in some of the Swayfx configuration or supporting status scripts. They should be placed into:

```bash
$HOME/.local/bin/
```

- `move-ws-to-active.sh`: Moves all workspaces to the currently focused output.
- `move-ws-to-output.sh`: Moves all workspaces to a specific output (arg 1).
- `toggle-touchpad.sh`: Toggles the touchpad on/off and sends a notification.
- `volume-control.sh`: Handles mute, volume up/down, and mic mute.
    - Prefers `wpctl` on PipeWire systems.
    - Falls back to `pactl` for PulseAudio-compatible sessions.
    - Intended for media-key bindings that should work across built-in and USB keyboards.
- `brightness-control.sh`: Handles brightness up/down for laptop backlights.
    - Uses `brightnessctl` when `/sys/class/backlight` is available.
    - Exits silently on desktops or systems without a controllable backlight.
- `monitor-hotplug.sh`: Auto-switches between "Mobile" (internal screen only) and "Docked" (external screen only) modes.
    - **Logic:**
        - If an external monitor is connected:
            - Enables the external monitor.
            - Moves all workspaces to it.
            - Disables the internal display by default (configurable via `DISABLE_INTERNAL_ON_EXTERNAL="true"` in the script).
            - If `DISABLE_INTERNAL_ON_EXTERNAL` is set to "false" and the lid is open, enables the internal display in extended mode.
        - If no external monitor is connected:
            - Enables the internal display.
            - Moves all workspaces to it.
            - If the laptop lid is closed, **suspends** the system (ensures it doesn't stay awake in your bag).
    - **Hardware Support:** Internal display is auto-detected as the first `eDP-*` output. Lid state is read from the first available `/proc/acpi/button/lid/*/state` entry when present.
    - **Logging:** Logs actions to `/tmp/sway-monitor-hotplug.log`.
    - **External output settings precedence:**
        1. `DOTSWAY_EXT_*` environment variables
        2. Per-monitor matches from `~/.config/sway/scripts/monitor-profiles.local.sh`
        3. Universal fallback defaults (`1920x1080@60Hz`, scale `1`, adaptive sync `off`)
    - **Per-monitor setup:**
        - Copy `scripts/monitor-profiles.example.sh` to `~/.config/sway/scripts/monitor-profiles.local.sh`.
        - Use `swaymsg -t get_outputs -r` to capture the external display `name`, `make`, `model`, and `serial`.
        - Add a `dotsway_monitor_profile()` case entry that calls `set_monitor_profile MODE SCALE ADAPTIVE_SYNC`.
        - Reload Sway and run `~/.config/sway/scripts/monitor-hotplug.sh --once` to re-apply immediately.
        - Check `/tmp/sway-monitor-hotplug.log` if the detected values or applied settings do not look right.
    - **Environment variables** (set before starting Sway to force the same external monitor behaviour everywhere):

        | Variable | Default | Description |
        |---|---|---|
        | `DOTSWAY_EXT_RES` | `1920x1080@60Hz` | Forced mode string for the external monitor (e.g. `3840x2160@120Hz`) |
        | `DOTSWAY_EXT_SCALE` | `1` | Forced output scale factor (e.g. `1.25` for a 4K display) |
        | `DOTSWAY_EXT_ADAPTIVE_SYNC` | `off` | Enable adaptive sync (`on`/`off`) |
        | `DOTSWAY_INTERNAL_OUTPUT` | *(auto)* | Force a specific internal output name (e.g. `eDP-1`) |
        | `DOTSWAY_MONITOR_PROFILES_FILE` | `~/.config/sway/scripts/monitor-profiles.local.sh` | Alternate path for local per-monitor overrides |

- `toggle_theme.sh`: **(New)** Toggles between Dark and Light themes for Sway.
    - **Features:**
        - Syncs with Gnome theme settings when running under Gnome (uses `gsettings`)
        - Falls back to Sway-only theming when Gnome is not available
        - Generates theme configuration dynamically in `/tmp/sway_theme_config`
        - Updates bar colors, window borders, and workspace indicators
        - Updates wofi launcher theme (symlinks `~/.config/wofi/style.css` to either `style-dark.css` or `style-light.css`)
        - Updates kitty terminal theme (Tokyo Night Moon/Day)
        - Updates mako notification theme (optional - only if installed)
        - Sends desktop notifications when theme changes (requires notify-send)
    - **Usage:**
        - `toggle_theme.sh toggle` - Toggle between dark and light themes
        - `toggle_theme.sh init` - Initialize theme on startup
        - `toggle_theme.sh get` - Get current theme (dark/light)
    - **Keybind:** Mod+Shift+t
    - **Status Bar:** Shows theme indicator (🌙 for dark, ☀️ for light) via `status.d/40-theme.sh`
    - **Gnome Compatibility:** When running under Gnome, automatically syncs with system theme preferences
    - **Optional Components:** Gracefully handles missing components (mako, kitty themes, etc.)
    - **Wofi Requirements:** If using wofi, both `~/.config/wofi/style-dark.css` and `~/.config/wofi/style-light.css` must exist. Copy the templates from `extra/wofi/` - see `extra/EXTRA.md` for setup instructions.
