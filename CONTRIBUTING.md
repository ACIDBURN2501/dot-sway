# Contributing to sync

sync is a Sway desktop and the bootstrap that gets you one, in one repo. The bar is low and the gates are boring: everything a change needs to pass already runs in CI, and the commands below are the same ones.

## Local gates

Run these before you push. They are the CI jobs, in the same order:

```sh
# shellcheck, gated at warning, over every tracked script
shellcheck --severity=warning $(git ls-files '*.sh')

# syntax check, every tracked script
for f in $(git ls-files '*.sh'); do bash -n "$f"; done

# the sandboxed script suites (no display or sway needed)
bash tests/theme-sandbox.sh "$PWD"
bash tests/osd-sandbox.sh "$PWD"
bash tests/quick-menu-sandbox.sh "$PWD"
bash tests/power-sandbox.sh "$PWD"
bash tests/idle-sandbox.sh "$PWD"
bash tests/host-env-sandbox.sh "$PWD"
bash tests/monitor-sandbox.sh "$PWD"

# markdown links (needs the lychee binary, ~40s)
lychee --no-progress '**/*.md'
```

If you touch the Sway config itself, `sway -C` is the config gate. CI runs it with a headless backend, so you do not need a local session, just a sway install.

## House style

- `#!/usr/bin/env bash` and `set -euo pipefail` in bash scripts. The one `#!/bin/sh` script (the wofi power menu) carries `set -eu`; dash has no pipefail.
- 2-space indent, snake_case variables, kebab-case.sh filenames.
- Probe for a tool before you call it: `command -v jq >/dev/null 2>&1 || exit 0`.
- A missing sensor prints nothing and exits 0. It does not print errors.
- Nerd Font icons, one space between an icon and its text.
- Split `local x=$(cmd)` into two lines. shellcheck enforces it.

The longer version, including the rationale for the warning gate, is in [AGENTS.md](AGENTS.md).

## Waybar custom modules

Modules in `waybar/modules/` back `custom/*` entries in the bar config:

- One line of output per run. Empty output hides the module. That is the feature, not a bug.
- Stay under ~50ms. If the source is slow, cache on the producer side and read the cache (see `brightness.sh`).
- Need a CSS class or a tooltip that depends on state? Emit JSON and set `"return-type": "json"` in `waybar/config.jsonc`.
- `theme.sh` is the one module without the safety flags. Its whole body is one if/else that always ends in an echo, and its contract is the same one line or nothing; leave it as is.

## Commits

Conventional Commits: `<type>(<scope>): <description>`. The types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`. The body explains why the change is needed, not what the diff already says.

## Pull requests

Small and focused. One feature or one fix per PR. A PR is the first time a runner sees your commits, and the `sway -C` job is best-effort (vanilla sway from apt, not SwayFX), so aim for a green local run plus a green PR.

## When in doubt

Open an issue first. The project is small, and even a modest design change has outsized implications. A half-day of discussion beats a three-hour rewrite.
