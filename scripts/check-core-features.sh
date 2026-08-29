#!/usr/bin/env bash
# Probe the local machine against the "just works" matrix in
# docs/core-features.md and print a table. Read-only: checks binaries,
# packages, units, and sockets; changes nothing.
#
# Usage: scripts/check-core-features.sh
# Exit:  0 if no feature is missing, 1 if any ✗.
#
#   ✓ ok   ! degraded or not applicable   ✗ missing
set -euo pipefail

# --- Constants ---------------------------------------------------------------

DISTRO="unknown"
case "$(grep -m1 '^ID=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')" in
arch) DISTRO="arch" ;;
debian) DISTRO="debian" ;;
esac

RESULTS=()

# --- Helpers -----------------------------------------------------------------

has_bin() { command -v "$1" >/dev/null 2>&1; }

pkg_installed() {
  case "$DISTRO" in
  arch) pacman -Qi "$1" >/dev/null 2>&1 ;;
  debian) dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'ok installed' ;;
  *) return 1 ;;
  esac
}

unit_active() { systemctl is-active --quiet "$1" 2>/dev/null; }

report() { # mark, feature, detail
  RESULTS+=("$(printf '%-3s%-22s — %s' "$1" "$2" "$3")")
}

# --- Feature probes (one per matrix row, matrix order) -----------------------

check_terminal() {
  if has_bin kitty; then
    report "✓" "Terminal" "kitty"
  else
    report "✗" "Terminal" "kitty not installed"
  fi
}

check_launcher() {
  if has_bin wofi; then
    report "✓" "Launcher" "wofi"
  else
    report "✗" "Launcher" "wofi not installed"
  fi
}

check_notifications() {
  if ! has_bin mako; then
    report "✗" "Notifications" "mako not installed"
    return 0
  fi
  if pgrep -x mako >/dev/null 2>&1; then
    report "✓" "Notifications" "mako daemon running"
  else
    report "!" "Notifications" "mako installed, daemon not running"
  fi
}

check_exit_confirm() {
  if has_bin swaynag; then
    report "✓" "Exit confirm" "swaynag"
  else
    report "✗" "Exit confirm" "swaynag not installed"
  fi
}

check_screenshots() {
  if has_bin grim && has_bin slurp; then
    report "✓" "Screenshots" "grim + slurp"
  else
    report "✗" "Screenshots" "grim or slurp missing"
  fi
}

check_lock_idle() {
  if has_bin swaylock && has_bin swayidle; then
    report "✓" "Lock / idle" "swaylock + swayidle"
  else
    report "✗" "Lock / idle" "swaylock or swayidle missing"
  fi
}

check_volume() {
  if has_bin wpctl; then
    report "✓" "Volume" "wpctl"
  elif has_bin pactl; then
    report "!" "Volume" "pactl fallback (no wpctl)"
  else
    report "✗" "Volume" "no wpctl or pactl"
  fi
}

check_media() {
  if has_bin playerctl; then
    report "✓" "Media (MPRIS)" "playerctl + waybar mpris module"
  else
    report "✗" "Media (MPRIS)" "playerctl not installed"
  fi
}

check_backlight() {
  if ! has_bin brightnessctl; then
    report "✗" "Backlight" "brightnessctl not installed"
    return 0
  fi
  if has_bin ddcutil; then
    report "✓" "Backlight" "brightnessctl + ddcutil"
  else
    report "!" "Backlight" "no ddcutil (external displays)"
  fi
}

check_battery() {
  if ! has_bin upower; then
    report "✗" "Battery" "upower not installed"
    return 0
  fi
  if upower -e 2>/dev/null | grep -q battery; then
    report "✓" "Battery" "upower + battery"
  else
    report "!" "Battery" "upower present, no battery (module hidden)"
  fi
}

check_bluetooth() {
  if ! has_bin bluetoothctl; then
    report "✗" "Bluetooth" "bluetoothctl not installed"
    return 0
  fi
  if ! has_bin rfkill; then
    report "!" "Bluetooth" "bluez present, rfkill unavailable (hardware unknown)"
  elif rfkill list bluetooth 2>/dev/null | grep -q bluetooth; then
    report "✓" "Bluetooth" "bluez + hardware"
  else
    report "!" "Bluetooth" "bluez present, no bluetooth hardware"
  fi
}

check_network_daemon() {
  local iwd_active=0 nm_active=0
  if unit_active iwd.service; then iwd_active=1; fi
  if unit_active NetworkManager.service; then nm_active=1; fi
  if [ "$iwd_active" -eq 1 ] && [ "$nm_active" -eq 1 ]; then
    report "!" "Network daemon" "both iwd and NetworkManager active"
  elif [ "$iwd_active" -eq 1 ]; then
    report "✓" "Network daemon" "iwd"
  elif [ "$nm_active" -eq 1 ]; then
    report "✓" "Network daemon" "NetworkManager"
  else
    report "✗" "Network daemon" "neither iwd nor NetworkManager active"
  fi
}

