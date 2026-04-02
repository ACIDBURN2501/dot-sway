# Sway/Swayfx Minimal Status Bar

This directory contains a very small set of scripts to drive a simple, fast status bar for Sway or Swayfx. The bar shows the battery, any additional status snippets from `status.d/`, and the current time.

- Battery (left): concise battery summary derived from UPower
- Center: outputs from any executable scripts in `~/.config/sway/status.d`
- Time (right): current time in HH:MM

The core loop is implemented in `statusbar.sh`. Supporting scripts live alongside it and under `status.d/`.

<p align="center">
  <img src="images/preview.png" alt="Desktop preview." />
</p>


## Files

- `config` — A default Sway configuration file you can use as a starting point.
- `config.d/` — Drop-in directory for additional Sway configuration snippets.
    - `compose_key` — Compose key settings (see [Compose Key Configuration](#compose-key-configuration) below).
    - `floating_windows` — Rules to make specific applications always open as floating windows (e.g., calculators, dialogs). See [Floating Windows Configuration](#floating-windows-configuration) below.

- `statusbar.sh` — main loop that prints a single status line every second: `<Battery> | <Status Icons> | <Time>`
- `battery.sh` — reads UPower's DisplayDevice and prints a semicolon-delimited line: `icon;label;color;default`
- `power.sh` — tiny helper that converts `battery.sh` output into a compact human-readable string (used similarly to `batt_short` in `statusbar.sh`)
- `status.d/` — drop-in directory for status items. Included scripts:
    - `20-brightness.sh` — Displays brightness percentage (uses `brightnessctl`)
    - `30-volume.sh` — Displays volume level and mute status (uses `pactl`)
    - `40-theme.sh` — Displays current theme indicator (🌙 for dark, ☀️ for light)
    - `80-bluetooth.sh` — Displays Bluetooth connection status
    - `90-net.sh` — Displays network status (WiFi/Ethernet)
- `scripts/` — Utility scripts for window management and system control.
    - `monitor-hotplug.sh` — Robustly handles monitor switching (internal vs. external) to avoid Kanshi race conditions.
    - `toggle_theme.sh` — **New!** Toggles between Dark and Light themes. Syncs with Gnome when available.
    - See `scripts/SCRIPTS.md` for more details.
- `extra/` — Extra configuration files, such as `kanshi` config (see `extra/EXTRA.md`).

## Requirements

- Bash (for the scripts)
- `jq` (for JSON parsing in utility scripts)
- `swaymsg` (for interacting with Sway)
- `swaynag` (for confirmation dialogs)
- UPower (for battery information)
- `brightnessctl` (for `status.d/20-brightness.sh`)
- `pactl` or `wpctl` (audio control helpers; `status.d/30-volume.sh` currently uses `pactl`)
- `bluez` / `bluetoothctl` (for `status.d/80-bluetooth.sh`)
- `gsettings` (optional, for Gnome theme syncing)
- `wofi` (optional, application launcher with automatic theme switching)
- `mako` (optional, notification daemon with automatic theme switching)
- `grim` (for screenshots)
- `slurp` (for interactive region selection in screenshots)
- `systemctl` (for system suspension and environment management)
- `dbus-update-activation-environment` (for environment variable management)
- Optional: `swayidle`, `swaylock` (referenced in `config`)

## How it works

1. `statusbar.sh` loops once per second
2. It calls `battery.sh` (if present and executable) and compresses that into a short left section (e.g. `󱟞 4h 12m`, `󱟠 1h 05m`, or `🔌` when full)
3. It executes each executable file in `~/.config/sway/status.d` (in lexical order) and concatenates their outputs with spaces for the center section
4. It appends the current time as the right section
5. Only non-empty sections are printed; sections are separated by ` | `

### Media Keys

Media keys are handled with small helper scripts and both of Sway's binding
styles: `bindsym` for `XF86...` keysyms and `bindcode` for standard Linux input
codes. This makes the defaults work more reliably with built-in laptop
keyboards, external USB keyboards, and keyboards that expose volume keys
through a separate `Consumer Control` device.

- `scripts/volume-control.sh` prefers `wpctl` and falls back to `pactl`
- `scripts/brightness-control.sh` uses `brightnessctl` when a backlight device exists
- The default bindings use both `bindsym` and `bindcode` for mute, volume, mic mute, and brightness

If your media keys are visible to `libinput` but still do not trigger in Sway,
an optional `swhkd` fallback config is provided in `extra/swhkd/swhkdrc`.
Use it only on affected hardware, otherwise both Sway and `swhkd` may respond
to the same key and double-trigger the action.

Common Linux media key codes used by the config:

- `121` - mute (`KEY_MUTE`)
- `122` - volume down (`KEY_VOLUMEDOWN`)
- `123` - volume up (`KEY_VOLUMEUP`)
- `232` - brightness down (`KEY_BRIGHTNESSDOWN`)
- `233` - brightness up (`KEY_BRIGHTNESSUP`)
- `256` - microphone mute (`KEY_MICMUTE`)

### Optional `swhkd` Fallback

For keyboards and laptops that expose media keys through separate hotkey devices
that Sway does not bind reliably, you can use `swhkd` as a media-key fallback.

Example startup:

```bash
swhks &
pkexec swhkd --config "$HOME/.config/swhkd/swhkdrc"
```

Suggested setup:

1. Copy `extra/swhkd/swhkdrc` to `~/.config/swhkd/swhkdrc`
2. Keep it limited to media keys so it does not conflict with normal Sway shortcuts
3. Enable it only on machines where Sway does not catch those keys reliably

## Using with Sway/Swayfx

### Configuration
A default configuration is provided in the `config` file. To use it:

```bash
cp ~/.config/sway/config ~/.config/sway/config.backup
cp ~/.config/sway/config ~/.config/sway/config
```

### Monitor Hotplug Configuration

`scripts/monitor-hotplug.sh` auto-detects the internal display (`eDP-*`) and any connected external display. External monitor settings now resolve in this order:

1. Explicit environment variables
2. Per-monitor matches from `~/.config/sway/scripts/monitor-profiles.local.sh`
3. Universal fallback defaults

The universal fallback is intentionally conservative: `1920x1080@60Hz`, scale `1`, and adaptive sync `off`.

This keeps the shared Sway config portable across laptops and desktops, while still allowing machine- or monitor-specific overrides outside the tracked config.

Use environment variables only when you want to force the same settings on every machine that uses this config. They must be set before Sway starts:

```bash
# Example: force all machines to use the same external mode
export DOTSWAY_EXT_RES="3840x2160@120Hz"
export DOTSWAY_EXT_SCALE="1"
export DOTSWAY_EXT_ADAPTIVE_SYNC="on"
```

### Compose Key Configuration

The config sets a compose key for entering special characters (e.g., `Menu`, `-`, `-`, `-` → `—`). The compose key defaults to the Menu key and is controlled by the `$compose_key` variable in the main config:

```
set $compose_key compose:menu
```

To change it, edit that line or override it in a `config.d/` snippet (since includes are loaded after the default `set`):

```
# Example: use Right Alt as compose key
set $compose_key compose:ralt
```

Common options:
- `compose:menu` — Menu key (default)
- `compose:ralt` — Right Alt
- `compose:lwin` — Left Windows key
- `compose:rwin` — Right Windows key
- `compose:caps` — Caps Lock

See `man 7 xkeyboard-config` for more XKB options.

For machine- or monitor-specific behavior, copy `scripts/monitor-profiles.example.sh` to `~/.config/sway/scripts/monitor-profiles.local.sh` and edit it for your hardware.

```bash
cp ~/.config/sway/scripts/monitor-profiles.example.sh ~/.config/sway/scripts/monitor-profiles.local.sh
```

Recommended setup flow:

1. Copy `~/.config/sway/scripts/monitor-profiles.example.sh` to `~/.config/sway/scripts/monitor-profiles.local.sh`.
2. Run `swaymsg -t get_outputs -r` and note the external monitor `make`, `model`, and `serial` values.
3. Add a `case` entry in `~/.config/sway/scripts/monitor-profiles.local.sh` for that monitor.
4. Reload Sway with `swaymsg reload`.
5. Re-apply the layout immediately with `~/.config/sway/scripts/monitor-hotplug.sh --once`.

The Sway config uses `exec_always` for the hotplug daemon so a reload restarts it and picks up profile changes.

To inspect the detected identity values more easily, this can help:

```bash
swaymsg -t get_outputs -r | jq -r '.[] | select(.name | startswith("eDP") | not) | [.name, .make, .model, .serial] | @tsv'
```

Example profile:

```bash
dotsway_monitor_profile() {
  local _output_name="$1"
  local make="$2"
  local model="$3"
  local serial="$4"

  case "$make|$model|$serial" in
    # Match a specific unit by serial
    'ExampleMake|ExampleModel|SERIALHERE')
      set_monitor_profile '3840x2160@120Hz' '1' 'on'
      ;;
    # Match any unit of this make/model (leave serial empty)
    'ExampleMake|ExampleModel|')
      set_monitor_profile '1920x1080@60Hz' '1' 'off'
      ;;
  esac
}
```

Match on `serial` when you want a specific physical display, or leave it empty when every monitor with the same make/model should share one profile.

| Variable | Default | Description |
|---|---|---|
| `DOTSWAY_EXT_RES` | `1920x1080@60Hz` | Forced mode for the external monitor. Environment variables override any profile match. |
| `DOTSWAY_EXT_SCALE` | `1` | Output scale factor. Environment variables override any profile match. |
| `DOTSWAY_EXT_ADAPTIVE_SYNC` | `off` | Adaptive sync (`on`/`off`). Only enable if your GPU and display support it. |
| `DOTSWAY_INTERNAL_OUTPUT` | *(auto)* | Override auto-detection of the internal panel (e.g. `eDP-1`). |
| `DOTSWAY_MONITOR_PROFILES_FILE` | `~/.config/sway/scripts/monitor-profiles.local.sh` | Alternate path for local per-monitor overrides. |

The internal display is auto-detected as the first `eDP-*` output reported by Sway, so no configuration is needed in most cases.

If a profile does not seem to apply, check `/tmp/sway-monitor-hotplug.log`. The script logs the detected monitor identity and whether each setting came from the default, a profile, or an environment override.

### Clamshell Mode Setup (Important)
To use "clamshell mode" (using the laptop while the lid is closed with an external monitor), you must prevent `systemd-logind` from suspending the system when the lid is closed. The `monitor-hotplug.sh` script handles suspension logic itself.

Run the following to configure `logind`:

```bash
sudo mkdir -p /etc/systemd/logind.conf.d/
echo -e "[Login]\nHandleLidSwitch=ignore\nHandleLidSwitchExternalPower=ignore" | sudo tee /etc/systemd/logind.conf.d/sway-clamshell.conf
sudo systemctl restart systemd-logind
```

### Status Bar
Add a bar block to your sway config to execute the script. For vanilla swaybar:

```
bar {
    status_command exec ~/.config/sway/statusbar.sh
}
```

For Swayfx with its bar, the same `status_command` applies. Ensure the scripts are executable:

```
chmod +x ~/.config/sway/*.sh ~/.config/sway/status.d/*.sh
```

## Theme Toggle (Dark/Light Mode)

This configuration includes a theme toggle system that allows you to switch between dark and light themes:

**Features:**
- Toggle via keybind: `Mod+Shift+t` (Alt+Shift+t by default)
- Status bar indicator: 🌙 (dark) / ☀️ (light)
- Automatic Gnome integration: syncs with system theme when running under Gnome
- Standalone operation: works independently when not using Gnome
- Dynamic theming: updates bar colors, window borders, and workspace indicators
- Optional component theming: automatically switches themes for wofi (launcher), kitty (terminal), and mako (notifications) if installed

**Gnome Compatibility:**
When running under Gnome, the theme toggle automatically syncs with `gsettings` (org.gnome.desktop.interface color-scheme), ensuring consistent theming between Sway and Gnome applications. If Gnome is not detected, it operates as a Sway-only theme toggle.

**Manual Usage:**
```bash
# Toggle theme
~/.config/sway/scripts/toggle_theme.sh toggle

# Check current theme
~/.config/sway/scripts/toggle_theme.sh get
```

## Adding items via status.d/

Place any executable script in `~/.config/sway/status.d`. The script should:

- Print a single line to stdout (no trailing newlines required; they are trimmed)
- Exit 0 on success; errors are ignored so a failing script won't break the bar
- Be fast (ideally <10–20ms) to avoid jank; consider caching or async daemons for expensive queries

## Utility Scripts

The `scripts/` directory contains helper scripts that are bound to keys in the provided `config`.
See [`scripts/SCRIPTS.md`](scripts/SCRIPTS.md) for details on:
- `move-ws-to-active.sh`
- `move-ws-to-output.sh`
- `toggle-touchpad.sh`
- `monitor-hotplug.sh`
- `toggle_theme.sh`

## Floating Windows Configuration

By default, Sway tiles all windows. However, some applications (like calculators, dialogs, or system utilities) work better as floating windows. The `config.d/floating_windows` file contains rules to automatically make specific applications float.

Monitor hotplug configuration lives in `scripts/` alongside the script that uses it: `scripts/monitor-profiles.example.sh` is the template, and `scripts/monitor-profiles.local.sh` is the machine-local override (gitignored).

### Adding Your Own Floating Applications

1. Open the application you want to make floating
2. Find its identifier by running:
   ```bash
   swaymsg -t get_tree | grep -Po '"(app_id|class)": *"\K[^"]*'
   ```
3. Edit `~/.config/sway/config.d/floating_windows` and add a line:
   ```
   for_window [app_id="YOUR_APP_ID"] floating enable
   ```
4. Reload Sway config with `$mod+Shift+c`

The file includes commented examples for common applications (pavucontrol, file pickers, etc.) that you can uncomment as needed.

## Extra Configuration

The `extra/` directory contains supplementary configuration files.
See [`extra/EXTRA.md`](extra/EXTRA.md) for details.

## Troubleshooting

- Nothing shows for battery: ensure `upower` is installed and `upower -e` lists a `/org/freedesktop/UPower/devices/DisplayDevice`
- Missing icons: install a font that supports Nerd Fonts/Unicode glyphs (e.g. JetBrainsMono Nerd Font)
- Slow updates: ensure scripts in `status.d` are quick; avoid running heavy commands each second
- Bluetooth icon missing: ensure `bluez` is installed and `bluetoothctl` is working
- Clamshell mode not working: Check `/tmp/sway-monitor-hotplug.log` for errors and verify `HandleLidSwitch=ignore` is set in `logind.conf`.

## License

These scripts are provided as-is; adapt them freely to your setup.
