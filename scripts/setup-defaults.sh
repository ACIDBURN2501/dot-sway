#!/usr/bin/env bash
#
# setup-defaults.sh: Configure XDG defaults for a Sway session on a
# GNOME-based distro (default terminal, MIME associations, desktop portals).
#
# Idempotent. The user-level steps run without root; anything needing root
# (apt, update-alternatives) is printed as a copy-paste block rather than
# executed. Re-run any time; it only writes what is missing or wrong.
#
# Inputs:  none (edit the constants below to change the preferred terminal
#          or MIME map).
# Outputs: ~/.config/xdg-terminals.list, ~/.config/environment.d/10-terminal.conf,
#          ~/.config/mimeapps.list (via xdg-mime), a GNOME gsettings key.
#
# See docs/xdg-defaults.md for the full rationale.

set -euo pipefail

# --- Constants ---------------------------------------------------------------

TERMINAL_CMD="kitty"                 # binary + $TERMINAL value + gsettings exec
TERMINAL_DESKTOP="kitty.desktop"     # Desktop Entry ID for xdg-terminals.list

# MIME type -> preferred Desktop Entry ID. Applied only if the target is
# installed; missing apps are skipped, not forced.
declare -A MIME_MAP=(
  ["text/plain"]="org.gnome.TextEditor.desktop"
  ["text/markdown"]="org.gnome.TextEditor.desktop"
  ["application/x-shellscript"]="org.gnome.TextEditor.desktop"
  ["application/pdf"]="org.gnome.Evince.desktop"
  ["image/png"]="org.gnome.Loupe.desktop"
  ["image/jpeg"]="org.gnome.Loupe.desktop"
  ["image/gif"]="org.gnome.Loupe.desktop"
  ["image/webp"]="org.gnome.Loupe.desktop"
  ["image/tiff"]="org.gnome.Loupe.desktop"
  ["image/bmp"]="org.gnome.Loupe.desktop"
  ["image/svg+xml"]="org.gnome.Loupe.desktop"
)

# --- Helpers -----------------------------------------------------------------

log()  { printf '  %s\n' "$*"; }
skip() { printf '  ~ skip: %s\n' "$*"; }

# Locate a .desktop by ID across the standard application directories.
desktop_exists() {
  local id="$1" dir
  for dir in "$HOME/.local/share/applications" /usr/local/share/applications /usr/share/applications; do
    [ -f "$dir/$id" ] && return 0
  done
  return 1
}

# --- Steps -------------------------------------------------------------------

set_terminal() {
  echo "[terminal] preferred = $TERMINAL_CMD"

  if ! command -v "$TERMINAL_CMD" >/dev/null 2>&1; then
    skip "$TERMINAL_CMD not on PATH; install it, then re-run"
    return 0
  fi

  # 1. freedesktop / GLib default (xdg-terminal-exec spec)
  printf '%s\n' "$TERMINAL_DESKTOP" > "$HOME/.config/xdg-terminals.list"
  log "xdg-terminals.list -> $TERMINAL_DESKTOP"

  # 2. $TERMINAL for xdg-terminal-exec fallback and TERMINAL-aware tools
  mkdir -p "$HOME/.config/environment.d"
  printf '# Preferred terminal for xdg-terminal-exec and $TERMINAL-aware tools.\nTERMINAL=%s\n' \
    "$TERMINAL_CMD" > "$HOME/.config/environment.d/10-terminal.conf"
  log "environment.d/10-terminal.conf -> TERMINAL=$TERMINAL_CMD"

  # 3. GNOME legacy key (used by some GNOME components under the fallback session)
  if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.default-applications.terminal exec "$TERMINAL_CMD"
    gsettings set org.gnome.desktop.default-applications.terminal exec-arg '-e'
    log "gsettings default-applications.terminal -> $TERMINAL_CMD"
  else
    skip "gsettings absent; GNOME legacy terminal key not set"
  fi
}

set_mime_defaults() {
  echo "[mime] default applications"
  if ! command -v xdg-mime >/dev/null 2>&1; then
    skip "xdg-mime absent; cannot set MIME defaults"
    return 0
  fi
  local mime app
  for mime in "${!MIME_MAP[@]}"; do
    app="${MIME_MAP[$mime]}"
    if desktop_exists "$app"; then
      xdg-mime default "$app" "$mime"
      log "$mime -> $app"
    else
      skip "$mime: $app not installed"
    fi
  done
}

print_root_steps() {
  echo "[root] the following need root and are NOT run by this script:"
  cat <<EOF

  # Screenshot / screencast portal for wlroots (sway-portals.conf wants wlr;gtk):
  sudo apt install xdg-desktop-portal-wlr

  # Debian 'x-terminal-emulator' alternative -> $TERMINAL_CMD:
  sudo update-alternatives --set x-terminal-emulator /usr/bin/$TERMINAL_CMD

  # Nautilus "Open in Terminal" (the stock extension is hardwired to gnome-terminal).
  # It's a Python extension loaded by the SYSTEM python3, so install --user -- NOT
  # pipx/uv tool, whose isolated venvs Nautilus can't import from.
  sudo apt remove nautilus-extension-gnome-terminal
  sudo apt install python3-nautilus gir1.2-gtk-4.0 python3-pip
  pip install --user --break-system-packages nautilus-open-any-terminal
  glib-compile-schemas ~/.local/share/glib-2.0/schemas/
  gsettings set com.github.stunkymonkey.nautilus-open-any-terminal terminal $TERMINAL_CMD
  nautilus -q

EOF
}

# --- Main --------------------------------------------------------------------

main() {
  set_terminal
  set_mime_defaults
  print_root_steps
  echo "Done. Log out/in (or restart the session) for TERMINAL and portals to take full effect."
}

main "$@"
