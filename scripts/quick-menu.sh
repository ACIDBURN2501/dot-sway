#!/usr/bin/env bash
# Domain quick menus (wofi dmenu popups): audio devices, network, bluetooth,
# and power. Reached from hotkeys ($super+Ctrl+a/w/b/p) and the bar's
# left-clicks; right-clicks keep the short single actions (mute, radio
# toggle, TUI).
#
# Contract: every backend is probed first and the menu silently skips when
# the tool or hardware is absent; a dismissed menu (Escape) is a no-op.
# External calls are wrapped in timeout so a wedged daemon can never hang
# the popup.
#
# Usage: quick-menu.sh <audio|network|bluetooth|power>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Query ceilings: quick (per-call) and the slower Wi-Fi rescan. Arrays so
# the invocation stays shellcheck-clean with and without timeout present.
if command -v timeout >/dev/null 2>&1; then
  TQ=(timeout 5)
  TS=(timeout 15)
else
  TQ=()
  TS=()
fi

command -v wofi >/dev/null 2>&1 || exit 0

# Show a menu; entries on stdin, the chosen line on stdout. Cacheless;
# these lists are dynamic, nothing should be remembered between runs.
menu() { # menu <prompt> [extra wofi args...]
  local prompt="$1"
  shift
  wofi -d -k /dev/null -p "$prompt" "$@"
}

notify() { # notify <text>: best-effort toast
  command -v notify-send >/dev/null 2>&1 && notify-send -t 2000 "$1" || true
}

# ---------------------------------------------------------------- audio (wpctl)

audio_menu() {
  command -v wpctl >/dev/null 2>&1 || return 0

  local entries
  entries=$("${TQ[@]}" wpctl status 2>/dev/null | awk '
    /^Audio$/ {in_audio = 1; next}
    /^(Video|Settings)$/ {in_audio = 0; next}
    in_audio && /Sinks:/ {mode = "sink"; next}
    in_audio && /Sources:/ {mode = "source"; next}
    in_audio && /(Devices|Filters|Cards|Profiles|Ports|Endpoints|Streams):/ {mode = ""; next}
    in_audio && mode != "" {
      prefix = (mode == "sink") ? "Output: " : "Input: "
      mark = (index($0, "*") > 0) ? "● " : "  "
      if (match($0, /[0-9]+\./)) {
        id = substr($0, RSTART, RLENGTH - 1)
        name = substr($0, RSTART + RLENGTH)
        sub(/\[[^]]*\][[:space:]]*$/, "", name)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
        print mark prefix name " [" id "]"
      }
    }')
  [ -n "$entries" ] || return 0

  local chosen
  chosen=$(printf 'Mute output\nMute microphone\n%s\n' "$entries" | menu "Audio:") || return 0
  case "$chosen" in
  "Mute output")
    wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
    ;;
  "Mute microphone")
    wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
    ;;
  *\[*\]*)
    local id="${chosen##*\[}"
    id="${id%\]}"
    [ -n "$id" ] && "${TQ[@]}" wpctl set-default "$id"
    ;;
  esac
}

# ------------------------------------------------------- network (NM then iwd)

network_menu() {
  if command -v nmcli >/dev/null 2>&1 &&
    [ "$("${TQ[@]}" nmcli -t -f RUNNING general 2>/dev/null)" = "running" ]; then
    network_menu_nm
  elif command -v iwctl >/dev/null 2>&1; then
    network_menu_iwd
  fi
}

network_menu_nm() {
  local visible="" visible_ssids="" saved="" line ssid signal in_use mark name chosen pw
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    # -g escapes colons inside values as "\:", so split from the field ends.
    # the SSID (middle) is the only field that may contain colons.
    in_use=${line%%:*}
    rest=${line#*:}
    signal=${rest##*:}
    rest=${rest%:*}
    ssid=${rest%:*}
    ssid=${ssid//\\:/:}
    [ -n "$ssid" ] || continue
    mark=""
    [ "$in_use" = "*" ] && mark="● "
    visible+="${mark}${ssid} (${signal}%)"$'\n'
    visible_ssids+="${ssid}"$'\n'
  done < <("${TS[@]}" nmcli -g IN-USE,SSID,SIGNAL,SECURITY dev wifi list --rescan yes 2>/dev/null)

  while IFS= read -r name; do
    [ -n "$name" ] || continue
    if ! grep -Fxq "$name" <<<"$visible_ssids"; then
      saved+="${name} (saved)"$'\n'
    fi
  done < <("${TQ[@]}" nmcli -t -f NAME,TYPE connection show 2>/dev/null | awk -F: '$2 == "802-11-wireless" {print $1}')

  local entries="${visible}${saved}Open network TUI"
  chosen=$(printf '%s\n' "$entries" | menu "Network:") || return 0
  case "$chosen" in
  "Open network TUI")
    exec "$SCRIPT_DIR/network-tui.sh"
    ;;
  *"(saved)")
    name="${chosen% (saved)}"
    if ! "${TS[@]}" nmcli connection up "$name" >/dev/null 2>&1; then
      notify "Failed to connect to $name"
    fi
    ;;
  *" ("*")") # visible network: "● ssid (NN%)", a saved profile connects
    # directly, anything else asks for the password (wofi's masked mode).
    ssid="${chosen% (*}"
    ssid="${ssid#● }"
    [ -n "$ssid" ] || return 0
    if "${TQ[@]}" nmcli -t -f NAME connection show 2>/dev/null | grep -Fxq "$ssid"; then
      if ! "${TS[@]}" nmcli connection up "$ssid" >/dev/null 2>&1; then
        notify "Failed to connect to $ssid"
      fi
    else
      pw=$(menu "Password for $ssid:" -P < /dev/null) || return 0
      [ -n "$pw" ] || return 0
      if ! "${TS[@]}" nmcli device wifi connect "$ssid" password "$pw" >/dev/null 2>&1; then
        notify "Failed to connect to $ssid"
      fi
    fi
    ;;
  esac
}

