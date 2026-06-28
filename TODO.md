# TODO

## Goal

Prevent theme toggles from changing the wallpaper by removing the Sway reload path that re-runs wallpaper rotation.

## Tasks

### 1. Confirm the dependency chain

- [ ] Verify which command in `scripts/toggle_theme.sh` triggers a Sway reload.
- [ ] Verify which config snippet re-runs wallpaper rotation during Sway reload.
- [ ] Record any Sway-only theme effects that currently depend on reload (for example window border colors from `/tmp/sway_theme_config`).

### 2. Change theme toggle behavior

- [ ] Update `scripts/toggle_theme.sh` so `toggle` does not call `swaymsg reload`.
- [ ] Keep the existing non-Sway theme updates intact (`waybar`, `wofi`, `kitty`, `mako`, and theme state files).
- [ ] Preserve startup `init` behavior so current theme bootstrap still works on login.

### 3. Document the new behavior

- [ ] Update relevant comments or docs to note that theme toggling no longer reloads Sway and therefore no longer rotates wallpaper.
- [ ] Note any remaining limitation that Sway-native colors may not update until a manual `reload` or a new login, if applicable.

## Notes

- The wallpaper changes today because `scripts/toggle_theme.sh` runs `swaymsg reload`, which re-executes `config.d/wallpaper`, which runs `scripts/rotate-wallpaper.sh`.
- In this config, the Sway-native theme values are generated into `/tmp/sway_theme_config` and loaded by Sway on config parse. If we stop reloading Sway during theme toggle, those values may not visibly update immediately.
- Based on the current config, the most likely Sway-native visual difference is window border/client colors rather than Waybar colors.
