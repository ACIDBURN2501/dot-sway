# The Sway Config

**What:** The core compositor configuration — keybindings, workspace rules, and the startup hooks that launch the bar, theme, and monitor daemons.
**Where:** `config` (the main file), `config.d/` (drop-in snippets), and gitignored `*.local` overlays for per-machine drift.
**Verified:** `sway -C` in CI (headless backend, no session needed); the theme pipeline additionally runs `tests/theme-sandbox.sh`.

## Layering

Sway reads the layers in this order, each one able to extend the last:

1. **`config`** — the main file: variables, keybindings, input rules, and the startup `exec` lines (theme init, monitor-hotplug daemon, mako if installed, ssh-agent socket export).
2. **`include ~/.config/sway/config.d/*`** — drop-in snippets, one concern each:
   - `waybar` — launches and supervises the bar (respawn capped at 5 attempts; `exec`, not `exec_always`, so reloads don't kill it).
   - `wallpaper` — bootstraps `images/wp.png` via `rotate-wallpaper.sh --if-unset`: first-run only, a no-op once a wallpaper exists (rotation is on-demand, `$mod+Shift+w`).
   - `floating_windows` — per-app floating rules, with commented examples.
   A system-wide `include /etc/sway/config.d/*` follows for host-level snippets.
3. **`*.local` overlays (gitignored)** — per-machine drift that must not land in the repo. Sway silently skips a missing `include`, so the default stands until you create the file:
   - `compose_key.local` — the compose-key input rule (copy `compose_key.local.example`).
   - `wallpaper_dir.local` — point the rotation pool at an external folder (copy `wallpaper_dir.local.example`).
   - `scripts/monitor-profiles.local.sh` — per-monitor hotplug profiles (copy `scripts/monitor-profiles.example.sh`).
4. **Runtime snippets** — generated under `$XDG_RUNTIME_DIR/sway/` (per-user, 0700, wiped on logout — deliberately not world-writable `/tmp`), then `include`d:
   - `swayfx_config_snippet` — written by `scripts/swayfx_guard.sh`; blank unless the running Sway is SwayFX (blur, rounded corners).
   - `sway_theme_config` — written by `scripts/toggle_theme.sh init` at startup; the active palette for the `config`-side colors.

## Reloading

`$mod+Shift+c` reloads `config` and the drop-ins. The split to keep straight: `swaymsg reload` does **not** relaunch Waybar (the `config.d/waybar` supervision owns that), and most overlays are read at event time — monitor hotplug and wallpaper rotation pick up their `*.local` files without a reload, while input rules like `compose_key.local` need the reload.
