#!/bin/sh
# POSIX sh (dash-compatible), so no pipefail.
set -eu

# Define power actions
Shutdown_command="systemctl poweroff"
Reboot_command="systemctl reboot"
Logout_command="swaymsg exit"
Hibernate_command="systemctl hibernate"
Suspend_command="systemctl suspend"

# Menu options
options="Shutdown\nReboot\nSuspend\nHibernate\nLogout"

# Show menu; a dismissed menu leaves $chosen empty and the case below
# falls through, so cancel exits 0 as before.
chosen=$(printf '%b\n' "$options" | wofi --show dmenu --prompt "Power:" --width 20%) || chosen=""

# Run the selected command
case "$chosen" in
shutdown) eval "$Shutdown_command" ;;
reboot) eval "$Reboot_command" ;;
suspend) eval "$Suspend_command" ;;
hibernate) eval "$Hibernate_command" ;;
logout) eval "$Logout_command" ;;
esac
