#!/usr/bin/env bash
# monitor-sandbox.sh: sandboxed assertion suite for
# scripts/monitor-hotplug.sh in --once mode: external-setting resolution
# (env var > host.env > per-monitor profile > default) and the docked-mode
# action sequence.
#
# Runs against a throwaway $HOME with the repo copied in. swaymsg is
# stubbed (logs argv, serves canned get_outputs/get_workspaces JSON) and
# SWAYSOCK points at a nonexistent socket, so even a stub miss cannot touch
# a real session. The lid path (/proc/acpi/button/lid) is not faked: the
# docked-mode assertions hold for any lid state because
# DISABLE_INTERNAL_ON_EXTERNAL=true.
#
# Usage: monitor-sandbox.sh /path/to/repo
# Exit:  0 when every assertion passes; prints N/M summary.
set -euo pipefail

REPO="${1:?usage: monitor-sandbox.sh /path/to/repo}"
[[ -f "$REPO/scripts/monitor-hotplug.sh" ]] || { echo "not a repo root: $REPO" >&2; exit 2; }

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
grepq() { grep -q -e "$1" "$2" 2>/dev/null; }

SB=""
new_sandbox() { # sets SB HOME_ RUNTIME_ BIN_ LOG_ Sway HOTLOG_
  SB=$(mktemp -d)
  HOME_="$SB/home"
  RUNTIME_="$SB/runtime"
  BIN_="$SB/bin"
  LOG_="$SB/swaymsg.log"
  Sway="$HOME_/.config/sway"
  HOTLOG_="$RUNTIME_/sway/monitor-hotplug.log"
  mkdir -p "$HOME_/.config" "$RUNTIME_" "$BIN_" "$Sway"
  tar -C "$REPO" --exclude=./.git --exclude=./images/wallpapers -cf - . | tar -C "$Sway" -xf -
  : > "$LOG_"
  # Canned outputs: one internal eDP panel, one external HDMI monitor.
  cat > "$SB/outputs.json" <<'JSON'
[
  {"name":"eDP-1","make":"BOE","model":"0x1234","serial":"","active":true},
  {"name":"HDMI-A-1","make":"ExampleMake","model":"ExampleModel","serial":"SERIAL1","active":false}
]
JSON
  # swaymsg stub: log the argv, serve the canned JSON for the two queries
  # the script makes, succeed silently for everything else.
  cat > "$BIN_/swaymsg" <<EOF
#!/bin/sh
echo "swaymsg \$*" >> "$LOG_"
if [ "\$1" = "-t" ] && [ "\$2" = "get_outputs" ]; then cat "$SB/outputs.json"; exit 0; fi
if [ "\$1" = "-t" ] && [ "\$2" = "get_workspaces" ]; then echo '[]'; exit 0; fi
exit 0
EOF
  chmod +x "$BIN_/swaymsg"
}

# Profile fixture: match the canned monitor, any unit (trailing glob).
write_profile() {
  cat > "$Sway/scripts/monitor-profiles.local.sh" <<'EOF'
dotsway_monitor_profile() {
  case "$2|$3|$4" in
    'ExampleMake|ExampleModel|'*) set_monitor_profile '2560x1440@144Hz' '1.5' 'on' ;;
  esac
}
EOF
}

# Run the script with the sandboxed HOME / XDG dirs, the stub bin first in
# PATH, and SWAYSOCK pointing nowhere as a second line of defence.
run_sandbox() { # run_sandbox <script> [args...]
  env HOME="$HOME_" XDG_CONFIG_HOME="$HOME_/.config" XDG_RUNTIME_DIR="$RUNTIME_" \
    SWAYSOCK="$SB/no-such.sock" DOTSWAY_HOST_ENV="$Sway/host.env" \
    PATH="$BIN_:$PATH" /bin/bash "$@"
}

# --- resolution precedence ------------------------------------------------

new_sandbox
run_sandbox "$Sway/scripts/monitor-hotplug.sh" --once
assert "default: external enabled with fallback settings" grepq 'output HDMI-A-1 enable mode 1920x1080@60Hz scale 1 pos 0 0 adaptive_sync off' "$LOG_"
assert "default: internal panel disabled" grepq 'output eDP-1 disable' "$LOG_"
assert "default: source logged as default" grepq 'mode=1920x1080@60Hz \[default\]' "$HOTLOG_"

new_sandbox
write_profile
run_sandbox "$Sway/scripts/monitor-hotplug.sh" --once
assert "profile: per-monitor settings applied" grepq 'output HDMI-A-1 enable mode 2560x1440@144Hz scale 1.5 pos 0 0 adaptive_sync on' "$LOG_"
assert "profile: source logged as profile" grepq 'mode=2560x1440@144Hz \[profile\]' "$HOTLOG_"

new_sandbox
write_profile
printf 'DOTSWAY_EXT_RES=3840x2160@120Hz\n' > "$Sway/host.env"
run_sandbox "$Sway/scripts/monitor-hotplug.sh" --once
assert "host.env: resolution beats the profile" grepq 'output HDMI-A-1 enable mode 3840x2160@120Hz scale 1.5 ' "$LOG_"
assert "host.env: resolution source logged as env" grepq 'mode=3840x2160@120Hz \[env\]' "$HOTLOG_"

new_sandbox
printf 'DOTSWAY_EXT_RES=3840x2160@120Hz\n' > "$Sway/host.env"
DOTSWAY_EXT_RES=1280x720@60Hz run_sandbox "$Sway/scripts/monitor-hotplug.sh" --once
assert "precedence: env var beats host.env" grepq 'output HDMI-A-1 enable mode 1280x720@60Hz ' "$LOG_"

new_sandbox
printf 'DOTSWAY_INTERNAL_OUTPUT=eDP-9\n' > "$Sway/host.env"
run_sandbox "$Sway/scripts/monitor-hotplug.sh" --once
assert "host.env: internal output override applied" grepq 'output eDP-9 disable' "$LOG_"

printf '%d/%d assertions passed\n' "$pass" "$((pass + fail))"
[[ "$fail" -eq 0 ]]
