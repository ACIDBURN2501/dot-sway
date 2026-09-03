#!/usr/bin/env bash
#
# uninstall.sh: remove what install.sh set up, and nothing else.
#
# The install manifest (~/.local/state/sync/install-manifest) is the source
# of truth: it lists every artifact install.sh and setup-defaults.sh
# recorded, and this script removes exactly those. Installs that predate the
# manifest fall back to conservative heuristics (a symlink that points into
# this checkout, a marker-guarded block in ~/.profile).
#
# Usage: uninstall.sh [--check] [--yes]
#
#   --check   dry run: report what would be removed, change nothing
#   --yes     non-interactive: assume yes to prompts
#
# Safety rules:
#   - the ~/.config/sway symlink is removed only when it is a symlink into
#     this checkout; a real directory or checkout is never deleted
#   - a recorded file whose contents changed since install is left alone
#     unless you confirm (it may hold your edits)
#   - never touches ~/.local/share/sync/secrets, the wallpaper pool,
#     hooks.local/, host.env, or the repo checkout itself
#
# This removes the integration, not the repository. To also remove the
# checkout, delete it yourself afterwards.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$REPO_ROOT/scripts/lib/manifest.sh"

CHECK=0
ASSUME_YES=0

log()    { printf '  %s\n' "$*"; }
skip()   { printf '  ~ skip: %s\n' "$*"; }
remove() { printf '  - %s\n' "$*"; }

usage() {
  cat <<'EOF'
Usage: uninstall.sh [--check] [--yes]

Remove what install.sh set up, driven by the install manifest
(~/.local/state/sync/install-manifest) with conservative fallbacks for
pre-manifest installs. Removes the integration, not the repository.

  --check   dry run: report what would be removed, change nothing
  --yes     non-interactive: assume yes to prompts
EOF
}

