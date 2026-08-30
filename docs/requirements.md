# Requirements

**What:** The dependency contract (probe-and-degrade) — what each feature needs, and the three ways to satisfy it.
**Where:** this page; the installable truth is the `bootstrap/packages/*.txt` manifests.
**Verified:** the manifests are checked against reference installs; at runtime, features light up as their tools appear.

Dependencies follow a **probe-and-degrade** contract. This file *names* what each feature needs; it never hardcodes or force-installs. For any dependency you have three choices:

1. **Install it yourself** — everything is probed at runtime (`command -v`, `upower -e`, …), so the feature lights up automatically once the tool is present.
2. **Run the helper** — `scripts/setup-defaults.sh` configures the session/XDG defaults it can (terminal, MIME, portals) and *prints* the exact root commands for the packages it can't install for you. See [xdg-defaults.md](xdg-defaults.md).
3. **Skip it** — the feature degrades silently: missing hardware or tools produce no output and no errors (Waybar hides empty modules; scripts `exit 0`).

Only **Core** below is load-bearing; everything after it is opt-in.

## Package names (Debian 13)

A few names differ from the Arch world:

| Tool | Debian 13 package |
|------|-------------------|
| mako | `mako-notifier` (provides `mako`, `makoctl`) |
| wpctl | `wireplumber` (ships `wpctl`) |
| swaynag | bundled in `sway` |
| rage | not packaged — decrypting secrets only needs `age`; encrypt on an Arch box |

`bootstrap/packages/debian.txt` is the verified manifest (checked on a trixie reference install).

## Core

- `sway` (or `swayfx`), `swaymsg`, `swaynag`
- `waybar` (≥ 0.9)
- `swayidle`, `swaylock` — idle lock and screen-off (`config.d/idle` via `scripts/idle-manager.sh`) and the `$super+l` lock keybind
- `bash`, `jq`
- A Nerd Font (config uses `SauceCodePro Nerd Font`, `Symbols Nerd Font` fallback)

## Hardware integration

Used by Waybar modules and scripts:

- `upower` — battery state for the Waybar module, and power transitions for `scripts/power-events.sh` (battery low / fully charged / AC plugged / unplugged → notification + hook, see `docs/hooks.md`)
- `brightnessctl` — laptop backlight
- `ddcutil` — external monitor brightness (optional)
- `wpctl` (PipeWire) or `pactl` (PulseAudio) — audio; Waybar's `pulseaudio` module reads via libpulse, so either works as long as the socket is provided (PipeWire's `pipewire-pulse` daemon counts)
- `bluez` / `bluetoothctl` — bluetooth state and interactive control
- `playerctl` — MPRIS transport (play/pause/next/previous keys) and the track readout for Waybar's `mpris` module. Waybar must be built against libplayerctl (both distro packages are).
- `wob` — transient OSD bar for volume/brightness changes; fed by the control scripts via `scripts/osd-bar.sh`, silently skipped when absent. Config in `extra/wob/wob.ini`.
- `iproute2` (`ip`) — read-only network inspection; Waybar's `network` module reads via netlink regardless of what manages the connection

## Click handlers

- **Audio** (left-click dropdown: mutes and a devices item; right-click mute; scroll adjust) → `waybar/menus/audio.xml` (native Waybar menu) + `scripts/volume-control.sh`; the devices item delegates to `scripts/quick-menu.sh audio` (also `$super+Ctrl+a`)
- **Media (MPRIS)** (left-click dropdown: transport controls; middle previous, right next) → `waybar/menus/mpris.xml` (native Waybar menu, `playerctl`) + the module's built-in middle/right actions
- **Bluetooth** (left-click quick menu: connect/disconnect and radio; right-click radio toggle) → `scripts/quick-menu.sh bluetooth` + `scripts/toggle-bluetooth.sh`. Pairing stays in the TUI (left-click menu → pair entry).
- **Network** (left-click quick menu: scan, saved networks, masked password entry; right-click TUI) → `scripts/quick-menu.sh network` + `scripts/network-tui.sh` — the TUI probes `impala` → `nmtui` → `iwctl`, falls back to a read-only `ip` summary. Install [`impala`](https://github.com/pythops/impala) for the recommended iwd TUI.
- **Power** (`Super+Ctrl+p`, or the power pill ⏻'s left-click dropdown) → `scripts/quick-menu.sh power` → `extra/wofi/wofi-power.sh`; the dropdown is `waybar/menus/power.xml`, a parallel definition of `wofi-power.sh` — keep the commands in sync
- **Theme** / **DND** (left-click) → respective toggle scripts under `scripts/`

Prefer GUI tools? Swap the `on-click` lines in `waybar/config.jsonc`: `pavucontrol` (audio), `blueman-manager` (bluetooth), `nm-connection-editor` / `nmtui` (network).

## Theming integrations

Optional, picked up automatically when installed: `gsettings` (Gnome `color-scheme` sync), `wofi` (launcher), `kitty` (terminal), `mako` (notifications).

## Other

- `grim`, `slurp` — screenshots
- `wl-clipboard` (`wl-copy`) — puts each screenshot on the clipboard as well as on disk. Without it captures still save, they just aren't pastable. A clipboard *history* needs a manager on top ([`cliphist`](https://github.com/sentriz/cliphist), `clipman`); neither is wired up here.
- `wayland-pipewire-idle-inhibit` — holds an idle inhibitor while audio plays so videos don't trigger the idle lock. `cargo install wayland-pipewire-idle-inhibit` (needs `libpipewire-0.3-dev` and `libclang-dev` at build time); the binary must be on the Sway session's `PATH`.
- `dbus-update-activation-environment`, `systemctl --user import-environment` — XDG/Wayland env propagation. See [xdg-defaults.md](xdg-defaults.md).
