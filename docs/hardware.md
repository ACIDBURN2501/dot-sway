# Hardware integration

**What:** Media keys, monitor hotplug (including clamshell), and per-app floating windows.
**Where:** keybindings in `config`; `scripts/` (volume, brightness, monitor-hotplug); `config.d/floating_windows`; the `extra/swhkd/` fallback for odd keyboards.
**Verified:** the per-distro rows in [core-features.md](core-features.md); per-machine hotplug behaviour is logged in `$XDG_RUNTIME_DIR/sway/monitor-hotplug.log`.

## Media keys

Bound with both `bindsym` (`XF86…` keysyms) and `bindcode` (raw Linux input codes) so they work across built-in, external USB, and separate-consumer-control keyboards.

- `scripts/volume-control.sh` handles mute, volume, and mic mute (the fallback chain is in the matrix).
- `scripts/brightness-control.sh` handles the laptop backlight; `external-brightness.sh` handles external monitors (the matrix row has the tooling).

| Code | Key |
|------|-----|
| `121` | `KEY_MUTE` |
| `122` | `KEY_VOLUMEDOWN` |
| `123` | `KEY_VOLUMEUP` |
| `232` | `KEY_BRIGHTNESSDOWN` |
| `233` | `KEY_BRIGHTNESSUP` |
| `256` | `KEY_MICMUTE` |

### `swhkd` fallback

On keyboards that expose media keys through a separate hotkey device Sway doesn't bind reliably, run `swhkd` alongside Sway:

```bash
pkexec swhkd --config "$HOME/.config/swhkd/swhkdrc"
```

Render `extra/swhkd/swhkdrc` to `~/.config/swhkd/swhkdrc` (substitute your home for `__SWAY_HOME__`; `install.sh` does this when `swhkd` is present) and keep it scoped to media keys only; otherwise Sway and swhkd both fire on the same press.

## Monitor hotplug

`scripts/monitor-hotplug.sh` auto-detects the internal display (first `eDP-*` output) and any external. External settings resolve in this order:

1. `DOTSWAY_EXT_*` environment variables (session env).
2. `host.env` at the repo root (copy `host.env.example`), the same `DOTSWAY_EXT_*` names.
3. Per-monitor matches from `scripts/monitor-profiles.local.sh`.
4. Fallback: `1920x1080@60Hz`, scale `1`, adaptive sync `off`.

Per-monitor setup:

1. Copy `scripts/monitor-profiles.example.sh` → `scripts/monitor-profiles.local.sh` (gitignored).
2. Capture identity values:
   ```bash
   swaymsg -t get_outputs -r | jq -r '.[] | select(.name | startswith("eDP") | not) | [.name, .make, .model, .serial] | @tsv'
   ```
3. Add a `case` entry calling `set_monitor_profile MODE SCALE ADAPTIVE_SYNC`.
4. `swaymsg reload` and `scripts/monitor-hotplug.sh --once` to apply.
5. If a profile doesn't apply, check `$XDG_RUNTIME_DIR/sway/monitor-hotplug.log`.

Match on `serial` for a specific unit; leave it empty to share a profile across every unit of the same make/model.

| Variable | Default | Description |
|----------|---------|-------------|
| `DOTSWAY_EXT_RES` | `1920x1080@60Hz` | Forced mode (e.g. `3840x2160@120Hz`). Overrides any profile. |
| `DOTSWAY_EXT_SCALE` | `1` | Output scale (e.g. `1.25` for 4K). |
| `DOTSWAY_EXT_ADAPTIVE_SYNC` | `off` | Adaptive sync (`on`/`off`). |
| `DOTSWAY_INTERNAL_OUTPUT` | *(auto)* | Force a specific internal output name. |
| `DOTSWAY_MONITOR_PROFILES_FILE` | `scripts/monitor-profiles.local.sh` | Alternate overrides path. |

Any of the `DOTSWAY_EXT_*` / `DOTSWAY_INTERNAL_OUTPUT` rows can be set in `host.env` instead of the environment; a non-empty environment variable still wins. The daemon is `exec_always`, so `swaymsg reload` re-reads `host.env`.

### Clamshell mode

For clamshell (lid closed, external only), stop `systemd-logind` from suspending; `monitor-hotplug.sh` decides suspend behavior itself:

```bash
sudo mkdir -p /etc/systemd/logind.conf.d/
printf '[Login]\nHandleLidSwitch=ignore\nHandleLidSwitchExternalPower=ignore\n' \
  | sudo tee /etc/systemd/logind.conf.d/sway-clamshell.conf
sudo systemctl restart systemd-logind
```

## Floating windows

`config.d/floating_windows` makes specific apps open floating. To add one:

1. Find its identifier:
   ```bash
   swaymsg -t get_tree | grep -Po '"(app_id|class)": *"\K[^"]*'
   ```
2. Add `for_window [app_id="YOUR_APP_ID"] floating enable`.
3. Reload with `$mod+Shift+c`.

The file ships with commented examples (pavucontrol, file pickers, etc.).
