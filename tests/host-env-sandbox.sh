#!/usr/bin/env bash
# host-env-sandbox.sh — sandboxed assertion suite for the host.env stack:
# scripts/lib/host-env.sh (the shared loader), scripts/host-env.sh (the
# session-start snippet generator), and the WALLPAPER_DIR handling in
# scripts/rotate-wallpaper.sh.
#
# Runs against a throwaway $HOME with the repo copied in. The generator
# writes into the sandbox XDG_RUNTIME_DIR; rotate-wallpaper runs with
# SWAY_DIR pointed at the sandbox copy and SWAYSOCK blanked, so its live
# apply step can never reach a real session.
#
# Usage: host-env-sandbox.sh /path/to/repo
# Exit:  0 when every assertion passes; prints N/M summary.
set -euo pipefail

REPO="${1:?usage: host-env-sandbox.sh /path/to/repo}"
[[ -f "$REPO/scripts/lib/host-env.sh" ]] || { echo "not a repo root: $REPO" >&2; exit 2; }

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
grepq() { grep -q -e "$1" "$2" 2>/dev/null; }

SB=""
new_sandbox() { # sets SB HOME_ RUNTIME_ Sway
  SB=$(mktemp -d)
  HOME_="$SB/home"
  RUNTIME_="$SB/runtime"
  Sway="$HOME_/.config/sway"
  mkdir -p "$HOME_/.config" "$RUNTIME_" "$Sway"
  # Copy without .git and the wallpaper pool — heavy, and no suite needs the
  # real one. The rotation tests need one in-repo candidate, so fake it.
  tar -C "$REPO" --exclude=./.git --exclude=./images/wallpapers -cf - . | tar -C "$Sway" -xf -
  mkdir -p "$Sway/images/wallpapers"
  : > "$Sway/images/wallpapers/fake-inrepo.jpg"
}

# Run a repo script with the sandboxed HOME / XDG dirs / SWAY_DIR.
# SWAYSOCK is blanked on purpose: rotate-wallpaper's live apply checks it,
# and the suite may run inside a real sway session on a dev machine.
run_sandbox() { # run_sandbox <script> [args...]
  env HOME="$HOME_" XDG_CONFIG_HOME="$HOME_/.config" XDG_RUNTIME_DIR="$RUNTIME_" \
    SWAY_DIR="$Sway" SWAYSOCK="" /bin/bash "$@"
}

snippet() { printf '%s' "$RUNTIME_/sway/host_config_snippet"; }

# --- generator: scripts/host-env.sh -------------------------------------

new_sandbox
run_sandbox "$Sway/scripts/host-env.sh"
assert "generator: snippet exists without host.env" test -f "$(snippet)"
assert "generator: snippet is empty without host.env" test ! -s "$(snippet)"

new_sandbox
printf 'COMPOSE_KEY=compose:ralt\n' > "$Sway/host.env"
run_sandbox "$Sway/scripts/host-env.sh"
assert "generator: compose key rendered into the snippet" grepq '^set \$compose_key compose:ralt$' "$(snippet)"

new_sandbox
printf 'COMPOSE_KEY=compose:ralt\n' > "$Sway/host.env"
COMPOSE_KEY=compose:caps run_sandbox "$Sway/scripts/host-env.sh"
assert "generator: env var beats host.env" grepq '^set \$compose_key compose:caps$' "$(snippet)"

new_sandbox
printf "COMPOSE_KEY='compose:ralt;exec x'\n" > "$Sway/host.env"
run_sandbox "$Sway/scripts/host-env.sh" 2> "$SB/err"
assert "generator: invalid compose key warns" grepq 'invalid COMPOSE_KEY' "$SB/err"
assert "generator: invalid compose key yields an empty snippet" test ! -s "$(snippet)"

new_sandbox
printf 'COMPOSE_KEY=(\n' > "$Sway/host.env"
run_sandbox "$Sway/scripts/host-env.sh" 2> "$SB/err"
assert "generator: unparseable host.env warns" grepq 'could not parse' "$SB/err"
assert "generator: unparseable host.env yields an empty snippet" test ! -s "$(snippet)"

# --- wallpaper pool: scripts/rotate-wallpaper.sh -------------------------

new_sandbox
run_sandbox "$Sway/scripts/rotate-wallpaper.sh"
assert "wallpaper: default pool without host.env" eq "$(readlink "$Sway/images/wp.png")" "wallpapers/fake-inrepo.jpg"

new_sandbox
mkdir -p "$SB/extpool"
: > "$SB/extpool/ext-a.jpg"
printf 'WALLPAPER_DIR=%s\n' "$SB/extpool" > "$Sway/host.env"
run_sandbox "$Sway/scripts/rotate-wallpaper.sh"
assert "wallpaper: host.env pool used" eq "$(readlink "$Sway/images/wp.png")" "$SB/extpool/ext-a.jpg"

new_sandbox
mkdir -p "$SB/extpool" "$SB/envpool"
: > "$SB/extpool/ext-a.jpg"
: > "$SB/envpool/env-a.jpg"
printf 'WALLPAPER_DIR=%s\n' "$SB/extpool" > "$Sway/host.env"
WALLPAPER_DIR="$SB/envpool" run_sandbox "$Sway/scripts/rotate-wallpaper.sh"
assert "wallpaper: env var beats host.env" eq "$(readlink "$Sway/images/wp.png")" "$SB/envpool/env-a.jpg"

new_sandbox
printf 'WALLPAPER_DIR=%s\n' "$SB/does-not-exist" > "$Sway/host.env"
run_sandbox "$Sway/scripts/rotate-wallpaper.sh" 2> "$SB/err"
assert "wallpaper: missing pool dir warns" grepq 'not a directory' "$SB/err"
assert "wallpaper: missing pool dir falls back to the in-repo pool" eq "$(readlink "$Sway/images/wp.png")" "wallpapers/fake-inrepo.jpg"

printf '%d/%d assertions passed\n' "$pass" "$((pass + fail))"
[[ "$fail" -eq 0 ]]
