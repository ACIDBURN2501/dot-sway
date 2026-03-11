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

To enable automatic theme switching for wofi, copy the provided theme templates to your wofi config directory:

```bash
# Create wofi config directory if it doesn't exist
mkdir -p ~/.config/wofi

# Copy theme templates from the repository
cp ~/.config/sway/extra/wofi/style-dark.css ~/.config/wofi/
cp ~/.config/sway/extra/wofi/style-light.css ~/.config/wofi/
```

The `toggle_theme.sh` script will automatically create the `style.css` symlink when you first toggle themes or run `toggle_theme.sh init`.

**Note:** Without these files, wofi will still work but won't switch themes automatically.

### Theme Integration

Wofi integrates with the theme toggle system to automatically switch between dark and light themes:

**Theme Files:**
- `~/.config/wofi/style-dark.css` - Dark theme styling
- `~/.config/wofi/style-light.css` - Light theme styling
- `~/.config/wofi/style.css` - Symlink to active theme (automatically managed)

**How it works:**
- When you toggle themes with `Mod+Shift+t`, wofi's theme automatically switches
- The `toggle_theme.sh` script creates a symlink from `style.css` to either `style-dark.css` or `style-light.css`
- Both theme files must exist for theme switching to work properly

**Template Files:**
- `extra/wofi/style-dark.css` - Dark theme template
- `extra/wofi/style-light.css` - Light theme template
- `extra/wofi/style.css` - Legacy reference (kept for backward compatibility)

These templates should be copied to `~/.config/wofi/` (see Setup section above).

### Customizing Wofi Themes

You can customize the appearance by editing the theme files:

```bash
# Edit dark theme
nano ~/.config/wofi/style-dark.css

# Edit light theme
nano ~/.config/wofi/style-light.css
```

**Key CSS elements:**
- `window` - Outer window appearance (border, background)
- `#input` - Search input field styling
- `#inner-box`, `#outer-box` - Container styling
- `#entry` - Individual menu item styling
- `#entry:selected` - Selected item styling

Changes take effect the next time wofi is launched.

### Power Menu

The `extra/wofi/wofi-power.sh` script provides a power menu using wofi with options to lock, logout, suspend, reboot, and shutdown. This script is independent of theme management but will use the active theme.

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

**Optional Feature:** [`swhkd`](https://github.com/waycrate/swhkd) is a hotkey
daemon that can catch media keys on some keyboards and laptops where Sway does
not reliably bind separate `Consumer Control`, WMI, or vendor hotkey devices.

**When to use it:**
- `libinput debug-events --show-keycodes` sees the media keys
- `wev` does not show them or Sway bindings still do not fire
- You want a fallback only for media keys, not a replacement for normal Sway shortcuts

**Configuration:**
- The sample config in `extra/swhkd/swhkdrc` calls the same helper scripts used by the main Sway config
- Copy it to `~/.config/swhkd/swhkdrc`
- Keep the config limited to media keys to avoid overlapping with your normal Sway bindings

**Startup:**

```bash
swhks &
pkexec swhkd --config "$HOME/.config/swhkd/swhkdrc"
```

**Important:**
- Use absolute paths in the `swhkd` config because `pkexec` may not preserve your shell environment
- Only enable `swhkd` on affected machines, otherwise media keys may trigger twice
- Reload the daemon after config changes with `sudo pkill -HUP swhkd`

## Kanshi (Deprecated)

Location: `extra/kanshi/config`

Previously, [Kanshi](https://github.com/emersion/kanshi) was used for managing display profiles. However, it was found to have consistency issues (race conditions) when hotplugging Thunderbolt docks.

**Current Recommendation:**
We have moved to a script-based approach (`scripts/monitor-hotplug.sh`) which is triggered by Sway events. This provides a more robust, macOS-like experience where plugging in an external monitor automatically:
1. Enables the external monitor
2. Moves all workspaces to it
3. Disables the internal laptop display

If you prefer complex multi-monitor setups (e.g. extending desktops rather than switching), you may want to disable the hotplug script in `config` and revert to using Kanshi.
