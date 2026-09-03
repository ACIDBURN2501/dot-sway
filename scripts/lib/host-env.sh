#!/usr/bin/env bash
# lib/host-env.sh: shared loader for the per-machine host.env file.
#
# Sourced, not executed. Every script that reads per-machine settings goes
# through this file so the file location and the precedence rule live in
# exactly one place.
#
# host.env (gitignored; copy host.env.example) holds per-machine settings
# as bash KEY=VALUE assignments at the repo root, i.e.
# ~/.config/sway/host.env in a standard install. It is sourced with full
# privileges: trusted user configuration, same as
# scripts/monitor-profiles.local.sh.
#
#   load_host_env
#     Sources host.env when present (absent file is not an error; the
#     caller's defaults stand). Precedence:
#       non-empty environment variable > host.env > built-in default
#     Known keys already set (non-empty) in the environment are snapshotted
#     before the source and restored after it, so the file cannot clobber a
#     session-provided value. The caller applies defaults afterwards with
#     : "${VAR:=default}" or "${VAR:-default}".
#     A host.env that fails to parse is reported on stderr and ignored, so
#     a syntax error cannot take down a session daemon.
#
# File resolution: $DOTSWAY_HOST_ENV when set (tests, alternate layouts),
# otherwise ${XDG_CONFIG_HOME:-$HOME/.config}/sway/host.env.

HOST_ENV_KEYS=(
  COMPOSE_KEY
  WALLPAPER_DIR
  LOCK_TIMEOUT
  SCREEN_OFF_TIMEOUT
  DOTSWAY_EXT_RES
  DOTSWAY_EXT_SCALE
  DOTSWAY_EXT_ADAPTIVE_SYNC
  DOTSWAY_INTERNAL_OUTPUT
  SWAYI_DIR
)

load_host_env() {
  local f="${DOTSWAY_HOST_ENV:-${XDG_CONFIG_HOME:-$HOME/.config}/sway/host.env}"
  [[ -f "$f" ]] || return 0

  # Snapshot known keys already set (non-empty) in the environment so the
  # source below cannot clobber them: env beats host.env.
  local key
  local -a saved_keys=() saved_vals=()
  for key in "${HOST_ENV_KEYS[@]}"; do
    if [[ -n "${!key:-}" ]]; then
      saved_keys+=("$key")
      saved_vals+=("${!key}")
    fi
  done

  # shellcheck disable=SC1090
  if ! . "$f"; then
    printf 'host-env: could not parse %s; ignoring it (fix the syntax)\n' "$f" >&2
  fi

  local i
  for i in "${!saved_keys[@]}"; do
    printf -v "${saved_keys[$i]}" '%s' "${saved_vals[$i]}"
  done
}
