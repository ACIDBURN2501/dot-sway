# Extra configuration files

These files are not part of the main configuration, but are available for specific use cases.

## Wofi Application Launcher (Optional)

Location: `extra/wofi/`

**Optional Feature:** [Wofi](https://hg.sr.ht/~scoopta/wofi) is a lightweight application launcher/menu for Wayland, similar to dmenu or rofi.

### Installation

- Arch Linux: `sudo pacman -S wofi`
- Debian/Ubuntu: `sudo apt install wofi`
- Fedora: `sudo dnf install wofi`

### Configuration

Wofi is referenced in the main Sway config but is optional - the configuration will not break if it's not installed.

**Keybind:** `Mod+d` launches wofi (if installed)

### Setup for Theme Switching

No manual setup is required. The `toggle_theme.sh` script manages `~/.config/wofi/style.css` for you, pointing it straight at the active theme's source file in this repo (`extra/wofi/style-{dark,light}.css`). It runs on first toggle (`Mod+Shift+t`) and at Sway startup (`toggle_theme.sh init`).

If wofi ever launches in the wrong (or default) theme, re-apply the current one:

```bash
scripts/toggle_theme.sh init
```

### Theme Integration

Wofi integrates with the theme toggle system to automatically switch between dark and light themes:

**Theme Files:**
- `extra/wofi/style-dark.css` - Dark theme styling
- `extra/wofi/style-light.css` - Light theme styling
- `~/.config/wofi/style.css` - Symlink to the active theme (automatically managed)

**How it works:**
- When you toggle themes with `Mod+Shift+t`, wofi's theme automatically switches
- `toggle_theme.sh` symlinks `~/.config/wofi/style.css` to `extra/wofi/style-dark.css` or `extra/wofi/style-light.css` in this repo
- Because the symlink targets the repo source directly, there is no separate copy to keep in sync and no way to end up with a dangling `style.css`

### Customizing Wofi Themes

You can customize the appearance by editing the theme files:

```bash
# Edit dark theme
nano extra/wofi/style-dark.css

# Edit light theme
nano extra/wofi/style-light.css
```

**Key CSS elements:**
- `window` - Outer window appearance (border, background)
- `#input` - Search input field styling
- `#inner-box`, `#outer-box` - Container styling
- `#entry` - Individual menu item styling
- `#entry:selected` - Selected item styling

Changes take effect the next time wofi is launched.

### Power Menu

The `extra/wofi/wofi-power.sh` script provides a power menu using wofi with options to shutdown, reboot, suspend, hibernate, and logout. This script is independent of theme management but will use the active theme. Machines without suspend/hibernate support may trim the menu locally — the provisioner never overwrites local changes.

## Kitty Terminal Theme

Location: `extra/kitty/`

The theme toggle themes kitty with [Tokyo Night](https://github.com/folke/tokyonight.nvim) (by Folke Lemaitre — the files carry their own MIT license headers, and the full license text is in `themes/LICENSE`). `scripts/toggle_theme.sh` seeds a fresh box on first `init`:

- `themes/tokyo_night_moon.conf` / `themes/tokyo_night_day.conf` are copied into kitty's conventional theme directory, `~/.config/kitty/themes/` (a user-installed `tokyo_night_*.conf` there always wins).
- `kitty.conf` is copied to `~/.config/kitty/kitty.conf` **only if absent** — it carries the `include current-theme.conf` line and socket-based remote control for live `kitty @ set-colors`. A user-authored kitty.conf is never touched; if yours lacks the include, add it manually.

## Mako Notification Daemon (Optional)

Location: `extra/mako/`

**Optional Feature:** Desktop notifications via [mako](https://github.com/emersion/mako) notification daemon.

**Installation:**
- Arch Linux: `sudo pacman -S mako`
- Debian: `sudo apt install mako-notifier`

**How it works:**
- Mako is automatically started by Sway if installed (will gracefully skip if not available)
- Theme configurations are stored in `extra/mako/config-dark` and `extra/mako/config-light`
- Active config at `~/.config/mako/config` is automatically updated when toggling themes
- Notifications appear at top-center (Gnome-style)
- The configuration will not break if mako is not installed

**Features:**
- Gnome-style toast notifications at top center
- Automatically matches dark/light theme
- 5-second default timeout
- Grouped notifications by app

## swhkd Media Key Fallback (Optional)

Location: `extra/swhkd/swhkdrc`

**Optional Feature:** [`swhkd`](https://github.com/waycrate/swhkd) is a hotkey daemon that can catch media keys on some keyboards and laptops where Sway does not reliably bind separate `Consumer Control`, WMI, or vendor hotkey devices.

**When to use it:**
- `libinput debug-events --show-keycodes` sees the media keys
- `wev` does not show them or Sway bindings still do not fire
- You want a fallback only for media keys, not a replacement for normal Sway shortcuts

**Configuration:**
- The sample config in `extra/swhkd/swhkdrc` calls the same helper scripts used by the main Sway config
- Copy it to `~/.config/swhkd/swhkdrc`
- The sample's absolute paths point at the maintainer's home (`/home/ajl/...`). Since `swhkd` runs as root (whose `$HOME` is `/root`), adjust them to the real user's `~/.config/sway` on each host before starting the daemon
- Keep the config limited to media keys to avoid overlapping with your normal Sway bindings

**Startup:**

```bash
pkexec swhkd --config "$HOME/.config/swhkd/swhkdrc"
```

**Important:**
- Use absolute paths in the `swhkd` config because `pkexec` may not preserve your shell environment
- Only enable `swhkd` on affected machines, otherwise media keys may trigger twice
- Reload the daemon after config changes with `sudo pkill -HUP swhkd`
