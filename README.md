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
- `pactl` (PulseAudio/PipeWire for `status.d/30-volume.sh`)
- `bluez` / `bluetoothctl` (for `status.d/80-bluetooth.sh`)
- `gsettings` (optional, for Gnome theme syncing)
- `mako` (optional, for desktop notifications)
- `grim` (for screenshots)
- `slurp` (for interactive region selection in screenshots)
- `systemctl` (for system suspension and environment management)
- `dbus-update-activation-environment` (for environment variable management)
- Optional: `swayidle`, `swaylock`, `wmenu`/`wofi`/`tofi` (referenced in `config`)

## How it works

1. `statusbar.sh` loops once per second
2. It calls `battery.sh` (if present and executable) and compresses that into a short left section (e.g. `󱟞 4h 12m`, `󱟠 1h 05m`, or `🔌` when full)
3. It executes each executable file in `~/.config/sway/status.d` (in lexical order) and concatenates their outputs with spaces for the center section
4. It appends the current time as the right section
5. Only non-empty sections are printed; sections are separated by ` | `

## Using with Sway/Swayfx

### Configuration
A default configuration is provided in the `config` file. To use it:

```bash
cp ~/.config/sway/config ~/.config/sway/config.backup
cp ~/.config/sway/config ~/.config/sway/config
```

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
