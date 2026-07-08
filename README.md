# Sway/Swayfx Desktop Configuration

A portable Sway (and Swayfx) configuration with **Waybar** as the status bar, a unified dark/light theme across bar, terminal, launcher, and notifications, and a monitor-hotplug daemon that handles clamshell mode and per-monitor profiles.

<p align="center">
  <img src="images/preview.png" alt="Desktop preview." />
</p>

## Layout

| Path | What it is |
|------|-----------|
| `config` | Primary Sway config. Includes `config.d/*`, `compose_key.local` (copy `compose_key.local.example`), and theme/SwayFX snippets generated under `/tmp`. |
| `config.d/` | Drop-in Sway snippets: `waybar` (launches the bar), `wallpaper` (bootstraps `images/wp.png`; rotate on demand with `$mod+Shift+w`), `floating_windows`. |
| `waybar/` | Status bar: `config.jsonc` layout, `style.css`, `colors-{dark,light}.css` palettes, custom `modules/`. |
| `scripts/` | Utilities bound to keybinds / `exec` lines. See [`scripts/SCRIPTS.md`](scripts/SCRIPTS.md). |
| `extra/` | Standalone configs for adjacent tools (kanshi, wofi, mako, swhkd). See [`extra/EXTRA.md`](extra/EXTRA.md). |
| `docs/` | Topic documentation (below). |

## Setup

```bash
git clone <this-repo> ~/.config/sway
sway -C                          # syntax-check the config
scripts/setup-defaults.sh        # terminal, MIME, and portal defaults (see docs)
```

Log into the Sway session; `config.d/waybar` and the theme/monitor hooks start automatically. See [docs/requirements.md](docs/requirements.md) for dependencies.

## Documentation

| Doc | Topic |
|-----|-------|
| [requirements.md](docs/requirements.md) | Dependencies and optional integrations |
| [xdg-defaults.md](docs/xdg-defaults.md) | Default terminal, MIME associations, desktop portals |
| [status-bar.md](docs/status-bar.md) | Waybar layout, adding modules, theming |
| [theming.md](docs/theming.md) | Dark/light toggle, wallpaper rotation |
| [hardware.md](docs/hardware.md) | Media keys, monitor hotplug, clamshell, floating windows |
| [troubleshooting.md](docs/troubleshooting.md) | Symptom → check table |

Contributor conventions live in [`AGENTS.md`](AGENTS.md).
