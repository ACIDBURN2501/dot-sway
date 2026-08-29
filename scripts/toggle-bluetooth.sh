#!/usr/bin/env bash
# Toggle the bluetooth radio and notify. Reached from the bluetooth bar
# module's right-click; the quick menu (scripts/quick-menu.sh bluetooth)
# carries the same toggle for the keyboard path.
set -euo pipefail

command -v bluetoothctl >/dev/null 2>&1 || exit 0

STATE="off"
if timeout 5 bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
  timeout 5 bluetoothctl power off >/dev/null 2>&1 || true
  STATE="off"
else
  timeout 5 bluetoothctl power on >/dev/null 2>&1 || true
  STATE="on"
fi

command -v notify-send >/dev/null 2>&1 && notify-send -t 1500 "Bluetooth $STATE" || true
