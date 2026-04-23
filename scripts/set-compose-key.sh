#!/usr/bin/env bash
set -euo pipefail

# Default compose key if DOTSWAY_COMPOSE_KEY is not set
DEFAULT_COMPOSE_KEY="compose:rwin"
COMPOSE_KEY="${DOTSWAY_COMPOSE_KEY:-$DEFAULT_COMPOSE_KEY}"

# Use swaymsg to set the xkb_options for all keyboards
# We use a loop in case there are multiple keyboards, although type:keyboard usually targets all.
swaymsg input "type:keyboard" xkb_options "$COMPOSE_KEY"
