#!/usr/bin/env bash
# host-env.sh: render per-machine host.env settings into sway config.
#
# Runs at session start (an exec in config, before the input block). Reads
# host.env via the shared loader (scripts/lib/host-env.sh) and writes
# $XDG_RUNTIME_DIR/sway/host_config_snippet, which config includes ahead of
# the input block. The snippet is rewritten on every run: empty when
# host.env is absent or a value is invalid, so sway's include (which
# silently skips a missing file) always sees a clean, current state.
#
# COMPOSE_KEY is validated before it is written: the snippet is evaluated
# by sway as config, so an unchecked value could inject arbitrary commands,
# and a typo would break session startup.
#
# After editing host.env: run this script, then `swaymsg reload`.
set -euo pipefail

SWAY_DIR="${SWAY_DIR:-$HOME/.config/sway}"
LOADER="$SWAY_DIR/scripts/lib/host-env.sh"
# shellcheck disable=SC1090
. "$LOADER"

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}/sway"
mkdir -p "$RUNTIME_DIR"
SNIPPET="$RUNTIME_DIR/host_config_snippet"

DOTSWAY_HOST_ENV="${DOTSWAY_HOST_ENV:-$SWAY_DIR/host.env}"
load_host_env

: > "$SNIPPET"
if [[ -n "${COMPOSE_KEY:-}" ]]; then
  if [[ "$COMPOSE_KEY" =~ ^[a-z0-9:_-]+$ ]]; then
    printf '# Generated from host.env by scripts/host-env.sh — do not edit.\nset $compose_key %s\n' "$COMPOSE_KEY" > "$SNIPPET"
  else
    printf 'host-env: ignoring invalid COMPOSE_KEY %q (want [a-z0-9:_-]+); the committed default stands\n' "$COMPOSE_KEY" >&2
  fi
fi
