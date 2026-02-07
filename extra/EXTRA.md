# Extra configuration files

These files are not part of the main configuration, but are available for specific use cases.

## Wofi Themes (Reference Only)

Location: `extra/wofi/`

**Note:** Wofi themes are now actively managed by the theme toggle system at `~/.config/wofi/`. The files in `extra/wofi/` are kept as reference only.

**Active Theme System:**
- `~/.config/wofi/style-dark.css` - Dark theme
- `~/.config/wofi/style-light.css` - Light theme
- `~/.config/wofi/style.css` - Symlink to active theme (automatically switched by `toggle_theme.sh`)

The theme automatically switches when you toggle between dark/light mode (Mod+Shift+t).

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

## Kanshi (Deprecated)

Location: `extra/kanshi/config`

Previously, [Kanshi](https://github.com/emersion/kanshi) was used for managing display profiles. However, it was found to have consistency issues (race conditions) when hotplugging Thunderbolt docks.

**Current Recommendation:**
We have moved to a script-based approach (`scripts/monitor-hotplug.sh`) which is triggered by Sway events. This provides a more robust, macOS-like experience where plugging in an external monitor automatically:
1. Enables the external monitor
2. Moves all workspaces to it
3. Disables the internal laptop display

If you prefer complex multi-monitor setups (e.g. extending desktops rather than switching), you may want to disable the hotplug script in `config` and revert to using Kanshi.