network_menu_iwd() {
  local dev networks name chosen pw
  dev=$("${TQ[@]}" iwctl station list 2>/dev/null | awk 'NR > 2 && NF >= 3 {print $1; exit}')
  [ -n "$dev" ] || return 0

  "${TQ[@]}" iwctl station "$dev" scan >/dev/null 2>&1 || true
  networks=$("${TQ[@]}" iwctl station "$dev" get-networks 2>/dev/null | awk '
    NR > 2 && NF >= 3 {
      line = $0
      mark = (line ~ /^[[:space:]]*>/) ? "● " : ""
      gsub(/^[[:space:]]*>?[[:space:]]*/, "", line)
      split(line, f, /[[:space:]]+/)
      if (f[2] == "psk" || f[2] == "open" || f[2] == "8021x") print mark f[1]
    }')
  [ -n "$networks" ] || return 0

  chosen=$(printf '%s\n' "$networks" | menu "Network:") || return 0
  name="${chosen#● }"
  [ -n "$name" ] || return 0
  if "${TQ[@]}" iwctl known-networks list 2>/dev/null | grep -Fq "$name"; then
    if ! "${TS[@]}" iwctl station "$dev" connect "$name" >/dev/null 2>&1; then
      notify "Failed to connect to $name"
    fi
  else
    pw=$(menu "Password for $name:" -P < /dev/null) || return 0
    if [ -n "$pw" ]; then
      if ! printf '%s' "$pw" | "${TS[@]}" iwctl station "$dev" connect "$name" >/dev/null 2>&1; then
        notify "Failed to connect to $name"
      fi
    else
      "${TS[@]}" iwctl station "$dev" connect "$name" >/dev/null 2>&1 || notify "Failed to connect to $name"
    fi
  fi
}

# -------------------------------------------------------- bluetooth (bluez)

bt_query() { # bt_query <args...>: bluetoothctl with a hard ceiling; prints
  # the output, exits non-zero when it fails (caller decides the fallback)
  "${TQ[@]}" bluetoothctl "$@" 2>/dev/null
}

bluetooth_menu() {
  command -v bluetoothctl >/dev/null 2>&1 || return 0

  local entries="" line mac name chosen
  if bt_query show | grep -q "Powered: yes"; then
    entries+="Disable bluetooth"$'\n'
  else
    entries+="Enable bluetooth"$'\n'
  fi

  local paired=""
  paired=$(bt_query devices Paired) || paired=""
  # Older bluez has no Paired listing; fall back to all known devices.
  [ -n "$paired" ] || paired=$(bt_query devices) || paired=""
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    mac=$(grep -oE '([0-9A-F]{2}:){5}[0-9A-F]{2}' <<<"$line") || continue
    name=${line#*"Device $mac "}
    if bt_query info "$mac" | grep -q "Connected: yes"; then
      entries+="Disconnect $name ($mac)"$'\n'
    else
      entries+="Connect $name ($mac)"$'\n'
    fi
  done <<<"$paired"

  entries+="Pair a new device (TUI)"
  chosen=$(printf '%s\n' "$entries" | menu "Bluetooth:") || return 0
  case "$chosen" in
  "Enable bluetooth")
    bt_query power on >/dev/null || true
    ;;
  "Disable bluetooth")
    bt_query power off >/dev/null || true
    ;;
  "Pair a new device (TUI)")
    exec "$SCRIPT_DIR/bluetooth-tui.sh"
    ;;
  "Connect "* | "Disconnect "*)
    mac=$(grep -oE '([0-9A-F]{2}:){5}[0-9A-F]{2}' <<<"$chosen") || return 0
    if [[ "$chosen" == "Connect "* ]]; then
      bt_query connect "$mac" >/dev/null || notify "Failed to connect"
    else
      bt_query disconnect "$mac" >/dev/null || true
    fi
    ;;
  esac
}

# ------------------------------------------------------------------- power

power_menu() {
  local script="$SCRIPT_DIR/../extra/wofi/wofi-power.sh"
  [ -x "$script" ] && exec "$script"
  return 0
}

# -------------------------------------------------------------------- main

case "${1:-}" in
audio) audio_menu ;;
network) network_menu ;;
bluetooth) bluetooth_menu ;;
power) power_menu ;;
*) exit 0 ;;
esac
