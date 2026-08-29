#!/usr/bin/env bash
# quick-menu-sandbox.sh — sandboxed assertion suite for scripts/quick-menu.sh.
#
# Runs against a throwaway $HOME with the repo copied in and PATH restricted
# to the stub bin: wofi returns scripted selections, and wpctl / nmcli /
# iwctl / bluetoothctl / kitty / systemctl / notify-send are logging stubs
# with fixture data shaped like the real daemons' output. No display, no
# session, no hardware.
#
# Usage: quick-menu-sandbox.sh /path/to/repo
# Exit:  0 when every assertion passes; prints N/M summary.
set -euo pipefail

REPO="${1:?usage: quick-menu-sandbox.sh /path/to/repo}"
[[ -f "$REPO/scripts/quick-menu.sh" ]] || { echo "not a repo root: $REPO" >&2; exit 2; }

pass=0 fail=0
assert() { # assert <desc> <cmd...>
  local desc="$1"
  shift
  if "$@"; then
    pass=$((pass + 1))
    printf 'ok   %s\n' "$desc"
  else
    fail=$((fail + 1))
    printf 'FAIL %s\n' "$desc"
  fi
}
eq() { [[ "${1-}" == "${2-}" ]]; }
grepq() { grep -q "$1" "$2" 2>/dev/null; }

