# Utility scripts

These scripts live in `scripts/` and are invoked in place from `$HOME/.config/sway/scripts/` — keybinds and `exec` lines reference them by that path, so there's nothing to copy elsewhere.

- `move-ws-to-active.sh`: Moves all workspaces to the currently focused output. Not bound by default — available for a keybind or manual use.
- `move-ws-to-output.sh`: Moves all workspaces to a specific output (arg 1). Not bound by default — available for a keybind or manual use.
- `toggle-touchpad.sh`: Toggles the touchpad on/off and sends a notification.
- `volume-control.sh`: Handles mute, volume up/down, and mic mute.
    - Prefers `wpctl` on PipeWire systems.
    - Falls back to `pactl` for PulseAudio-compatible sessions.
    - Intended for media-key bindings that should work across built-in and USB keyboards.
- `brightness-control.sh`: Handles brightness up/down for laptop backlights.
    - Uses `brightnessctl` when `/sys/class/backlight` is available.
    - Exits silently on desktops or systems without a controllable backlight.
- `network-tui.sh`: Launches the best available network management TUI in kitty for the Waybar network click handler.
    - **Probe order:** `impala` (recommended; requires `iwd` as the wifi backend) → `nmtui` (requires NetworkManager) → `iwctl` (iwd interactive shell).
    - **Fallback:** read-only `ip -c -br a` + `ip -c r` summary with `kitty --hold` so the window stays open.
    - **Adding a TUI:** install one of the above and the script picks it up automatically — no config edit needed.
- `bluetooth-tui.sh`: Launches the best available bluetooth management TUI in kitty for the Waybar bluetooth click handler.
    - **Probe order:** `bluetuith` (recommended; ncurses TUI) → `bluetoothctl` (interactive shell).
    - **Adding a TUI:** install `bluetuith` and the script picks it up automatically.
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

- `rotate-wallpaper.sh`: Picks a random `.png/.jpg/.jpeg` from the wallpaper pool, repoints the `images/wp.png` symlink at it, and applies the change live via `swaymsg output * bg`. Bound to `$mod+Shift+w` for on-demand switching. `config.d/wallpaper` runs it with `--if-unset` on start/reload, which only picks when `wp.png` isn't already set — so reloads and logins keep the current wallpaper.
    - **Pool location:** `images/wallpapers/` by default. A `wallpaper_dir.local` file at the repo root (gitignored — copy `wallpaper_dir.local.example`) redirects it to any external folder, e.g. a synced image library; only top-level files are scanned, so a subfolder of a larger collection works.
    - **Empty/absent pool:** an already-set `wp.png` is left alone; otherwise it falls back to the committed `images/default.png`, so `wp.png` always resolves (no black desktop, no broken swaylock image) even on a fresh checkout with an empty pool.
    - **Lock screen:** the swaylock keybind (and the optional swayidle example in `config`) consume `images/wp.png`, so the lock screen follows rotation automatically — no extra wiring.
    - **Override the repo dir:** set `SWAY_DIR=/some/other/path` before invoking; the script resolves `images/`, `wallpaper_dir.local`, and the default pool underneath it.
- `toggle_theme.sh`: Switches the desktop between dark and light themes in one keypress (`Mod+Shift+t`). Source of truth is Gnome's `org.gnome.desktop.interface color-scheme` when `gsettings` is available, otherwise `~/.config/sway/.theme_state`.
    - **Updates in lockstep:**
        - Sway colors via `/tmp/sway_theme_config` (sourced from `config`)
        - Waybar palette by symlinking `waybar/colors.css` → `colors-{dark,light}.css`; `toggle` additionally sends `SIGUSR2` for a live reload (`init` deliberately doesn't — signalling waybar mid-startup races its async D-Bus setup and segfaults it)
        - Kitty theme (Tokyo Night Moon/Day) via `kitty @ set-colors`
        - Wofi theme by symlinking `~/.config/wofi/style.css`
        - Mako notification theme (when installed) with `makoctl reload`
        - Gnome `gtk-theme` (when available)
    - **Status indicator:** `waybar/modules/theme.sh` emits 🌙 (dark) or ☀️ (light); click toggles.
    - **Subcommands:**
        - `toggle_theme.sh toggle` — flip
        - `toggle_theme.sh init` — re-apply current theme to all components (invoked at Sway startup)
        - `toggle_theme.sh get` — print `dark` or `light`
    - **Component prerequisites:**
        - **Waybar:** `waybar/colors-dark.css` and `waybar/colors-light.css` define the palette via `@define-color`. `colors.css` symlink is managed automatically and gitignored. `SIGUSR2` is best-effort — a no-op if Waybar isn't running.
        - **Wofi:** no setup needed — `~/.config/wofi/style.css` is symlinked straight at the repo source `extra/wofi/style-{dark,light}.css`. See `extra/EXTRA.md`.
