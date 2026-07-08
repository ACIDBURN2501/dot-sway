# Requirements

Dependencies follow a **probe-and-degrade** contract. This file *names* what each feature needs; it never hardcodes or force-installs. For any dependency you have three choices:

1. **Install it yourself** — everything is probed at runtime (`command -v`, `upower -e`, …), so the feature lights up automatically once the tool is present.
2. **Run the helper** — `scripts/setup-defaults.sh` configures the session/XDG defaults it can (terminal, MIME, portals) and *prints* the exact root commands for the packages it can't install for you. See [xdg-defaults.md](xdg-defaults.md).
3. **Skip it** — the feature degrades silently: missing hardware or tools produce no output and no errors (Waybar hides empty modules; scripts `exit 0`).

Only **Core** below is load-bearing; everything after it is opt-in.

## Core

- `sway` (or `swayfx`), `swaymsg`, `swaynag`
- `waybar` (≥ 0.9)
- `bash`, `jq`
- A Nerd Font (config uses `SauceCodePro Nerd Font`, `Symbols Nerd Font` fallback)

## Hardware integration

Used by Waybar modules and scripts:

- `upower` — battery
- `brightnessctl` — laptop backlight
- `ddcutil` — external monitor brightness (optional)
- `wpctl` (PipeWire) or `pactl` (PulseAudio) — audio; Waybar's `pulseaudio` module reads via libpulse, so either works as long as the socket is provided (PipeWire's `pipewire-pulse` daemon counts)
- `bluez` / `bluetoothctl` — bluetooth state and interactive control
- `iproute2` (`ip`) — read-only network inspection; Waybar's `network` module reads via netlink regardless of what manages the connection

## Click handlers

- **Audio** (left-click mute, scroll adjust) → `scripts/volume-control.sh`
- **Bluetooth** (left-click) → `scripts/bluetooth-tui.sh` — probes for [`bluetuith`](https://github.com/darkhz/bluetuith), falls back to `bluetoothctl`.
- **Network** (left-click) → `scripts/network-tui.sh` — probes `impala` → `nmtui` → `iwctl`, falls back to a read-only `ip` summary. Install [`impala`](https://github.com/pythops/impala) for the recommended iwd TUI.
- **Theme** / **DND** (left-click) → respective toggle scripts under `scripts/`

Prefer GUI tools? Swap the `on-click` lines in `waybar/config.jsonc`: `pavucontrol` (audio), `blueman-manager` (bluetooth), `nm-connection-editor` / `nmtui` (network).

## Theming integrations

Optional, picked up automatically when installed: `gsettings` (Gnome `color-scheme` sync), `wofi` (launcher), `kitty` (terminal), `mako` (notifications).

## Other

- `grim`, `slurp` — screenshots
- `swayidle`, `swaylock` — idle locking
- `wayland-pipewire-idle-inhibit` — holds an idle inhibitor while audio plays so videos don't trigger the lock. `cargo install wayland-pipewire-idle-inhibit` (needs `libpipewire-0.3-dev` and `libclang-dev` at build time); the binary must be on the Sway session's `PATH`.
- `dbus-update-activation-environment`, `systemctl --user import-environment` — XDG/Wayland env propagation. See [xdg-defaults.md](xdg-defaults.md).