SB=""
new_sandbox() { # sets HOME_ RUNTIME_ BIN_ LOG_ CHOICE_ PWCHOICE_
  SB=$(mktemp -d)
  HOME_="$SB/home"
  RUNTIME_="$SB/runtime"
  BIN_="$SB/bin"
  LOG_="$SB/tool.log"
  CHOICE_="$SB/choice"
  PWCHOICE_="$SB/pw_choice"
  Sway="$HOME_/.config/sway"
  mkdir -p "$HOME_/.config" "$RUNTIME_" "$BIN_" "$Sway"
  # Copy without .git and the wallpaper pool — heavy, and no suite needs them.
  tar -C "$REPO" --exclude=./.git --exclude=./images/wallpapers -cf - . | tar -C "$Sway" -xf -
  : > "$LOG_"
  : > "$CHOICE_"
  : > "$PWCHOICE_"
  # Real externals the script under test needs; PATH is the stub bin ONLY.
  for b in bash dirname awk grep tr cat timeout env; do
    cp "$(command -v "$b")" "$BIN_/$b" 2>/dev/null || true
  done
  # wofi: logs its args, then prints the scripted selection (PWCHOICE_ for
  # the masked password prompt).
  cat > "$BIN_/wofi" <<EOF
#!/bin/sh
echo "wofi \$*" >> "$LOG_"
cat >/dev/null
if [ -s "$PWCHOICE_" ] && printf '%s' "\$*" | grep -q "Password"; then
  cat "$PWCHOICE_"
elif [ -s "$CHOICE_" ]; then
  cat "$CHOICE_"
fi
exit 0
EOF
  for b in notify-send kitty systemctl; do
    printf '#!/bin/sh\necho "%s $*" >> "%s"\nexit 0\n' "$b" "$LOG_" > "$BIN_/$b"
  done
  chmod +x "$BIN_"/*
}

run() { # run <domain> → sets RC
  env -u SWAYSOCK HOME="$HOME_" XDG_RUNTIME_DIR="$RUNTIME_" PATH="$BIN_" \
    WOFI_LOG="$LOG_" CHOICE="$CHOICE_" PW_CHOICE="$PWCHOICE_" \
    /bin/bash "$Sway/scripts/quick-menu.sh" "$@" >/dev/null 2>&1 && RC=0 || RC=$?
}

cleanup() { [[ -n "$SB" ]] && rm -rf "$SB"; }
trap cleanup EXIT

install_wpctl_stub() {
  cat > "$BIN_/wpctl" <<EOF
#!/bin/sh
echo "wpctl \$*" >> "$LOG_"
case "\$1" in
  status) cat "$SB/wpctl-status.fixture" ;;
esac
exit 0
EOF
  chmod +x "$BIN_/wpctl"
  cat > "$SB/wpctl-status.fixture" <<'FIXTURE'
Audio
 ├─ Devices:
 │      51. TU102 High Definition Audio Controller      [alsa]
 │
 ├─ Sinks:
 │  *   46. FiiO K11 R2R Analog Stereo          [vol: 0.85]
 │     113. TU102 High Definition Audio Controller Digital Stereo (HDMI) [vol: 0.40]
 │
 ├─ Sources:
 │  *   34. WOER Analog Stereo                  [vol: 0.81]
 │
 ├─ Filters:
 │
 └─ Streams:
        72. speech-dispatcher-dummy
             71. output_FR       > FiiO K11 R2R:playback_FL	[init]
Video
 ├─ Devices:
 │      51. TU102 High Definition Audio Controller      [alsa]
FIXTURE
}

install_nmcli_stub() {
  cat > "$BIN_/nmcli" <<EOF
#!/bin/sh
echo "nmcli \$*" >> "$LOG_"
case "\$*" in
  "-t -f RUNNING general") echo running ;;
  "-g IN-USE,SSID,SIGNAL,SECURITY"*)
    printf '%s\n' '*:Home:84:WPA2' 'CoffeeShop:60:WPA2' 'OpenNet:70:'
    ;;
  "-t -f NAME,TYPE connection show")
    printf '%s\n' 'Home:802-11-wireless' 'Wired connection 3:802-3-ethernet'
    ;;
  "-t -f NAME connection show") echo Home ;;
esac
exit 0
EOF
  chmod +x "$BIN_/nmcli"
}

install_iwctl_stub() {
  cat > "$BIN_/iwctl" <<EOF
#!/bin/sh
echo "iwctl \$*" >> "$LOG_"
if [ "\$1" = station ] && [ "\$2" = list ]; then
  printf '%s\n' '          Devices in station mode' '-------------------------------------------------' '  wlan0              station       disconnected'
elif [ "\$1" = station ] && [ "\$3" = get-networks ]; then
  printf '%s\n' '        Networks found for station wlan0' '------' '  >  Old      psk   -40' '     Home     psk   -55' '     OpenNet  open  -70'
elif [ "\$1" = known-networks ]; then
  echo '   Old   psk'
elif [ "\$1" = station ] && [ "\$3" = connect ]; then
  cat >> "$SB/iwd_psk"
fi
exit 0
EOF
  chmod +x "$BIN_/iwctl"
}

install_bluetoothctl_stub() { # state: powered + one paired device (connected)
  cat > "$BIN_/bluetoothctl" <<EOF
#!/bin/sh
echo "bluetoothctl \$*" >> "$LOG_"
case "\$*" in
  show) echo 'Powered: yes' ;;
  devices*) echo 'Device AA:BB:CC:DD:EE:FF Headset' ;;
  info*) echo 'Connected: yes' ;;
  power*) echo 'Changing power off succeeded' ;;
  disconnect*) echo 'Successful disconnected' ;;
esac
exit 0
EOF
  chmod +x "$BIN_/bluetoothctl"
}

# ------------------------------------------------------------------ S1: usage
new_sandbox
run
assert "no argument exits 0" eq "$RC" 0
run bogus
assert "unknown domain exits 0" eq "$RC" 0

# ------------------------------------------------------- S2: wofi is optional
new_sandbox
rm -f "$BIN_/wofi"
run audio
assert "without wofi the menu silently skips" eq "$RC" 0

# ------------------------------------------------------------------ S3: audio
new_sandbox
install_wpctl_stub
printf '%s' '● Output: FiiO K11 R2R Analog Stereo [46]' > "$CHOICE_"
run audio
assert "default sink marked and listed" grepq 'wofi -d -k /dev/null -p Audio:' "$LOG_"
assert "selecting a sink sets it default" grepq 'wpctl set-default 46' "$LOG_"

new_sandbox
install_wpctl_stub
printf '%s' 'Mute output' > "$CHOICE_"
run audio
assert "mute entry toggles sink mute" grepq 'wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle' "$LOG_"

new_sandbox
install_wpctl_stub
run audio
assert "dismissed audio menu exits 0" eq "$RC" 0

# ------------------------------------------------- S4: network via NetworkManager
new_sandbox
install_nmcli_stub
printf '%s' 'Home (84%)' > "$CHOICE_"
run network
assert "visible saved network connects via its profile" grepq 'nmcli connection up Home' "$LOG_"

new_sandbox
install_nmcli_stub
printf '%s' 'CoffeeShop (60%)' > "$CHOICE_"
printf '%s' 'hunter2' > "$PWCHOICE_"
run network
assert "new network prompts with masked wofi (-P)" grepq 'wofi -d -k /dev/null -p Password for CoffeeShop: -P' "$LOG_"
assert "new network connects with the entered password" grepq 'nmcli device wifi connect CoffeeShop password hunter2' "$LOG_"

new_sandbox
install_nmcli_stub
printf '%s' 'Open network TUI' > "$CHOICE_"
run network
assert "TUI entry opens the terminal TUI" grepq 'kitty' "$LOG_"

new_sandbox
install_nmcli_stub
run network
assert "dismissed network menu exits 0" eq "$RC" 0

# -------------------------------------------------------- S5: network via iwd
new_sandbox
rm -f "$BIN_/nmcli"
install_iwctl_stub
printf '%s' 'Home' > "$CHOICE_"
printf '%s' 'hunter2' > "$PWCHOICE_"
run network
assert "iwd scan ran for the station" grepq 'iwctl station wlan0 scan' "$LOG_"
assert "unknown iwd network connects with stdin passphrase" grepq 'iwctl station wlan0 connect Home' "$LOG_"
assert "passphrase piped to iwctl" eq "$(cat "$SB/iwd_psk")" "hunter2"

new_sandbox
rm -f "$BIN_/nmcli"
install_iwctl_stub
printf '%s' '● Old' > "$CHOICE_"
run network
assert "known iwd network connects without a prompt" grepq 'iwctl station wlan0 connect Old' "$LOG_"
assert "no password asked for known network" bash -c "[[ ! -s '$SB/iwd_psk' ]]"

# ------------------------------------------------------------- S6: bluetooth
new_sandbox
install_bluetoothctl_stub
printf '%s' 'Disconnect Headset (AA:BB:CC:DD:EE:FF)' > "$CHOICE_"
run bluetooth
assert "connected device offers disconnect and works" grepq 'bluetoothctl disconnect AA:BB:CC:DD:EE:FF' "$LOG_"

new_sandbox
cat > "$BIN_/bluetoothctl" <<EOF
#!/bin/sh
echo "bluetoothctl \$*" >> "$LOG_"
case "\$*" in
  show) echo 'Powered: no' ;;
  devices*) echo 'Device AA:BB:CC:DD:EE:FF Headset' ;;
  info*) echo 'Connected: no' ;;
  power*) echo 'Changing power on succeeded' ;;
esac
exit 0
EOF
chmod +x "$BIN_/bluetoothctl"
printf '%s' 'Enable bluetooth' > "$CHOICE_"
run bluetooth
assert "powered-off state offers enable and works" grepq 'bluetoothctl power on' "$LOG_"

new_sandbox
install_bluetoothctl_stub
printf '%s' 'Pair a new device (TUI)' > "$CHOICE_"
run bluetooth
assert "pair entry opens the terminal TUI" grepq 'kitty -e bluetoothctl' "$LOG_"

new_sandbox
install_bluetoothctl_stub
run bluetooth
assert "dismissed bluetooth menu exits 0" eq "$RC" 0

# ------------------------------------------------------------------ S7: power
new_sandbox
printf '%s' 'Reboot' > "$CHOICE_"
run power
assert "power menu delegates to wofi-power.sh" grepq 'systemctl reboot' "$LOG_"

new_sandbox
rm -f "$Sway/extra/wofi/wofi-power.sh"
run power
assert "missing power script is a silent no-op" eq "$RC" 0

echo
echo "$pass/$((pass + fail)) assertions passed"
[[ "$fail" -eq 0 ]]