confirm() {
  if [ "$ASSUME_YES" -eq 1 ] || [ "$CHECK" -eq 1 ]; then
    return 0
  fi
  local reply
  printf '%s [y/N] ' "$1" >&2
  read -r reply
  case "$reply" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

do_rm() {
  # do_rm <path>: remove a file/symlink, honouring --check.
  local path="$1"
  if [ "$CHECK" -eq 1 ]; then
    remove "would remove $path"
  else
    rm -f "$path"
    remove "removed $path"
  fi
}

# --- Artifact handlers -------------------------------------------------------

remove_sway_link() {
  echo "[sway] ~/.config/sway"
  local link="$HOME/.config/sway"
  if [ -L "$link" ]; then
    if [ "$(readlink "$link")" = "$REPO_ROOT" ]; then
      do_rm "$link"
    else
      skip "$HOME/.config/sway is a symlink to $(readlink "$link"), not this checkout; left alone"
    fi
  elif [ -d "$link/.git" ]; then
    skip "$HOME/.config/sway is a git checkout (the clone-into-place flow); left in place"
  elif [ -e "$link" ]; then
    skip "$HOME/.config/sway exists and is not a symlink; left alone"
  else
    skip "$HOME/.config/sway is absent"
  fi
}

remove_profile_block() {
  echo "[profile] ssh-agent block"
  local profile="$HOME/.profile"
  if [ ! -f "$profile" ] || ! grep -qF '# sync ssh-agent' "$profile"; then
    skip "no '# sync ssh-agent' block in ~/.profile"
    return 0
  fi
  if [ "$CHECK" -eq 1 ]; then
    remove "would remove the '# sync ssh-agent' block from ~/.profile"
    return 0
  fi
  # The block provision.sh appends is exactly two lines: the marker comment
  # and one export line. Filter both out (plus the blank line that precedes
  # the marker), leaving the rest of ~/.profile byte-identical.
  local tmp
  tmp="$(mktemp)"
  grep -v -F '# sync ssh-agent' "$profile" \
    | grep -v -F '[ -n "${SSH_AUTH_SOCK:-}" ] || export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR:-/tmp}/ssh-agent.socket"' \
    > "$tmp" || true
  # Drop a trailing blank line left where the block was appended.
  sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$tmp" 2>/dev/null || true
  mv "$tmp" "$profile"
  remove "removed the ssh-agent block from ~/.profile"
}

remove_environment_conf() {
  echo "[environment.d] ssh-agent socket export"
  local conf="$HOME/.config/environment.d/20-ssh-agent.conf"
  if [ -f "$conf" ]; then
    do_rm "$conf"
  else
    skip "environment.d/20-ssh-agent.conf absent"
  fi
}

remove_ssh_agent_unit() {
  echo "[user unit] ssh-agent.service"
  local unit="$HOME/.config/systemd/user/ssh-agent.service"
  local src="$REPO_ROOT/bootstrap/user/systemd/ssh-agent.service"
  if [ ! -f "$unit" ]; then
    skip "ssh-agent.service not installed for the user"
    return 0
  fi
  # Attribute before removing: only delete the unit when it is the one this
  # repo installed (identical to the shipped copy). A differing unit may be
  # the user's own or the distro's.
  if [ -f "$src" ] && cmp -s "$unit" "$src"; then
    if [ "$CHECK" -eq 1 ]; then
      remove "would remove ssh-agent.service (matches the repo's unit) and disable it"
      return 0
    fi
    systemctl --user disable ssh-agent.service >/dev/null 2>&1 || true
    rm -f "$unit"
    systemctl --user daemon-reload 2>/dev/null || true
    remove "removed ssh-agent.service"
  else
    skip "ssh-agent.service differs from the repo's unit; left alone (remove manually if it is ours)"
  fi
}

remove_swhkd() {
  echo "[swhkd] rendered media-key config"
  local dst="$HOME/.config/swhkd/swhkdrc"
  if [ -f "$dst" ]; then
    do_rm "$dst"
    # Remove the directory only if we emptied it.
    rmdir "$HOME/.config/swhkd" 2>/dev/null || true
  else
    skip "$HOME/.config/swhkd/swhkdrc absent"
  fi
}

# Manifest-recorded plain files (setup-defaults output, rendered swhkdrc).
# honour checksums: a file that changed since install may hold user edits.
remove_manifest_files() {
  local type path detail
  manifest_lines | while IFS=$'\t' read -r type path detail; do
    [ "$type" = "file" ] || continue
    case "$path" in
      # handled by their own handlers above
      "$HOME/.config/swhkd/swhkdrc"|"$HOME/.config/environment.d/20-ssh-agent.conf") continue ;;
    esac
    [ -f "$path" ] || continue
    if [ "$detail" = "modified-by-setup-defaults" ]; then
      # mimeapps.list accumulates user changes; never auto-remove.
      skip "$path may hold your MIME edits; left alone (remove manually if unwanted)"
      continue
    fi
    if [ -n "$detail" ] && [ "$(sha256sum "$path" | cut -d' ' -f1)" != "$detail" ]; then
      # Changed since install: it may hold user edits. Under --yes (and
      # --check) keep it; never auto-delete something the user touched.
      if [ "$ASSUME_YES" -eq 1 ] || [ "$CHECK" -eq 1 ]; then
        skip "$path (changed since install; kept, remove manually if unwanted)"
      elif confirm "$path changed since install; remove anyway?"; then
        do_rm "$path"
      else
        skip "$path (changed since install)"
      fi
    else
      do_rm "$path"
    fi
  done
}

# --- Main --------------------------------------------------------------------

main() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --check) CHECK=1 ;;
      --yes|-y) ASSUME_YES=1 ;;
      --help|-h) usage; exit 0 ;;
      *) printf 'unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
  done

  printf 'uninstall.sh: %s\n' "$REPO_ROOT"
  [ "$CHECK" -eq 1 ] && printf '(dry run — nothing will change)\n'
  if [ -f "$MANIFEST_FILE" ]; then
    log "using install manifest: $MANIFEST_FILE"
  else
    skip "no install manifest; falling back to probes (pre-manifest install)"
  fi

  if [ "$CHECK" -eq 0 ] && ! confirm 'Proceed with uninstall?'; then
    echo 'aborted'
    exit 0
  fi

  remove_sway_link
  remove_profile_block
  remove_environment_conf
  remove_ssh_agent_unit
  remove_swhkd
  remove_manifest_files

  echo
  skip "left untouched: ~/.local/share/sync/secrets, the wallpaper pool, hooks.local/, host.env, and this checkout"
  if [ "$CHECK" -eq 1 ]; then
    echo 'uninstall.sh: dry run done'
  else
    echo 'uninstall.sh: done. The repository itself is left in place; delete it manually if unwanted.'
  fi
}

main "$@"
