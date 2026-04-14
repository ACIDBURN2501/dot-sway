# Agent Guidelines for Sway Configuration Repository

This document outlines the standards, conventions, and workflows for agents contributing to this repository. Adhering to these guidelines ensures consistency, stability, and maintainability of the Sway configuration and its supporting scripts.

## Build, Lint, & Test

### Linting
We use `shellcheck` for all shell scripts. All scripts must pass linting before being considered stable.
- **Run linter on all scripts:**
  ```bash
  shellcheck *.sh status.d/*.sh scripts/*.sh
  ```
- **Run linter on a single file:**
  ```bash
  shellcheck path/to/script.sh
  ```

### Testing
Testing is primarily manual as these are system integration scripts.
- **Run the main status bar loop:**
  ```bash
  ./statusbar.sh
  ```
- **Test a specific status module:**
  ```bash
  ./status.d/20-brightness.sh
  ```
- **Verify file permissions:** Ensure all scripts are executable.
  ```bash
  chmod +x *.sh status.d/* scripts/*.sh
  ```

## Code Style & Conventions

### Shebang & Safety
Always use a proper shebang and enable safety flags to prevent unexpected behavior.
- **Shebang:** `#!/usr/bin/env bash`
- **Safety Flags:** `set -euo pipefail`
  - `-e`: Exit immediately if a command exits with a non-zero status.
  - `-u`: Treat unset variables as an error.
  - `-o pipefail`: The return value of a pipeline is the status of the last command to exit with a non-zero status.

### Formatting & Naming
- **Indentation:** Use **2 spaces** for indentation. Never use tabs.
- **File Naming:** Use `kebab-case.sh` (e.g., `monitor-hotplug.sh`).
- **Variable/Function Naming:** Use `snake_case` (e.g., `get_battery_info`).
- **Constants:** Use `UPPER_SNAKE_CASE` (e.g., `ICON_VOL_MUTE`).

### Structure
Scripts should follow a logical structure:
1. Shebang and safety flags.
2. Comments describing the script's purpose and usage.
3. Configuration variables and constants.
4. Helper functions.
5. Execution logic / Main entry point.

### Status Scripts (`status.d/`)
Scripts in `status.d/` are executed by `statusbar.sh` once per second.
- **Output:** Must print exactly **one line** to stdout.
- **Formatting:** Do not include leading/trailing whitespace or extra newlines. `statusbar.sh` handles joining outputs.
- **Performance:** Must be fast (ideally <20ms). Use `|| true` or check command existence to prevent script failure from stopping the bar.
- **Ordering:** Files are executed in lexical order (e.g., `20-brightness.sh` comes before `30-volume.sh`).

### Dependencies & Tooling
Verify that required external tools are available before attempting to use them.
- **Check for commands:**
  ```bash
  if ! command -v jq >/dev/null 2>&1; then
    exit 0
  fi
  ```
- **Common Tools:** `jq`, `swaymsg`, `upower`, `brightnessctl`, `ddcutil`, `pactl`, `bluetoothctl`.

### Error Handling
- Use `|| true` for commands that might fail but shouldn't halt execution (e.g., fetching status).
- Provide sensible fallbacks if a command fails or a value is missing.
- Use `2>/dev/null` to suppress noise from commands that might fail gracefully.

### Icons & UI
We use Nerd Fonts for status bar icons.
- Use consistent icons for similar features (e.g., `` for brightness, `` for volume).
- Ensure icons are followed by a space if they are preceding text (e.g., `printf "󰁹 %s%%" "$PCT"`).

## Conventional Commits

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification for all changes. This helps in generating changelogs and understanding the project history.

**Format:** `<type>(<scope>): <description>`

- **feat:** A new feature (e.g., `feat(status): add network speed module`)
- **fix:** A bug fix (e.g., `fix(battery): handle missing DisplayDevice gracefully`)
- **docs:** Documentation only changes (e.g., `docs(agents): update linting instructions`)
- **style:** Changes that do not affect the meaning of the code (white-space, formatting, etc.)
- **refactor:** A code change that neither fixes a bug nor adds a feature
- **perf:** A code change that improves performance
- **test:** Adding missing tests or correcting existing tests
- **chore:** Changes to the build process or auxiliary tools and libraries

**Examples:**
- `feat(timer): improved the algorithm for sub nanosecond times`
- `fix(volume): use pactl instead of amixer for better compatibility`
- `style(brightness): fix indentation in 20-brightness.sh`

## Project Architecture

- **Root:** Contains the main `statusbar.sh` and core scripts like `battery.sh` and `power.sh`.
- **`status.d/`:** Modular status bar components. Each script here adds a "block" to the center of the bar.
- **`scripts/`:** Independent utility scripts for window management, hotplugging, etc.
  - `monitor-hotplug.sh`: Handles display switching AND system suspension logic for clamshell mode.
- **`extra/`:** External configuration for tools like `kanshi` and `wofi`.
- **`config`:** The primary Sway configuration file.

## Common Workflows

### Adding a New Status Module
1. Create a new script in `status.d/` (e.g., `50-new-module.sh`).
2. Add the shebang and safety flags.
3. Check for required dependencies at the start.
4. Implement the logic to fetch the status.
5. Format the output with an icon and optional text.
6. Make the script executable: `chmod +x status.d/50-new-module.sh`.
7. Verify by running `./status.d/50-new-module.sh` and then `./statusbar.sh`.

### Modifying Sway Config
1. Edit the `config` file.
2. Test the configuration for syntax errors: `sway -C`.
3. Reload Sway to apply changes: `swaymsg reload`.

## Handling Hardware Variability

As this configuration is intended to be portable across different machines:
- **Conditional Execution:** Always check for the presence of hardware-specific tools or files (e.g., `/sys/class/backlight` or `upower`).
- **Graceful Fallbacks:** If a hardware feature is missing, the script should exit silently (exit 0) without printing anything.
- **Portability:** Avoid hardcoding specific interface names (like `wlan0`) unless necessary; use tools like `ip` or `nmcli` to discover them.

## Troubleshooting Agents

When an agent encounters an issue:
1. **Check Logs:** Look for error messages in the terminal where `statusbar.sh` is running.
2. **Manual Execution:** Run the failing script manually with `bash -x` to see execution trace.
3. **Environment:** Verify that all environment variables (like `PATH`) are correctly set.
4. **Permissions:** Ensure all scripts and directories have the correct read/execute permissions.

## Design Philosophy

- **Minimalism:** Keep scripts small and focused. Avoid unnecessary dependencies.
- **Robustness:** Configuration should handle missing hardware or software gracefully without crashing the desktop environment or status bar.
- **Speed:** The status bar updates every second; all modules must return results almost instantly.
- **Visual Consistency:** Use Nerd Font icons and consistent spacing to maintain a clean aesthetic.
