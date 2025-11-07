#!/usr/bin/env bash
# ----------------------------------------------------------------------
#  Bluetooth status script for SwayFX / i3status / Waybar, etc.
#  Returns a single Unicode icon that represents the current state:
#
#       – at least one device is connected
#    󰂯 – controller is on but no device is connected
#    󰂲 – controller is powered off or no controller is found
# ----------------------------------------------------------------------

BLUETOOTH_CONNECTED=""
BLUETOOTH_DISCONNECTED="󰂯"
BLUETOOTH_OFF="󰂲"

# ----------------------------------------------------------------------
# Helper: print the chosen icon and exit with the appropriate code.
#   $1 – icon to print
#   $2 – exit status (0 = good/connected, 1 = just info, 2 = error/off)
# ----------------------------------------------------------------------
print_and_exit() {
  printf '%s\n' "$1"
  exit "${2:-0}"
}

# ----------------------------------------------------------------------
# 1. Verify that bluetoothctl exists.
# ----------------------------------------------------------------------
if ! command -v bluetoothctl &>/dev/null; then
  # No bluetoothctl → we cannot query the stack → treat as “off”.
  print_and_exit "$BLUETOOTH_OFF" 2
fi

# ----------------------------------------------------------------------
# 2. Grab the short “show” dump.
# ----------------------------------------------------------------------
# Using `bluetoothctl show` without a device name prints the properties
# of the *default* controller (or the error message you already saw).
SHOW_OUTPUT=$(bluetoothctl show 2>/dev/null)

# ----------------------------------------------------------------------
# 3. Determine whether a controller is present.
# ----------------------------------------------------------------------
if [[ $SHOW_OUTPUT == *"No default controller"* ]]; then
  # No controller => bluetooth is effectively off.
  print_and_exit "$BLUETOOTH_OFF" 2
fi

# ----------------------------------------------------------------------
# 4. Is the controller powered?
# ----------------------------------------------------------------------
if ! grep -q "^Powered: yes$" <<<"$SHOW_OUTPUT"; then
  # The controller exists but is turned off.
  print_and_exit "$BLUETOOTH_DISCONNECTED" 2
fi

# ----------------------------------------------------------------------
# 5. At this point the controller is present AND powered.
#    We only need to know whether a device is connected.
# ----------------------------------------------------------------------
if bluetoothctl info | grep -q "^Connected: yes$"; then
  print_and_exit "$BLUETOOTH_CONNECTED" 0
else
  print_and_exit "$BLUETOOTH_DISCONNECTED" 1
fi
