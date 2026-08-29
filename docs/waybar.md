# Waybar (Status Bar)

**What:** The status bar — workspace and mode indicators, brightness, audio, theme, DND, bluetooth, network, tray, battery, clock — plus the contract custom shell modules must follow.
**Where:** `waybar/` — `config.jsonc` (layout), `style.css` + `colors-{dark,light}.css` (palette), `modules/` (custom shell modules). Launched from `config.d/waybar`.
**Verified:** parse errors print to stderr when run in the foreground; the theme and DND custom modules are exercised by the CI theme suite (`tests/theme-sandbox.sh`).

Waybar is launched by `config.d/waybar` on Sway start. The snippet points `waybar/colors.css` at the active palette, then supervises Waybar (respawning it if it dies to an early-boot D-Bus race, capped at 5 attempts). `exec` (not `exec_always`) so reloads don't kill the bar; theme switches reload it live via `SIGUSR2`.

## Layout

| Cluster | Modules |
|---------|---------|
| Left    | `sway/workspaces`, `sway/mode` |
| Center  | `custom/brightness`, `pulseaudio`, `custom/theme`, `custom/dnd`, `bluetooth`, `network` |
| Right   | `tray`, `battery`, `clock` |

Battery, audio, bluetooth, network, and clock use Waybar's native event-driven modules (D-Bus, no polling). Brightness, theme, and DND are custom shell modules under `waybar/modules/`.

## Adding modules

- **Native module:** add its name to a `modules-*` array in `config.jsonc` and a config block below. See the [Waybar wiki](https://github.com/Alexays/Waybar/wiki). Native modules are preferred; they're event-driven.
- **Custom shell module:** drop an executable in `waybar/modules/`, then add `"custom/<name>"` to a cluster with `"exec"`, an `"interval"`, and an optional `"on-click"`. For state-dependent styling, emit JSON (`{text, tooltip, class, percentage}`) and set `"return-type": "json"` so `style.css` can then target `#custom-<name>.<class>`.

### The module output contract

Custom modules are polled on their interval, and the output rules are the interface:

- **One line per run.** Empty output hides the module — missing hardware or a missing tool prints nothing and exits 0, not an error.
- **Budget ~50ms per run.** If the source is slow (a DDC/CI probe, a daemon query), cache on the producer side and read the cache here — `brightness.sh` reads the cache that `scripts/external-brightness.sh` writes.
- **Probe before you call:** `command -v jq >/dev/null 2>&1 || exit 0`.

After a change: `pkill -SIGUSR2 -x waybar` (Waybar rereads config and CSS). `swaymsg reload` no longer relaunches Waybar; for a full restart, `pkill -x waybar` and let the next login (or the `config.d/waybar` command) bring it back.

## Theming

Edit `waybar/colors-dark.css` and `waybar/colors-light.css`; both **must define the same `@define-color` names** so `style.css` resolves in either palette. Don't put colors in `style.css`; use the semantic tokens (`@bg`, `@fg`, `@accent`, `@warning`, …). The theme toggle swaps the `colors.css` symlink and sends `SIGUSR2` so Waybar repaints in place — see [theming.md](theming.md).
