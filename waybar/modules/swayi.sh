#!/usr/bin/env bash
# swayi.sh: delegator for the swayi usage pill (AI session/weekly numbers).
#
# The swayi tool lives in its own checkout, not in this repo. This module is
# the stable path config.jsonc points at: it resolves SWAYI_DIR (env var >
# host.env, see host.env.example) and, when a swayi checkout is present,
# execs its waybar module with every argument passed through (the no-arg
# poll prints the pill JSON; "refresh" re-collects and signals waybar).
# exec preserves the PID, so waybar's signal 8 reaches the external script.
#
# When SWAYI_DIR is unset or the checkout is absent, this prints nothing and
# exits 0: waybar hides the pill, and the menu (waybar/menus/swayi.xml) is
# only reachable by clicking the pill, so nothing dangles.
set -euo pipefail

SWAY_DIR="${SWAY_DIR:-$HOME/.config/sway}"
# shellcheck disable=SC1091
. "$SWAY_DIR/scripts/lib/host-env.sh"
DOTSWAY_HOST_ENV="${DOTSWAY_HOST_ENV:-$SWAY_DIR/host.env}"
load_host_env

MODULE="${SWAYI_DIR:-}/waybar/modules/swayi.sh"
if [[ -n "${SWAYI_DIR:-}" && -x "$MODULE" ]]; then
  exec "$MODULE" "$@"
fi
exit 0
