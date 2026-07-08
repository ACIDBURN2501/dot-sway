#!/usr/bin/env bash
# rotate-wallpaper.sh
# Pick a random image from images/wallpapers/ and apply it as the desktop
# background. Repoints the images/wp.png symlink (used by `output * bg` and
# swaylock) and applies the change live via swaymsg.
#
# Empty/absent pool → fall back to the committed images/default.png so wp.png
# always resolves (never a black desktop or a broken swaylock image), unless a
# wallpaper is already set. Rotation is on-demand — bound to $mod+Shift+w. With
# --if-unset the script only acts when wp.png isn't already a valid wallpaper,
# so start/reload (config.d/wallpaper) bootstrap one on first run but leave an
# existing wallpaper in place.
set -euo pipefail

# --if-unset: no-op when wp.png already resolves to an existing file. Used by
# config.d/wallpaper so start/reload only set a wallpaper when none is present,
# letting the chosen wallpaper persist until an explicit rotate.
IF_UNSET=0
[[ "${1:-}" == "--if-unset" ]] && IF_UNSET=1

SWAY_DIR="${SWAY_DIR:-$HOME/.config/sway}"
WALLPAPER_DIR="$SWAY_DIR/images/wallpapers"
LINK="$SWAY_DIR/images/wp.png"
DEFAULT="$SWAY_DIR/images/default.png"   # committed fallback when the pool is empty

# Machine-local pool override — wallpaper_dir.local (gitignored, like
# compose_key.local) holds one path to an external wallpaper folder.
# Absent file → the in-repo images/wallpapers/ pool above.
# First non-blank, non-comment line is the path (~ is expanded).
OVERRIDE_FILE="$SWAY_DIR/wallpaper_dir.local"
if [[ -f "$OVERRIDE_FILE" ]]; then
  override="$(grep -m1 -v -e '^[[:space:]]*#' -e '^[[:space:]]*$' "$OVERRIDE_FILE" || true)"
  [[ -n "$override" ]] && WALLPAPER_DIR="${override/#\~/$HOME}"
fi

# In --if-unset (start/reload) mode, leave an already-set wallpaper alone so it
# persists until the user explicitly rotates with $mod+Shift+w. `-e` follows the
# symlink, so a missing or dangling wp.png still triggers a first pick.
if [[ "$IF_UNSET" -eq 1 && -e "$LINK" ]]; then
  exit 0
fi

# Apply the current wp.png live if sway IPC is reachable. On cold boot the socket
# may not exist yet — sway picks up the symlink when it processes `output * bg`.
apply_bg() {
  if [[ -n "${SWAYSOCK:-}" ]] && command -v swaymsg >/dev/null 2>&1; then
    swaymsg "output * bg $LINK fill" >/dev/null 2>&1 || true
  fi
}

# Gather candidates from the pool (stays empty if the dir is absent).
candidates=()
if [[ -d "$WALLPAPER_DIR" ]]; then
  mapfile -d '' -t candidates < <(
    find "$WALLPAPER_DIR" -maxdepth 1 -type f \
      \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) -print0
  )
fi

# Empty/absent pool: keep an already-set wallpaper; otherwise fall back to the
# committed default so wp.png always resolves. Both live in images/, so the link
# stays relative and portable.
if [[ "${#candidates[@]}" -eq 0 ]]; then
  [[ -e "$LINK" ]] && exit 0
  [[ -e "$DEFAULT" ]] || exit 0
  ln -sfn "default.png" "$LINK"
  apply_bg
  exit 0
fi

pick="${candidates[RANDOM % ${#candidates[@]}]}"

# In-repo pool → relative target (portable across machines); external
# override dir → absolute path is the only option.
if [[ "$pick" == "$SWAY_DIR/images/wallpapers/"* ]]; then
  ln -sfn "wallpapers/$(basename "$pick")" "$LINK"
else
  ln -sfn "$pick" "$LINK"
fi

apply_bg
