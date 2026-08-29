#!/usr/bin/env bash
# Event hook dispatcher.
#
# Runs every executable file in the event's hook directories, in sorted
# order:
#
#   hooks/<event>.d/        tracked, ships with the repo
#   hooks.local/<event>.d/  machine-local overlay (gitignored)
#
# Contract (documented in the .sample files and docs/hooks.md):
#   * a hook is any executable file in the directory;
#   * .sample files are non-executable and never run;
#   * a hook receives the event name as $1;
#   * a missing directory is a silent no-op;
#   * a non-zero exit is logged to stderr; the remaining hooks still run.
#
# Usage: hooks.sh <event>
set -euo pipefail

EVENT="${1-}"
if [[ -z "$EVENT" || ! "$EVENT" =~ ^[A-Za-z0-9_-]+$ ]]; then
  printf 'Usage: %s <event>\n' "$0" >&2
  exit 2
fi

SWAY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for dir in "$SWAY_DIR/hooks/$EVENT.d" "$SWAY_DIR/hooks.local/$EVENT.d"; do
  [[ -d "$dir" ]] || continue
  for hook in "$dir"/*; do
    [[ -f "$hook" && -x "$hook" ]] || continue
    rc=0
    "$hook" "$EVENT" || rc=$?
    if [[ "$rc" -ne 0 ]]; then
      printf 'hooks.sh: %s exited %d\n' "$hook" "$rc" >&2
    fi
  done
done

exit 0
