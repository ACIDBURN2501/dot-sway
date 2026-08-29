#!/usr/bin/env bash
# power-sandbox.sh — sandboxed assertion suite for scripts/power-events.sh.
#
# Runs against a throwaway $HOME with the repo copied in and PATH restricted
# to the stub bin: upower replays a scripted queue of DisplayDevice samples
# (percentage + state), notify-send logs to a file, and executable test
# hooks append every fired event to a log. No display, no session, no
# battery hardware.
#
# Usage: power-sandbox.sh /path/to/repo
# Exit:  0 when every assertion passes; prints N/M summary.
set -euo pipefail

REPO="${1:?usage: power-sandbox.sh /path/to/repo}"
[[ -f "$REPO/scripts/power-events.sh" ]] || { echo "not a repo root: $REPO" >&2; exit 2; }

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
no_grepq() { ! grep -q "$1" "$2" 2>/dev/null; }
count() { grep -c "$1" "$2" 2>/dev/null || true; }
logs_empty() { [[ ! -s "$LOG_" && ! -s "$HOOKLOG_" ]]; }

SB=""
WPID=""
new_sandbox() { # sets HOME_ RUNTIME_ BIN_ LOG_ HOOKLOG_ QUEUE_ SB
  SB=$(mktemp -d)
  HOME_="$SB/home"
  RUNTIME_="$SB/runtime"
  BIN_="$SB/bin"
  LOG_="$SB/notify.log"
  HOOKLOG_="$SB/hooks.log"
  QUEUE_="$SB/queue"
  Sway="$HOME_/.config/sway"
  mkdir -p "$HOME_/.config" "$RUNTIME_" "$BIN_" "$Sway"
  # Copy without .git and the wallpaper pool — heavy, and no suite needs them.
  tar -C "$REPO" --exclude=./.git --exclude=./images/wallpapers -cf - . | tar -C "$Sway" -xf -
  : > "$LOG_"
  : > "$HOOKLOG_"
  : > "$QUEUE_"
  : > "$SB/last"
  # Real externals the watcher needs; PATH is the stub bin ONLY.
  for b in bash dirname awk grep tr cat timeout env sleep head sed mkdir; do
    cp "$(command -v "$b")" "$BIN_/$b" 2>/dev/null || true
  done
  # notify-send: logs the full invocation (urgency assertions included).
  printf '#!/bin/sh\necho "notify-send $*" >> "%s"\nexit 0\n' "$LOG_" > "$BIN_/notify-send"
  # Executable test hooks — one per event, appending to the hook log.
  for ev in battery-low battery-charged power-plugged power-unplugged; do
    printf '#!/bin/sh\necho "$1" >> "%s"\n' "$HOOKLOG_" > "$Sway/hooks/$ev.d/99-test.sh"
  done
  chmod +x "$BIN_"/* "$Sway/hooks/"*.d/99-test.sh
}

install_upower_stub() { # args: lines of "<pct> <state>" replayed per -i call
  cat > "$SB/devices.fixture" <<'FIX'
/org/freedesktop/UPower/devices/battery_BAT0
/org/freedesktop/UPower/devices/DisplayDevice
FIX
  cat > "$BIN_/upower" <<EOF
#!/bin/sh
case "\$1" in
  -e) cat "$SB/devices.fixture" ;;
  -i)
    line="\$(head -n 1 "$QUEUE_" 2>/dev/null)"
    if [ -n "\$line" ]; then
      sed -i 1d "$QUEUE_"
    else
      line="\$(cat "$SB/last")"
    fi
    printf '%s\n' "\$line" > "$SB/last"
    pct="\${line%% *}"; st="\${line#* }"
    printf '  updated:             10 seconds ago\n'
    printf '  state:               %s\n' "\$st"
    printf '  warning-level:       none\n'
    printf '  percentage:          %s%%\n' "\$pct"
    ;;
esac
exit 0
EOF
  chmod +x "$BIN_/upower"
}

run_bg() { # start the watcher; the caller fills the queue first
  env -u SWAYSOCK HOME="$HOME_" XDG_RUNTIME_DIR="$RUNTIME_" PATH="$BIN_" \
    POWER_EVENTS_INTERVAL="${INTERVAL_:-0.2}" POWER_EVENTS_LOW_PCT="${LOW_:-20}" \
    /bin/bash "$Sway/scripts/power-events.sh" >/dev/null 2>&1 &
  WPID=$!
}

run_fg() { # start the watcher in the foreground (returns when it exits)
  RC=0
  env -u SWAYSOCK HOME="$HOME_" XDG_RUNTIME_DIR="$RUNTIME_" PATH="$BIN_" \
    POWER_EVENTS_INTERVAL="${INTERVAL_:-0.2}" POWER_EVENTS_LOW_PCT="${LOW_:-20}" \
    /bin/bash "$Sway/scripts/power-events.sh" >/dev/null 2>&1 || RC=$?
}

stop_watcher() {
  [[ -n "$WPID" ]] || return 0
  kill "$WPID" 2>/dev/null || true
  wait "$WPID" 2>/dev/null || true
  WPID=""
}

# wait_queue_drain: poll until the upower queue is empty, then one interval.
wait_queue_drain() {
  local n=0
  while [[ -s "$QUEUE_" ]] && (( n < 100 )); do
    sleep 0.1
    n=$((n + 1))
  done
  sleep 0.5
}

cleanup() {
  stop_watcher
  [[ -n "$SB" ]] && rm -rf "$SB"
}
trap cleanup EXIT

# --- degradation: no battery → exits 0 after the first probe, silent ------
new_sandbox
install_upower_stub
: > "$SB/devices.fixture" # upower -e lists nothing: a desktop
run_fg
assert "desktop without a battery exits 0"        eq "$RC" "0"
assert "desktop without a battery stays silent"   logs_empty

# --- degradation: no upower → silent skip ----------------------------------
new_sandbox
run_fg
assert "without upower the watcher exits 0"       eq "$RC" "0"
assert "without upower nothing fires"             logs_empty

# --- episode logic: each transition fires exactly once ----------------------
new_sandbox
install_upower_stub
cat > "$QUEUE_" <<'Q'
25 discharging
19 discharging
18 discharging
90 charging
100 fully-charged
99 discharging
18 discharging
19 charging
100 fully-charged
100 fully-charged
Q
run_bg
wait_queue_drain
stop_watcher
assert "battery-low fires once per discharge episode (2 total)" \
  eq "$(count battery-low "$HOOKLOG_")" "2"
assert "battery-charged fires once per charge episode (2 total)" \
  eq "$(count battery-charged "$HOOKLOG_")" "2"
assert "power-plugged fires per transition (2 total)" \
  eq "$(count power-plugged "$HOOKLOG_")" "2"
assert "power-unplugged fires per transition (1 total)" \
  eq "$(count power-unplugged "$HOOKLOG_")" "1"
assert "the low battery notified"                 grepq "Battery low" "$LOG_"
assert "notifications carry default urgency (DND-suppressible)" \
  no_grepq '\-u critical' "$LOG_"
read -r FINAL_CLASS FINAL_LOW FINAL_FULL < "$RUNTIME_/sway/power-events.state"
assert "state file ends plugged with full flagged" \
  eq "$FINAL_CLASS $FINAL_LOW $FINAL_FULL" "plugged 0 1"

# --- single-instance guard: a second watcher refuses to run ----------------
new_sandbox
install_upower_stub
printf '50 discharging\n' > "$QUEUE_"
run_bg
# Wait for the seed: once the state file exists, the first watcher is live.
n=0
while [[ ! -s "$RUNTIME_/sway/power-events.state" ]] && (( n < 50 )); do
  sleep 0.1
  n=$((n + 1))
done
INTERVAL_=30
run_fg
assert "a second watcher exits 0 instead of double-firing" eq "$RC" "0"
INTERVAL_=0.2
stop_watcher

# --- summary -----------------------------------------------------------------
printf '%d/%d assertions passed\n' "$pass" "$((pass + fail))"
(( fail == 0 ))
