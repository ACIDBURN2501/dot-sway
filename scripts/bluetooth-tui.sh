#!/usr/bin/env bash
# Launch the best available bluetooth management TUI in kitty.
# Probes for tools in priority order; falls back to bluetoothctl's interactive shell.
set -euo pipefail

if command -v bluetuith >/dev/null 2>&1; then
  exec kitty -e bluetuith
elif command -v bluetoothctl >/dev/null 2>&1; then
  exec kitty -e bluetoothctl
else
  exec kitty --hold -e sh -c 'echo "No bluetooth tooling installed."; echo "Install bluez (bluetoothctl) or bluetuith."'
fi