check_network_tui() {
  if has_bin impala; then
    report "✓" "Network TUI" "impala"
  elif has_bin nmtui; then
    report "✓" "Network TUI" "nmtui"
  elif has_bin iwctl; then
    report "✓" "Network TUI" "iwctl"
  else
    report "!" "Network TUI" "ip fallback only"
  fi
}

check_firewall() {
  if has_bin ufw; then
    report "✓" "Firewall" "ufw installed"
  else
    report "✗" "Firewall" "ufw not installed"
  fi
}

check_portals() {
  local p missing=()
  if [ "$DISTRO" != "arch" ] && [ "$DISTRO" != "debian" ]; then
    # No package manager we can query: probe the runtime instead.
    if has_bin xdg-desktop-portal; then
      report "✓" "Portals" "xdg-desktop-portal present (unknown distro)"
    else
      report "✗" "Portals" "xdg-desktop-portal not found"
    fi
    return 0
  fi
  for p in xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk; do
    if ! pkg_installed "$p"; then missing+=("$p"); fi
  done
  if [ ${#missing[@]} -eq 0 ]; then
    report "✓" "Portals" "wlr + gtk backends"
  elif [ ${#missing[@]} -lt 3 ]; then
    report "!" "Portals" "missing: ${missing[*]}"
  else
    report "✗" "Portals" "no portal backends"
  fi
}

check_clipboard() {
  if has_bin wl-copy; then
    report "✓" "Clipboard" "wl-clipboard"
  else
    report "✗" "Clipboard" "wl-clipboard not installed"
  fi
}

check_ssh_agent() {
  if [ -n "${SSH_AUTH_SOCK:-}" ] && [ -S "${SSH_AUTH_SOCK}" ]; then
    report "✓" "SSH agent" "socket ${SSH_AUTH_SOCK}"
  elif [ -n "${SSH_AUTH_SOCK:-}" ]; then
    report "!" "SSH agent" "SSH_AUTH_SOCK set but socket missing"
  elif [ -S "${XDG_RUNTIME_DIR:-/tmp}/ssh-agent.socket" ]; then
    report "!" "SSH agent" "agent socket present, not exported to this shell"
  else
    report "✗" "SSH agent" "no reachable agent socket"
  fi
}

check_secrets() {
  if ! has_bin age; then
    report "✗" "Secrets" "age not installed"
    return 0
  fi
  if has_bin rage; then
    report "✓" "Secrets" "age + rage"
  else
    report "!" "Secrets" "age only (no rage for encrypting)"
  fi
}

check_tailscale() {
  if ! has_bin tailscale; then
    report "✗" "Tailscale" "not installed"
    return 0
  fi
  if tailscale status >/dev/null 2>&1; then
    report "✓" "Tailscale" "on tailnet"
  else
    report "!" "Tailscale" "installed, not on tailnet"
  fi
}

check_snapshots() {
  local fs
  fs="$(findmnt -no FSTYPE / || true)"
  if [ "$fs" = "btrfs" ]; then
    if has_bin snapper; then
      report "✓" "System snapshots" "btrfs + snapper"
    else
      report "✗" "System snapshots" "btrfs but snapper not installed"
    fi
  else
    report "!" "System snapshots" "N/A (not btrfs: $fs)"
  fi
}

check_text_apps() {
  local p have=()
  for p in gnome-text-editor evince loupe; do
    if has_bin "$p"; then have+=("$p"); fi
  done
  if [ ${#have[@]} -eq 3 ]; then
    report "✓" "Text / PDF / images" "gnome-text-editor + evince + loupe"
  elif [ ${#have[@]} -gt 0 ]; then
    report "!" "Text / PDF / images" "${have[*]} only"
  else
    report "✗" "Text / PDF / images" "none installed"
  fi
}

check_theme() {
  if has_bin gnome-shell; then
    report "✓" "Theme source of truth" "gnome-shell (gsettings)"
  else
    report "✗" "Theme source of truth" "gnome-shell not installed"
  fi
}

# --- Main --------------------------------------------------------------------

main() {
  check_terminal
  check_launcher
  check_notifications
  check_exit_confirm
  check_screenshots
  check_lock_idle
  check_volume
  check_media
  check_backlight
  check_battery
  check_bluetooth
  check_network_daemon
  check_network_tui
  check_firewall
  check_portals
  check_clipboard
  check_ssh_agent
  check_secrets
  check_tailscale
  check_snapshots
  check_text_apps
  check_theme

  printf 'Core features (%s)\n' "$DISTRO"
  printf '%s\n' "Legend: ✓ ok · ! degraded or N/A · ✗ missing"
  printf -- '---\n'
  local line ok=0 warn=0 fail=0
  for line in "${RESULTS[@]}"; do
    case "$line" in
    "✓"*) ok=$((ok + 1)) ;;
    "!"*) warn=$((warn + 1)) ;;
    "✗"*) fail=$((fail + 1)) ;;
    esac
    printf '%s\n' "$line"
  done
  printf -- '---\n'
  printf '%d ok, %d degraded/N/A, %d missing\n' "$ok" "$warn" "$fail"
  [ "$fail" -eq 0 ]
}

main "$@"
