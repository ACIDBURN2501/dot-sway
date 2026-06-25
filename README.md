# Sway/Swayfx Desktop Configuration

A portable Sway (and Swayfx) configuration with **Waybar** as the desktop status bar, a unified dark/light theme toggle across the bar, terminal, launcher, and notifications, and a monitor-hotplug daemon that handles clamshell mode and per-monitor profiles.

<p align="center">
  <img src="images/preview.png" alt="Desktop preview." />
</p>

## Files

- `config` — Sway configuration. Sources `/tmp/swayfx_config_snippet` (SwayFX-only settings, generated on launch by `scripts/swayfx_guard.sh`) and `/tmp/sway_theme_config` (active theme palette).
- `config.d/` — Drop-in directory; sourced via `include config.d/*`.
    - `waybar` — Launches Waybar, bootstrapping the active palette symlink.
    - `wallpaper` — Re-rolls the desktop wallpaper on each reload. See [Wallpaper Rotation](#wallpaper-rotation).
    - `floating_windows` — Per-application floating rules. See [Floating Windows](#floating-windows).
    - `compose_key` — Compose-key bindings.
- `waybar/` — Status bar configuration.
    - `config.jsonc` — Module layout.
    - `style.css` — Visual style; imports the active palette via `colors.css`.
    - `colors-dark.css`, `colors-light.css` — Palettes (Tokyo Night Moon/Day), harmonised with the kitty themes.
    - `colors.css` — Symlink (gitignored) to the active palette, managed by `scripts/toggle_theme.sh`.
    - `modules/` — Custom shell modules for state Waybar can't read natively:
        - `brightness.sh` — Laptop backlight via `brightnessctl`; falls back to external monitors via a `ddcutil` cache.
        - `theme.sh` — Current theme indicator (🌙 / ☀️).
        - `dnd.sh` — Mako DND indicator (🧘 when active).
- `scripts/` — Utility scripts bound to keys in `config`. See [`scripts/SCRIPTS.md`](scripts/SCRIPTS.md).
- `images/` — Visual assets.
    - `wallpapers/` — Pool of source images for `rotate-wallpaper.sh`. Drop `.png/.jpg/.jpeg` files in; the folder itself is tracked via `.gitkeep`, contents are gitignored.
    - `wp.png` — Symlink to the active wallpaper (gitignored). Managed by `scripts/rotate-wallpaper.sh`; consumed by `output * bg` and swaylock.
    - `preview.png` — Repo screenshot for the README header.
- `extra/` — Supplementary configs (kanshi, wofi, mako, swhkd). See [`extra/EXTRA.md`](extra/EXTRA.md).

## Requirements

Core:

- `sway` (or `swayfx`), `swaymsg`, `swaynag`
- `waybar` (≥ 0.9)
- `bash`, `jq`
- A Nerd Font (the config uses `SauceCodePro Nerd Font`, with `Symbols Nerd Font` as fallback)

Hardware integration (used by Waybar modules and scripts):

- `upower` — battery
- `brightnessctl` — laptop backlight
- `ddcutil` — external monitor brightness (optional)
- `wpctl` (PipeWire) or `pactl` (PulseAudio) — audio control; Waybar's `pulseaudio` module reads via libpulse, so either works as long as the socket is provided (PipeWire's `pipewire-pulse` daemon counts)
- `bluez` / `bluetoothctl` — bluetooth state and interactive control
- `iproute2` (provides `ip`) — read-only network inspection; Waybar's `network` module reads via netlink and works regardless of what's managing the connection (dhcpcd, systemd-networkd, NetworkManager, etc.)

Click handlers:

- **Audio** (left-click mute, scroll to adjust) → `scripts/volume-control.sh`
- **Bluetooth** (left-click) → `scripts/bluetooth-tui.sh` — probes for [`bluetuith`](https://github.com/darkhz/bluetuith), falls back to `bluetoothctl`'s interactive shell.
- **Network** (left-click) → `scripts/network-tui.sh` — probes for `impala` → `nmtui` → `iwctl`, falls back to a read-only `ip` interface + routes summary if none are installed. Install [`impala`](https://github.com/pythops/impala) for the recommended iwd TUI.
- **Theme** / **DND** (left-click) → respective toggle scripts under `scripts/`

If you prefer GUI tools, swap the `on-click` lines in `waybar/config.jsonc`: `pavucontrol` for audio, `blueman-manager` for bluetooth, `nm-connection-editor` or `nmtui` for network.

Theming integrations (optional, picked up automatically when installed):

- `gsettings` — Gnome `color-scheme` sync
- `wofi` — application launcher
- `kitty` — terminal
- `mako` — notification daemon

Other:

- `grim`, `slurp` — screenshots
- `swayidle`, `swaylock` — idle locking
- `wayland-pipewire-idle-inhibit` — holds an idle inhibitor while audio is playing so videos don't trigger the lock. Install with `cargo install wayland-pipewire-idle-inhibit` (needs `libpipewire-0.3-dev` and `libclang-dev` at build time); the binary must be on the sway session's `PATH`.
- `dbus-update-activation-environment`, `systemctl --user import-environment` — XDG/Wayland env propagation

## Status Bar

Waybar is launched by `config.d/waybar` on every Sway reload. The snippet:

1. Reads `.theme_state` and points `waybar/colors.css` at the matching palette.
2. Kills any prior Waybar instance.
3. Launches Waybar with this repo's `config.jsonc` and `style.css`.

### Layout

| Cluster | Modules                                                                  |
|---------|--------------------------------------------------------------------------|
| Left    | `sway/workspaces`, `sway/mode`, `battery`                                |
| Center  | `custom/brightness`, `pulseaudio`, `custom/theme`, `custom/dnd`, `bluetooth`, `network` |
| Right   | `tray`, `clock`                                                          |

Battery, audio, bluetooth, network, and clock use Waybar's native event-driven modules (D-Bus, no polling). Brightness, theme, and DND are custom shell modules — see `waybar/modules/`.

### Adding modules

- **Native module:** add its name to a `modules-*` array in `config.jsonc` and a config block below. See the [Waybar wiki](https://github.com/Alexays/Waybar/wiki) for the catalogue.
- **Custom shell module:** drop an executable script in `waybar/modules/`, then add `"custom/<name>"` to a cluster with `"exec": "$HOME/.config/sway/waybar/modules/<script>.sh"`, an `"interval"`, and an optional `"on-click"`. For state-dependent styling, emit JSON (`{text, tooltip, class, percentage}`) and set `"return-type": "json"` — `style.css` can then target `#custom-<name>.<class>`.

### Theming

Edit `waybar/colors-dark.css` and `waybar/colors-light.css` — both must define the same `@define-color` names so `style.css` resolves in either palette. The toggle script (`scripts/toggle_theme.sh`) swaps the `colors.css` symlink and sends `SIGUSR2` so Waybar re-renders in place. Don't put colors in `style.css` directly; use the semantic tokens (`@bg`, `@fg`, `@accent`, `@warning`, etc.).

## Theme Toggle (Dark/Light)

A single keybind (`Mod+Shift+t`) flips Sway, Waybar, kitty, wofi, mako, and (when running under Gnome) Gnome's `color-scheme` between dark and light. The script lives at `scripts/toggle_theme.sh` and runs `init` at Sway startup to bootstrap all components.

- **Status indicator:** 🌙 dark / ☀️ light (`waybar/modules/theme.sh`).
- **Gnome sync:** when `gsettings` reports `org.gnome.desktop.interface color-scheme`, that is the source of truth; otherwise `.theme_state` is.
- **Live Waybar repaint:** symlink swap + `SIGUSR2` — no restart.

Manual usage:

```bash
~/.config/sway/scripts/toggle_theme.sh toggle   # flip
~/.config/sway/scripts/toggle_theme.sh init     # re-apply current theme to all components
~/.config/sway/scripts/toggle_theme.sh get      # print "dark" or "light"
```

## Wallpaper Rotation

`config.d/wallpaper` runs `scripts/rotate-wallpaper.sh` on each Sway start/reload. The script:

1. Scans `images/wallpapers/` for `.png`, `.jpg`, and `.jpeg` files (case-insensitive).
2. Picks one uniformly at random.
3. Repoints the `images/wp.png` symlink at the pick.
4. Applies it live with `swaymsg output * bg images/wp.png fill` so the change is visible immediately, not just after the next reload.

Because everything that references the wallpaper (`output * bg`, the swaylock keybind, and the swayidle `before-sleep` hook) reads `images/wp.png`, the lock screen and idle blur follow the same rotation automatically.

### Usage

```bash
# Add wallpapers
cp ~/Pictures/*.jpg ~/.config/sway/images/wallpapers/

# Roll a new one (any of the below)
$mod+Shift+c                                    # reload Sway — fires the exec_always hook
~/.config/sway/scripts/rotate-wallpaper.sh      # run the script directly
```

An empty `images/wallpapers/` folder is a no-op — the current `wp.png` symlink is left untouched, so you can disable rotation by emptying the folder without breaking anything.

### Cold-boot note

On a fresh login Sway parses `output * bg` before `exec_always` fires, so the boot wallpaper is whatever `wp.png` pointed at when you last shut down. The rotation script then runs and applies the new pick live — expect a sub-second flash of the previous wallpaper before it changes.

## Media Keys

Media keys are bound with both `bindsym` (for `XF86...` keysyms) and `bindcode` (for raw Linux input codes), so they work across built-in laptop keyboards, external USB keyboards, and keyboards that expose volume keys through a separate Consumer Control device.

- `scripts/volume-control.sh` prefers `wpctl`, falls back to `pactl`.
- `scripts/brightness-control.sh` uses `brightnessctl` on backlight-bearing hardware, with a `ddcutil` cache for external monitors.

Input codes used:

| Code  | Key                       |
|-------|---------------------------|
| `121` | `KEY_MUTE`                |
| `122` | `KEY_VOLUMEDOWN`          |
| `123` | `KEY_VOLUMEUP`            |
| `232` | `KEY_BRIGHTNESSDOWN`      |
| `233` | `KEY_BRIGHTNESSUP`        |
| `256` | `KEY_MICMUTE`             |

### `swhkd` fallback

On keyboards that expose media keys through a separate hotkey device Sway doesn't bind reliably, run `swhkd` alongside Sway:

```bash
swhks &
pkexec swhkd --config "$HOME/.config/swhkd/swhkdrc"
```

Copy `extra/swhkd/swhkdrc` to `~/.config/swhkd/swhkdrc` and keep it scoped to media keys only — otherwise Sway and swhkd will both fire on the same press.

## Monitor Hotplug

`scripts/monitor-hotplug.sh` auto-detects the internal display (first `eDP-*` output) and any connected external display. External monitor settings resolve in this order:

1. `DOTSWAY_EXT_*` environment variables.
2. Per-monitor matches from `~/.config/sway/scripts/monitor-profiles.local.sh`.
3. Universal fallback: `1920x1080@60Hz`, scale `1`, adaptive sync `off`.

Per-monitor setup:

1. Copy `scripts/monitor-profiles.example.sh` → `scripts/monitor-profiles.local.sh` (gitignored).
2. `swaymsg -t get_outputs -r | jq -r '.[] | select(.name | startswith("eDP") | not) | [.name, .make, .model, .serial] | @tsv'` to capture identity values.
3. Add a `case` entry in `monitor-profiles.local.sh` that calls `set_monitor_profile MODE SCALE ADAPTIVE_SYNC`.
4. `swaymsg reload` and `scripts/monitor-hotplug.sh --once` to apply immediately.
5. If a profile doesn't apply, check `/tmp/sway-monitor-hotplug.log` — every decision is logged.

Match on `serial` for a specific physical display, leave it empty to share a profile across every unit of the same make/model.

Environment variables:

| Variable                          | Default                                              | Description                                                                |
|-----------------------------------|------------------------------------------------------|----------------------------------------------------------------------------|
| `DOTSWAY_EXT_RES`                 | `1920x1080@60Hz`                                     | Forced mode string (e.g. `3840x2160@120Hz`). Overrides any profile match.  |
| `DOTSWAY_EXT_SCALE`               | `1`                                                  | Output scale factor (e.g. `1.25` for 4K).                                  |
| `DOTSWAY_EXT_ADAPTIVE_SYNC`       | `off`                                                | Adaptive sync (`on`/`off`).                                                |
| `DOTSWAY_INTERNAL_OUTPUT`         | *(auto)*                                             | Force a specific internal output name (e.g. `eDP-1`).                      |
| `DOTSWAY_MONITOR_PROFILES_FILE`   | `~/.config/sway/scripts/monitor-profiles.local.sh`   | Alternate path for the per-monitor overrides file.                         |

### Clamshell mode

For clamshell mode (laptop closed, external monitor only), prevent `systemd-logind` from suspending the system — `monitor-hotplug.sh` decides suspend behavior itself:

```bash
sudo mkdir -p /etc/systemd/logind.conf.d/
echo -e "[Login]\nHandleLidSwitch=ignore\nHandleLidSwitchExternalPower=ignore" \
  | sudo tee /etc/systemd/logind.conf.d/sway-clamshell.conf
sudo systemctl restart systemd-logind
```

## Floating Windows

`config.d/floating_windows` makes specific applications open as floating windows (calculators, dialogs, etc.). To add an application:

1. Open it and find its identifier:
   ```bash
   swaymsg -t get_tree | grep -Po '"(app_id|class)": *"\K[^"]*'
   ```
2. Add a line:
   ```
   for_window [app_id="YOUR_APP_ID"] floating enable
   ```
3. Reload with `$mod+Shift+c`.

The file ships with commented examples (pavucontrol, file pickers, etc.).

## Extras

`extra/` contains supplementary configurations — see [`extra/EXTRA.md`](extra/EXTRA.md).

## Troubleshooting

| Symptom                                         | Check                                                                                       |
|-------------------------------------------------|---------------------------------------------------------------------------------------------|
| No bar at all                                   | `pgrep waybar`; if empty, run `waybar -c waybar/config.jsonc -s waybar/style.css` and inspect stderr |
| CSS parse error on launch                       | `waybar/colors.css` symlink missing — run `scripts/toggle_theme.sh init`                    |
| Theme indicator stuck                           | Check `.theme_state` and `gsettings get org.gnome.desktop.interface color-scheme`           |
| Battery missing                                 | `upower -e` must list `/org/freedesktop/UPower/devices/DisplayDevice`                       |
| Missing glyphs                                  | Install a Nerd Font (the config asks for `SauceCodePro Nerd Font`)                          |
| Bluetooth icon stuck off                        | `bluez` running? `rfkill list bluetooth` shows the controller?                              |
| Clamshell mode suspends unexpectedly            | `/tmp/sway-monitor-hotplug.log` + verify `HandleLidSwitch=ignore` in `/etc/systemd/logind.conf.d/` |
| Monitor profile not applied                     | `/tmp/sway-monitor-hotplug.log` logs the detected identity and which source set each value  |
| Wallpaper doesn't rotate on reload              | `images/wallpapers/` exists with at least one `.png/.jpg/.jpeg`? Run `scripts/rotate-wallpaper.sh` directly and check `readlink images/wp.png` |

## License

Provided as-is; adapt freely.
