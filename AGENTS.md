# Agent Guidelines for Sway Configuration Repository

Conventions for contributing changes to this Sway + Waybar desktop configuration.

## Build, Lint, & Test

### Linting
`shellcheck` covers all shell scripts. CI (`.github/workflows/ci.yml`) runs it
across every tracked `*.sh` and gates at **`--severity=warning`**, so the tree
must stay warning-clean — not just error-clean. Reproduce the gate locally:

```bash
shellcheck --severity=warning $(git ls-files '*.sh')
```

Keep it green rather than suppressing: split `local x=$(cmd)` into two lines
(SC2155), name throwaway loop vars `_` (SC2034), use `printf` over `echo -e` in
`#!/bin/sh` scripts (SC3037). A repo-wide `.shellcheckrc` is the place for any
code you genuinely want to disable, with a reason.

CI's second job runs `sway -C` against the config. Note `sway -C` exits `0` even
on parse errors, so the job greps its output for `[ERROR]` instead of trusting
the exit code — do the same if you script config checks.

### Testing
Manual — these are system-integration scripts.

- **Launch Waybar directly** (stderr shows parse errors):
  ```bash
  waybar -c waybar/config.jsonc -s waybar/style.css
  ```
- **Test a custom Waybar module** in isolation:
  ```bash
  ./waybar/modules/brightness.sh
  ```
- **Verify executable bits:**
  ```bash
  chmod +x scripts/*.sh waybar/modules/*.sh
  ```

## Code Style & Conventions

### Shebang & Safety
- **Shebang:** `#!/usr/bin/env bash`
- **Safety flags:** `set -euo pipefail` (errexit, nounset, pipefail)

### Formatting & Naming
- **Indentation:** 2 spaces. No tabs.
- **Filenames:** `kebab-case.sh`.
- **Variables/functions:** `snake_case`.
- **Constants:** `UPPER_SNAKE_CASE`.

### Script Structure
1. Shebang + safety flags.
2. Header comment: purpose, inputs, outputs.
3. Constants.
4. Helper functions.
5. Main logic.

### Waybar Custom Modules (`waybar/modules/`)
Scripts here back `custom/*` modules in `waybar/config.jsonc`.

- **Output:** print one line per invocation. Empty output hides the module.
- **Performance:** budget under 50ms; cache state on disk if upstream is slow (see `brightness.sh` for the ddcutil pattern).
- **JSON mode:** if the module needs state-dependent CSS classes or tooltips, emit JSON (`{text, tooltip, class, percentage}`) and set `"return-type": "json"` in `config.jsonc`. `style.css` can then target `#custom-<name>.<class>`.
- **Failure mode:** prefer `command -v <tool> || exit 0` over silent errors — Waybar treats empty output as "nothing to show", which is the right default for missing hardware.

### Dependencies & Tooling
Always probe for tools before calling them:

```bash
command -v jq >/dev/null 2>&1 || exit 0
```

Common tools: `jq`, `swaymsg`, `upower`, `brightnessctl`, `ddcutil`, `pactl` / `wpctl`, `bluetoothctl`, `nmcli`, `makoctl`.

### Error Handling
- `|| true` on commands whose failure should not abort the script.
- `2>/dev/null` to suppress noise from probes.
- Provide a sensible fallback or exit 0 when state is unobtainable.

### Icons & UI
Nerd Font glyphs only; consistent icons per concept (battery, brightness, network, etc.). Follow each icon with one space when followed by text:

```bash
printf "󰁹 %s%%" "$PCT"
```

## Conventional Commits

