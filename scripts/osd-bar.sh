#!/usr/bin/env bash
# Write a 0-100 value to the wob OSD pipe (see extra/wob/wob.ini and the
# wob exec line in config). The OSD is feedback, never an error surface:
# wob not running or a missing pipe is a silent no-op.
set -euo pipefail

PCT="${1:-}"
case "$PCT" in
  '' | *[!0-9]*) exit 0 ;;
esac

pgrep -x wob >/dev/null 2>&1 || exit 0

PIPE="${XDG_RUNTIME_DIR:-/tmp}/sway/wob.sock"
[ -p "$PIPE" ] || exit 0

# Open the FIFO read-write so a reader that dies mid-write can never block us.
{ printf '%s\n' "$PCT" >&3; } 3<> "$PIPE" 2>/dev/null || true
