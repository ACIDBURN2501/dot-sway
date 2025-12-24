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
- `statusbar.sh` — main loop that prints a single status line every second: `<Battery> | <Status Icons> | <Time>`
- `battery.sh` — reads UPower's DisplayDevice and prints a semicolon-delimited line: `icon;label;color;default`
- `power.sh` — tiny helper that converts `battery.sh` output into a compact human-readable string (used similarly to `batt_short` in `statusbar.sh`)
- `status.d/` — drop-in directory for status items. Included scripts:
    - `20-brightness.sh` — Displays brightness percentage (uses `brightnessctl`)
    - `30-volume.sh` — Displays volume level and mute status (uses `pactl`)
    - `80-bluetooth.sh` — Displays Bluetooth connection status
    - `90-net.sh` — Displays network status (WiFi/Ethernet)
- `scripts/` — Utility scripts for window management and system control.
    - `monitor-hotplug.sh` — **New!** Robustly handles monitor switching (internal vs. external) to avoid Kanshi race conditions.
    - See `scripts/SCRIPTS.md` for more details.
- `extra/` — Extra configuration files, such as `kanshi` config (see `extra/EXTRA.md`).

## Requirements

- Bash (for the scripts)
- `jq` (for JSON parsing in utility scripts)
- `swaymsg` (for interacting with Sway)
- UPower (for battery information)
- `brightnessctl` (for `status.d/20-brightness.sh`)
- `pactl` (PulseAudio/PipeWire for `status.d/30-volume.sh`)
- `bluez` / `bluetoothctl` (for `status.d/80-bluetooth.sh`)
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

## Adding items via status.d/

Place any executable script in `~/.config/sway/status.d`. The script should:

- Print a single line to stdout (no trailing newlines required; they are trimmed)
- Exit 0 on success; errors are ignored so a failing script won’t break the bar
- Be fast (ideally <10–20ms) to avoid jank; consider caching or async daemons for expensive queries

## Utility Scripts

The `scripts/` directory contains helper scripts that are bound to keys in the provided `config`.
See [`scripts/SCRIPTS.md`](scripts/SCRIPTS.md) for details on:
- `move-ws-to-active.sh`
- `move-ws-to-output.sh`
- `toggle-touchpad.sh`
- `monitor-hotplug.sh`

## Extra Configuration

The `extra/` directory contains supplementary configuration files.
See [`extra/EXTRA.md`](extra/EXTRA.md) for details.

## Troubleshooting

- Nothing shows for battery: ensure `upower` is installed and `upower -e` lists a `/org/freedesktop/UPower/devices/DisplayDevice`
- Missing icons: install a font that supports Nerd Fonts/Unicode glyphs (e.g. JetBrainsMono Nerd Font)
- Slow updates: ensure scripts in `status.d` are quick; avoid running heavy commands each second
- Bluetooth icon missing: ensure `bluez` is installed and `bluetoothctl` is working

## License

These scripts are provided as-is; adapt them freely to your setup.
