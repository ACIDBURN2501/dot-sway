#!/usr/bin/env bash
# theme-sandbox.sh — sandboxed assertion suite for scripts/toggle_theme.sh
#
# Runs the script against a throwaway $HOME with the repo copied in (never a
# symlink — .theme_state and friends must not leak into the real tree), with
# every session-external binary stubbed and SWAYSOCK unset. The notify-send
# stub exits 1 on purpose: a Sway desktop without a notification daemon is a
# normal state, and the script must survive it with exit 0.
#
# Usage: theme-sandbox.sh /path/to/repo
# Exit:  0 when every assertion passes; prints N/M summary.
set -euo pipefail

REPO="${1:?usage: theme-sandbox.sh /path/to/repo}"
[[ -f "$REPO/scripts/toggle_theme.sh" ]] || { echo "not a repo root: $REPO" >&2; exit 2; }

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
has() { grep -q "$2" "$1" 2>/dev/null; }
link_to() { [[ "$(readlink "$1" 2>/dev/null)" == "$2" ]]; }
same_as() { cmp -s "$1" "$2" 2>/dev/null; }

SB=""
new_sandbox() { # sets HOME_ RUNTIME_ BIN_ GNOME_LOG_
  SB=$(mktemp -d)
  HOME_="$SB/home"
  RUNTIME_="$SB/runtime"
  BIN_="$SB/bin"
  GNOME_LOG_="$SB/gsettings.log"
  Sway="$HOME_/.config/sway"
  mkdir -p "$HOME_/.config" "$RUNTIME_" "$BIN_"
  cp -a "$REPO" "$HOME_/.config/sway"
  # gsettings is stubbed too: the host's real one would make GNOME the
  # source of truth and let the host's actual theme drive the run.
  for b in swaymsg pkill gsettings kitty notify-send mako makoctl pgrep; do
    printf '#!/bin/sh\nexit 1\n' > "$BIN_/$b"
    chmod +x "$BIN_/$b"
  done
  # The repo's working tree carries an untracked .theme_state; drop it so
  # the sandbox really is a fresh box.
  rm -f "$Sway/.theme_state"
}
install_gnome_stub() { # gsettings stub that pretends GNOME is in dark mode
  cat > "$BIN_/gsettings" <<EOF
#!/bin/sh
echo "gsettings \$*" >> "$GNOME_LOG_"
if [[ "\${1-}" == get && "\${3-}" == color-scheme ]]; then
  echo "string 'prefer-dark'"
  exit 0
fi
exit 0
EOF
  chmod +x "$BIN_/gsettings"
}
run_tts() { # run_tts <args...> → sets RC and OUT (stdout)
  OUT=$(env -u SWAYSOCK HOME="$HOME_" XDG_RUNTIME_DIR="$RUNTIME_" PATH="$BIN_:$PATH" \
    bash "$HOME_/.config/sway/scripts/toggle_theme.sh" "$@" 2>/dev/null) && RC=0 || RC=$?
}
cleanup() { [[ -n "$SB" ]] && rm -rf "$SB"; }
trap cleanup EXIT

# ---------------------------------------------------------------- S1: init, fresh box
new_sandbox
run_tts init
assert "init exits 0"                 eq "$RC" 0
assert "init does not create .theme_state" bash -c "[[ ! -f '$HOME_/.config/sway/.theme_state' ]]"
assert "init writes dark sway_theme_config" has "$RUNTIME_/sway/sway_theme_config" 'set $bg_color #323232'
assert "init links waybar dark palette"  link_to "$Sway/waybar/colors.css" "colors-dark.css"
assert "init links wofi dark style"     link_to "$HOME_/.config/wofi/style.css" "$Sway/extra/wofi/style-dark.css"
# NOTE: the doubled themes/themes/ staging dir below is a known oddity;
# see the kitty section of extra/EXTRA.md. A fix is drafted in the project queue.
assert "init seeds user kitty.conf"     same_as "$HOME_/.config/kitty/kitty.conf" "$Sway/extra/kitty/kitty.conf"
assert "init seeds kitty moon theme"    same_as "$HOME_/.config/kitty/themes/themes/tokyo_night_moon.conf" "$Sway/extra/kitty/themes/tokyo_night_moon.conf"
assert "init sets current-theme=moon"   same_as "$HOME_/.config/kitty/current-theme.conf" "$HOME_/.config/kitty/themes/themes/tokyo_night_moon.conf"
assert "init seeds managed mako config" same_as "$HOME_/.config/mako/config" "$Sway/extra/mako/config-dark"