[Conventional Commits](https://www.conventionalcommits.org/) — `<type>(<scope>): <description>`.

- **feat** — new feature
- **fix** — bug fix
- **docs** — docs only
- **style** — formatting only
- **refactor** — no behavior change
- **perf** — performance
- **test** — tests
- **chore** — build/tooling

Examples:
- `feat(waybar): add disk usage module`
- `fix(brightness): handle backlight devices without max_brightness`
- `docs(scripts): clarify monitor profile precedence`

## Project Architecture

- **`config`:** Primary Sway configuration. Includes `config.d/*` and theme/SwayFX snippets generated under `$XDG_RUNTIME_DIR/sway/` (per-user, 0700, wiped on logout — not world-writable `/tmp`). sway expands the variable in `include` via wordexp(3).
- **`config.d/`:** Drop-in Sway snippets sourced via `include config.d/*`. `waybar` launches the bar; `wallpaper` bootstraps `images/wp.png` from `images/wallpapers/` via `rotate-wallpaper.sh --if-unset` (a no-op when one is already set — rotation is on-demand via `$mod+Shift+w`); `floating_windows` carries per-app rules. (The compose-key input rule lives in `compose_key.local` at the repo root, included directly by `config`, not a `config.d` drop-in.)
- **`waybar/`:** Status bar config.
  - `config.jsonc` — module layout
  - `style.css` — imports the active palette via the `colors.css` symlink (gitignored)
  - `colors-dark.css` / `colors-light.css` — `@define-color` palettes. Both files **must define the same names** so `style.css` resolves in either palette.
  - `modules/` — custom shell modules for state Waybar can't read natively (DDC/CI brightness, theme indicator, mako DND).
- **`scripts/`:** Utilities bound to keybinds or `exec` lines — monitor hotplug, theme toggle, media key handlers, etc.
- **`extra/`:** Standalone configs for adjacent tools (kanshi, wofi, mako, swhkd).

## Common Workflows

### Adding a Waybar module
1. **Native module:** add its name to a `modules-*` array in `waybar/config.jsonc` and a config block below. Native modules are preferred when one fits — they're event-driven.
2. **Custom shell module:** drop the script in `waybar/modules/`, add `"custom/<name>"` to a cluster with `"exec"`, `"interval"`, and optional `"on-click"`.
3. `chmod +x waybar/modules/<name>.sh`.
4. Reload: `pkill -SIGUSR2 -x waybar` (style or `config.jsonc` changes — waybar rereads both). `swaymsg reload` no longer relaunches waybar; if you ever need a full restart, `pkill -x waybar` and let the next sway login (or run the launch command from `config.d/waybar`) bring it back.

### Modifying Sway config
1. Edit `config` (or a snippet under `config.d/`).
2. Syntax check: `sway -C`.
3. `swaymsg reload`.

### Modifying Waybar colors
1. Edit `waybar/colors-dark.css` and `waybar/colors-light.css`. Keep `@define-color` names identical across both.
2. Verify CSS parses by relaunching Waybar manually — parse errors land on stderr:
   ```bash
   waybar -c waybar/config.jsonc -s waybar/style.css
   ```
3. Live reload a running Waybar: `pkill -SIGUSR2 -x waybar`.

## Handling Hardware Variability

This config is shared across laptops and desktops.

- **Probe, don't assume:** check `/sys/class/backlight`, `upower -e`, `rfkill list bluetooth` before using a feature.
- **Empty over error:** a missing sensor should produce no output (exit 0), not a stderr noise burst — Waybar already hides empty modules.
- **No hardcoded interfaces:** use `nmcli`, `ip`, or `/proc/net/route` to discover the active interface; don't bake in `wlan0`.

## Troubleshooting

- **Waybar didn't start:** run it in the foreground (`waybar -c waybar/config.jsonc -s waybar/style.css`) — config and CSS errors print to stderr.
- **Module shows nothing:** run the module script directly to see what it prints. Empty output hides the module by design.
- **Theme didn't repaint:** confirm `waybar/colors.css` symlink exists (`scripts/toggle_theme.sh init` recreates it) and that Waybar is running (`pgrep -x waybar`).
- **Permissions:** all scripts must be `chmod +x`.

## Design Philosophy

- **Native first:** prefer Waybar's native modules; reach for `custom/*` only when there's no native equivalent for the state we need.
- **Event-driven over polling:** when a custom module *must* poll, cache aggressively on the producer side (see `scripts/external-brightness.sh` writing a cache that `waybar/modules/brightness.sh` reads).
- **Graceful degradation:** missing hardware → silent skip, not error.
- **Visual consistency:** Nerd Font icons throughout; theming via the semantic `@define-color` tokens, never inline colors in `style.css`.
