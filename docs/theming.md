# Theme Toggle & Wallpaper

## Theme toggle (dark/light)

A single keybind (`Mod+Shift+t`) flips Sway, Waybar, kitty, wofi, mako, and (under GNOME) Gnome's `color-scheme` between dark and light. The script is `scripts/toggle_theme.sh`; it runs `init` at Sway startup to bootstrap all components.

- **Status indicator:** 🌙 dark / ☀️ light (`waybar/modules/theme.sh`).
- **Gnome sync:** when `gsettings` reports `org.gnome.desktop.interface color-scheme`, that is the source of truth; otherwise `.theme_state` is.
- **Live Waybar repaint:** symlink swap + `SIGUSR2`, no restart.

```bash
scripts/toggle_theme.sh toggle   # flip
scripts/toggle_theme.sh init     # re-apply current theme to all components
scripts/toggle_theme.sh get      # print "dark" or "light"
```

## Wallpaper rotation

Rotation is **on-demand**. Press `$mod+Shift+w` to switch to a fresh random wallpaper; otherwise the current one persists across reloads and logins. `scripts/rotate-wallpaper.sh` does the work:

1. Scans the pool for `.png/.jpg/.jpeg` (case-insensitive, top level). Pool is `images/wallpapers/` by default; a gitignored `wallpaper_dir.local` (copy `wallpaper_dir.local.example`) can point it at an external folder.
2. Picks one uniformly at random.
3. Repoints the `images/wp.png` symlink at the pick.
4. Applies it live with `swaymsg output * bg images/wp.png fill`.

`config.d/wallpaper` runs the script with `--if-unset` on each start/reload. That is a **bootstrap only**: it sets a wallpaper when `wp.png` isn't already an existing file (e.g. a fresh checkout) — a random pool pick, or the committed `images/default.png` when the pool is empty — and is a no-op otherwise, so `$mod+Shift+c` (reload) and logins keep whatever you last chose.

Because everything that references the wallpaper reads `images/wp.png`, the lock screen follows your pick automatically: the active swaylock keybind (`$super+l`) uses it, and so does the commented swayidle example in `config` (its `timeout`/`before-sleep` hooks) if you enable it.

```bash
cp ~/Pictures/*.jpg ~/.config/sway/images/wallpapers/   # add wallpapers
$mod+Shift+w                                            # switch to a random pick
scripts/rotate-wallpaper.sh                             # or roll directly
```

With an empty or missing pool, an already-set `wp.png` is left untouched; a fresh checkout falls back to the committed `images/default.png` so the desktop is never blank and the swaylock image always loads.

**Cold-boot note:** Sway parses `output * bg` before `exec_always` fires, so the boot wallpaper is whatever `wp.png` pointed at when you last shut down. Since start-up no longer rotates, there's no flash — the persisted wallpaper is what you see. Only a first-run checkout (no `wp.png` yet) shows a blank background for a moment at parse, until the bootstrap points `wp.png` at `images/default.png` (or a pool pick) just after login.
