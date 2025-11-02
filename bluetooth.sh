#!/usr/bin/env bash

BLUETOOTH_CONNECTED=""
BLUETOOTH_DISCONNECTED="󰂯"

if ! command -v bluetoothctl &>/dev/null; then
  echo "$BLUETOOTH_DISCONNECTED"
  exit 1
fi

if bluetoothctl show | grep -q "Connected: yes"; then
  echo "$BLUETOOTH_CONNECTED"
else
  echo "$BLUETOOTH_DISCONNECTED"
fi
