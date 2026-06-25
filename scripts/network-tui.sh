#!/usr/bin/env bash
# Launch the best available network management TUI in kitty.
# Probes for tools in priority order; falls back to a read-only ip view.
set -euo pipefail

if command -v impala >/dev/null 2>&1; then
  exec kitty -e impala
elif command -v nmtui >/dev/null 2>&1; then
  exec kitty -e nmtui
elif command -v iwctl >/dev/null 2>&1; then
  exec kitty -e iwctl
else
  exec kitty --hold -e sh -c 'ip -c -br a; echo; ip -c r'
fi
