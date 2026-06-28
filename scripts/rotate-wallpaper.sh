#!/usr/bin/env bash
# rotate-wallpaper.sh
# Pick a random image from images/wallpapers/ and apply it as the desktop
# background. Repoints the images/wp.png symlink (used by `output * bg` and
# swaylock) and applies the change live via swaymsg.
#
# Empty folder → no-op. Run from sway via `exec_always` so every reload picks
# fresh.
set -euo pipefail

SWAY_DIR="${SWAY_DIR:-$HOME/.config/sway}"
WALLPAPER_DIR="$SWAY_DIR/images/wallpapers"
LINK="$SWAY_DIR/images/wp.png"
SKIP_MARKER="/tmp/sway_skip_wallpaper_rotation"

# Theme toggles reload sway to re-apply colors, which would otherwise rotate the
# wallpaper too. toggle_theme.sh drops this marker so we skip rotation on that
# reload; sway still re-applies the current wp.png via `output * bg`. The marker
# is consumed here so the next genuine reload rotates as normal.
if [[ -e "$SKIP_MARKER" ]]; then
  rm -f "$SKIP_MARKER"
  exit 0
fi

[[ -d "$WALLPAPER_DIR" ]] || exit 0

mapfile -d '' -t candidates < <(
  find "$WALLPAPER_DIR" -maxdepth 1 -type f \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) -print0
)

[[ "${#candidates[@]}" -gt 0 ]] || exit 0

pick="${candidates[RANDOM % ${#candidates[@]}]}"

# Relative symlink target keeps the link portable across machines.
ln -sfn "wallpapers/$(basename "$pick")" "$LINK"

# Apply live if sway IPC is reachable. On cold boot the socket may not exist
# yet — sway will pick up the symlink when it processes `output * bg` itself.
if [[ -n "${SWAYSOCK:-}" ]] && command -v swaymsg >/dev/null 2>&1; then
  swaymsg "output * bg $LINK fill" >/dev/null 2>&1 || true
fi
