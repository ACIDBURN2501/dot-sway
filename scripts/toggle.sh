#!/usr/bin/env bash
# Per-session toggle flag store.
#
# A deliberately dumb store of existence flags under
# $XDG_RUNTIME_DIR/sway/toggles/ (0700, wiped on logout). Each toggle
# script owns its flag: it writes the flag on every flip, so an absent
# flag means "off" and can never be stale across sessions.
#
# Usage:
#   toggle.sh set <name> [value]   create or refresh the flag; value is
#                                 stored as the file content (presence is
#                                 what `get` reports)
#   toggle.sh unset <name>         remove the flag
#   toggle.sh get <name>           print nothing; exit 0 if set, 1 if unset

set -euo pipefail

TOGGLES_DIR="${XDG_RUNTIME_DIR:-/tmp}/sway/toggles"

usage() {
  printf 'Usage: %s {set|unset|get} <name> [value]\n' "$0" >&2
  exit 2
}

[[ $# -ge 2 ]] || usage
CMD="$1"
NAME="$2"

# Names are flat and boring: no path separators or shell metacharacters.
if [[ ! "$NAME" =~ ^[A-Za-z0-9_-]+$ ]]; then
  printf 'toggle.sh: invalid flag name: %s\n' "$NAME" >&2
  exit 2
fi

case "$CMD" in
  set)
    mkdir -p "$TOGGLES_DIR"
    chmod 700 "$TOGGLES_DIR"
    printf '%s\n' "${3-}" > "$TOGGLES_DIR/$NAME"
    ;;
  unset)
    rm -f "$TOGGLES_DIR/$NAME"
    ;;
  get)
    if [[ -f "$TOGGLES_DIR/$NAME" ]]; then
      exit 0
    fi
    exit 1
    ;;
  *)
    usage
    ;;
esac
