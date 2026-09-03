#!/usr/bin/env bash
# osd-sandbox.sh: sandboxed assertion suite for the wob OSD writers:
# scripts/osd-bar.sh, volume-control.sh, brightness-control.sh, and
# external-brightness.sh.
#
# Runs against a throwaway $HOME with the repo copied in and every
# hardware-facing binary stubbed (wpctl, pactl, brightnessctl, ddcutil,
# notify-send, wob, pgrep). A real FIFO stands in for the wob pipe and a
# background reader captures what the writers push to it.
#
# Usage: osd-sandbox.sh /path/to/repo
# Exit:  0 when every assertion passes; prints N/M summary.
set -euo pipefail

REPO="${1:?usage: osd-sandbox.sh /path/to/repo}"
[[ -f "$REPO/scripts/osd-bar.sh" ]] || { echo "not a repo root: $REPO" >&2; exit 2; }

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
new_sandbox() { # sets HOME_ RUNTIME_ BIN_ LOG_
  SB=$(mktemp -d)
  HOME_="$SB/home"
  RUNTIME_="$SB/runtime"
  BIN_="$SB/bin"
  LOG_="$SB/tool.log"
  FIFO_="$RUNTIME_/sway/wob.sock"
  OSD_OUT_="$SB/osd_out"
  Sway="$HOME_/.config/sway"
  mkdir -p "$HOME_/.config" "$RUNTIME_/sway" "$BIN_" "$Sway" "$SB/bl"
  # Copy without .git and the wallpaper pool (heavy, and no suite needs them).
  tar -C "$REPO" --exclude=./.git --exclude=./images/wallpapers -cf - . | tar -C "$Sway" -xf -
  : > "$LOG_"
  : > "$OSD_OUT_"
  mkfifo "$FIFO_"
  # Real externals the scripts under test need, copied into the stub bin so
  # the sandbox can run with PATH=$BIN_ ONLY; a real wpctl on the host must
  # never leak into the pactl-fallback tests.
  for b in bash dirname awk grep tr cat; do
    cp "$(command -v "$b")" "$BIN_/$b"
  done
  # pgrep lies that wob is running; every stub logs its invocation.
  printf '#!/bin/sh\nexit 0\n' > "$BIN_/pgrep"
  printf '#!/bin/sh\necho "wob $*" >> "%s"\ncat >/dev/null\n' "$LOG_" > "$BIN_/wob"
  printf '#!/bin/sh\necho "notify-send $*" >> "%s"\nexit 0\n' "$LOG_" > "$BIN_/notify-send"
  printf '#!/bin/sh\necho "brightnessctl $*" >> "%s"\ncase $1 in get) echo 40;; max) echo 100;; esac\n' "$LOG_" > "$BIN_/brightnessctl"
  for b in wpctl pactl ddcutil; do
    printf '#!/bin/sh\nexit 0\n' > "$BIN_/$b"
  done
  chmod +x "$BIN_"/*
}

start_reader() { # background reader capturing what the writers push
  cat "$FIFO_" > "$OSD_OUT_" &
  READER_=$!
}

stop_reader() {
  kill "$READER_" 2>/dev/null || true
  wait "$READER_" 2>/dev/null || true
}

run() { # run <script> [args...] → sets RC (stdout discarded; writers talk via the FIFO)
  # PATH is the stub bin alone: no host binary can leak into a test.
  env -u SWAYSOCK HOME="$HOME_" XDG_RUNTIME_DIR="$RUNTIME_" PATH="$BIN_" \
    BACKLIGHT_DIR="$SB/bl" /bin/bash "$HOME_/.config/sway/scripts/$1" "${@:2}" >/dev/null 2>&1 && RC=0 || RC=$?
}

cleanup() { stop_reader; [[ -n "$SB" ]] && rm -rf "$SB"; }
trap cleanup EXIT

install_wpctl_stub() { # stateful: sink/source levels, mute via marker file
  cat > "$BIN_/wpctl" <<EOF
#!/bin/sh
echo "wpctl \$*" >> "$LOG_"
case "\$*" in
  *set-mute*) : > "$SB/sink_muted" ;;
  *get-volume*@DEFAULT_AUDIO_SINK@*) [ -f "$SB/sink_muted" ] && echo "Volume: 0.65 [MUTED]" || echo "Volume: 0.65" ;;
  *get-volume*@DEFAULT_AUDIO_SOURCE@*) echo "Volume: 0.50 [MUTED]" ;;
esac
exit 0
EOF
  chmod +x "$BIN_/wpctl"
}

install_pactl_stub() { # stateful: sink volume 71%, mute flag via marker file
  cat > "$BIN_/pactl" <<EOF
#!/bin/sh
echo "pactl \$*" >> "$LOG_"
case "\$1 \$2" in
  "get-sink-volume @DEFAULT_SINK@") echo "Volume: front-left: 46530 /  71% / -8.79 dB" ;;
  "get-sink-mute @DEFAULT_SINK@") [ -f "$SB/sink_muted" ] && echo "Mute: yes" || echo "Mute: no" ;;
  "get-source-mute @DEFAULT_SOURCE@") [ -f "$SB/src_muted" ] && echo "Mute: yes" || echo "Mute: no" ;;
esac
exit 0
EOF
  chmod +x "$BIN_/pactl"
}

install_ddcutil_stub() {
  cat > "$BIN_/ddcutil" <<EOF
#!/bin/sh
echo "ddcutil \$*" >> "$LOG_"
case "\$1 \$2 \$3" in
  "getvcp 10 --terse") echo "VCP 10 C 45 100" ;;
esac
exit 0
EOF
  chmod +x "$BIN_/ddcutil"
}

# ---------------------------------------------------------------- S1: osd-bar.sh
new_sandbox
start_reader
run osd-bar.sh 85
sleep 0.3
stop_reader
assert "numeric value reaches the wob pipe" eq "$(tr -d '[:space:]' < "$OSD_OUT_")" "85"

new_sandbox
run osd-bar.sh notanumber
assert "non-numeric value exits 0 silently" eq "$RC" 0

new_sandbox
rm -f "$FIFO_"
run osd-bar.sh 50
assert "missing pipe is a silent no-op" eq "$RC" 0

# --------------------------------------------------------- S2: volume via wpctl
new_sandbox
install_wpctl_stub
start_reader
run volume-control.sh up
sleep 0.3
stop_reader
assert "wpctl up called" grepq "wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+" "$LOG_"
assert "new level 65 pushed to the OSD" eq "$(tr -d '[:space:]' < "$OSD_OUT_")" "65"

new_sandbox
install_wpctl_stub
start_reader
run volume-control.sh mute
sleep 0.3
stop_reader
assert "wpctl mute called" grepq "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle" "$LOG_"
assert "muted pushes 0 to the OSD" eq "$(tr -d '[:space:]' < "$OSD_OUT_")" "0"

new_sandbox
install_wpctl_stub
run volume-control.sh mic-mute
assert "mic mute notifies (muted via wpctl source)" grepq "notify-send -t 1500 Microphone muted" "$LOG_"
assert "mic mute pushes no OSD bar" eq "$(tr -d '[:space:]' < "$OSD_OUT_")" ""

new_sandbox
rm -f "$FIFO_"
install_wpctl_stub
run volume-control.sh up
assert "volume change without wob still exits 0" eq "$RC" 0
assert "volume change still applied" grepq "wpctl set-volume" "$LOG_"

# --------------------------------------------------------- S3: volume via pactl
drop_wpctl() { # remove the stub entirely: with PATH=$BIN_ the script then
  # takes the pactl fallback, on any host (CI has no wpctl; this box does).
  rm -f "$BIN_/wpctl"
}

new_sandbox
drop_wpctl
install_pactl_stub
start_reader
run volume-control.sh up
sleep 0.3
stop_reader
assert "pactl fallback used" grepq "pactl set-sink-volume @DEFAULT_SINK@ +5%" "$LOG_"
assert "pactl level 71 pushed to the OSD" eq "$(tr -d '[:space:]' < "$OSD_OUT_")" "71"

new_sandbox
drop_wpctl
install_pactl_stub
touch "$SB/sink_muted"
start_reader
run volume-control.sh mute
sleep 0.3
stop_reader
assert "pactl muted pushes 0" eq "$(tr -d '[:space:]' < "$OSD_OUT_")" "0"

new_sandbox
drop_wpctl
install_pactl_stub
touch "$SB/src_muted"
run volume-control.sh mic-mute
assert "pactl mic mute notifies" grepq "notify-send -t 1500 Microphone muted" "$LOG_"

# ------------------------------------------------------- S4: brightness control
new_sandbox
touch "$SB/bl/card0-backlight"
start_reader
run brightness-control.sh up
sleep 0.3
stop_reader
assert "brightnessctl set called" grepq "brightnessctl -q set 5%+" "$LOG_"
assert "backlight level 40 pushed to the OSD" eq "$(tr -d '[:space:]' < "$OSD_OUT_")" "40"

new_sandbox
run brightness-control.sh up
assert "no backlight dir is a silent no-op" eq "$RC" 0

# ---------------------------------------------------- S5: external (DDC/CI) brightness
new_sandbox
install_ddcutil_stub
start_reader
run external-brightness.sh up
sleep 0.3
stop_reader
assert "ddcutil setvcp called with 55" grepq "ddcutil setvcp 10 55" "$LOG_"
assert "external level 55 pushed to the OSD" eq "$(tr -d '[:space:]' < "$OSD_OUT_")" "55"
assert "cache updated for the waybar module" eq "$(cat "$RUNTIME_/sway-brightness-ext")" "55 100"

echo
echo "$pass/$((pass + fail)) assertions passed"
[[ "$fail" -eq 0 ]]
