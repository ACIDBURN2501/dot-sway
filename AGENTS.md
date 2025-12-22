# Agent Guidelines

## Build, Lint, & Test
- **Lint:** Use `shellcheck` for all scripts.
  `shellcheck *.sh status.d/*.sh scripts/*.sh`
- **Test:** Run `statusbar.sh` manually to verify output format.
  `./statusbar.sh`
- **Permissions:** Ensure scripts are executable.
  `chmod +x *.sh status.d/* scripts/*.sh`

## Code Style & Conventions
- **Shebang/Safety:** Always start with `#!/usr/bin/env bash` and `set -euo pipefail`.
- **Formatting:** Indent with **2 spaces**. Do not use tabs.
- **Naming:** Use `kebab-case.sh` for files and `snake_case` for variables/functions.
- **Structure:** Define helper functions at the top, execution logic at the bottom.
- **Status Scripts:** `status.d/` scripts must print **one line** to stdout and exit 0.
- **Dependencies:** Verify external tools (jq, swaymsg, upower) availability or handle errors gracefully (e.g., `|| true`).
- **Icons:** Use Nerd Fonts icons for UI elements.
- **Comments:** Explain "why", not "what". Keep concise.