# ------------------------------------------------- S2: toggle dark→light (notify-send fails)
run_tts toggle
assert "toggle exits 0 despite failing notify-send" eq "$RC" 0
assert "toggle flips state to light"  eq "$(cat "$HOME_/.config/sway/.theme_state")" "light"
assert "toggle writes light config"   has "$RUNTIME_/sway/sway_theme_config" 'set $bg_color #f0f0f0'
assert "toggle links waybar light"    link_to "$Sway/waybar/colors.css" "colors-light.css"
assert "toggle links wofi light"      link_to "$HOME_/.config/wofi/style.css" "$Sway/extra/wofi/style-light.css"
assert "toggle sets current-theme=day" same_as "$HOME_/.config/kitty/current-theme.conf" "$HOME_/.config/kitty/themes/themes/tokyo_night_day.conf"

# ---------------------------------------------------------- S3: round trip back to dark
run_tts toggle
assert "round trip returns to dark" eq "$(cat "$HOME_/.config/sway/.theme_state")" "dark"
assert "round trip sets current-theme=moon" same_as "$HOME_/.config/kitty/current-theme.conf" "$HOME_/.config/kitty/themes/themes/tokyo_night_moon.conf"

# ----------------------------------------------------------------------- S4: get
run_tts get
assert "get prints current theme" eq "$OUT" "dark"

# ------------------------------------- S5: user-customised mako config is never clobbered
new_sandbox
mkdir -p "$HOME_/.config/mako"
echo "user-custom mako" > "$HOME_/.config/mako/config"
run_tts toggle
assert "user mako config untouched" eq "$(cat "$HOME_/.config/mako/config")" "user-custom mako"

# ------------------------------------------------ S6: managed mako config keeps tracking theme
new_sandbox
mkdir -p "$HOME_/.config/mako"
cp "$Sway/extra/mako/config-dark" "$HOME_/.config/mako/config"
run_tts toggle
assert "managed mako config follows to light" same_as "$HOME_/.config/mako/config" "$Sway/extra/mako/config-light"

# --------------------------------------------------- S7: user-authored kitty.conf is never touched
new_sandbox
mkdir -p "$HOME_/.config/kitty"
echo "custom kitty.conf" > "$HOME_/.config/kitty/kitty.conf"
run_tts toggle
assert "user kitty.conf untouched" eq "$(cat "$HOME_/.config/kitty/kitty.conf")" "custom kitty.conf"
assert "current-theme still updated for user kitty" same_as "$HOME_/.config/kitty/current-theme.conf" "$HOME_/.config/kitty/themes/themes/tokyo_night_day.conf"

# ------------------------------------------------ S8: user-installed kitty theme wins over repo copy
new_sandbox
mkdir -p "$HOME_/.config/kitty/themes/themes"
echo "user moon theme" > "$HOME_/.config/kitty/themes/themes/tokyo_night_moon.conf"
run_tts init
assert "user kitty theme wins" eq "$(cat "$HOME_/.config/kitty/current-theme.conf")" "user moon theme"

# ---------------------------------------------------------------- S9: bad usage
new_sandbox
run_tts bogus
assert "unknown arg exits non-zero" bash -c "[[ $RC -ne 0 ]]"

# ------------------------------------- S10: GNOME present → gsettings is source of truth
new_sandbox
install_gnome_stub
run_tts get
assert "get queried gnome color-scheme" bash -c "grep -q 'gsettings get org.gnome.desktop.interface color-scheme' \"$GNOME_LOG_\""
run_tts toggle
assert "toggle asks gnome for prefer-light" bash -c "grep -q 'set org.gnome.desktop.interface color-scheme prefer-light' \"$GNOME_LOG_\""
assert "toggle asks gnome for Adwaita"      bash -c "grep -q 'set org.gnome.desktop.interface gtk-theme Adwaita' \"$GNOME_LOG_\""
assert "state file tracks the gnome flip"   eq "$(cat "$HOME_/.config/sway/.theme_state")" "light"

echo
echo "$pass/$((pass + fail)) assertions passed"
[[ "$fail" -eq 0 ]]
