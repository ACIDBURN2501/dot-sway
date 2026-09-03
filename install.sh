#!/usr/bin/env bash
#
# install.sh: set up this Sway desktop on an existing machine. A thin
# preflight plus delegation — every mutating step is an existing idempotent
# stage from bootstrap/provision.sh or scripts/setup-defaults.sh, so this
# adds an entry point, not a parallel implementation.
#
# For a fresh machine (zero → online), use bootstrap/provision.sh instead;
# see bootstrap/README.md.
#
# Usage: install.sh [--check] [--yes] [git-ref]
#
#   --check   dry run: report what would happen, change nothing
#   --yes     non-interactive: assume yes to prompts
#   git-ref   optional tag/branch/commit to check out first (rollback pin)
#
# What it does, in order:
#   1. probe the distro and the core dependency set (sway, waybar, jq)
#   2. optionally check out git-ref
#   3. run the provision stages: packages user-units portals sway
#   4. run scripts/setup-defaults.sh (terminal, MIME, portal defaults)
#   5. render the swhkd media-key template when the swhkd binary is present
#   6. record every artifact it creates in the install manifest
#      (~/.local/state/sync/install-manifest) so uninstall.sh can remove
#      exactly what was added
#
# Conventions follow AGENTS.md: probe, don't assume; a missing tool or
# feature degrades to a skip, not an error.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$REPO_ROOT/scripts/lib/manifest.sh"

CHECK=0
ASSUME_YES=0
GIT_REF=""

log()  { printf '  %s\n' "$*"; }
skip() { printf '  ~ skip: %s\n' "$*"; }
warn() { printf '  ! %s\n' "$*" >&2; }

usage() {
  cat <<'EOF'
Usage: install.sh [--check] [--yes] [git-ref]

Set up this Sway desktop on an existing machine by delegating to the
existing idempotent provision stages. For a fresh machine, use
bootstrap/provision.sh (see bootstrap/README.md).

  --check   dry run: report what would happen, change nothing
  --yes     non-interactive: assume yes to prompts
  git-ref   optional tag/branch/commit to check out first (rollback pin)
EOF
}

confirm() {
  # confirm <prompt> — return 0 to proceed. Always yes under --yes/--check.
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

# --- Preflight ---------------------------------------------------------------

detect_distro() {
  local id
  id="$(grep -m1 '^ID=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')"
  case "$id" in
    arch)   DISTRO="arch" ;;
    debian) DISTRO="debian" ;;
    *)      DISTRO="unknown" ;;
  esac
}

preflight() {
  echo "[preflight]"
  detect_distro
  case "$DISTRO" in
    arch|debian) log "distro: $DISTRO" ;;
    *) warn "distro: unsupported ($(grep -m1 '^ID=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')); packages/portal stages will skip" ;;
  esac

  # Core set the desktop cannot start without. Everything else degrades.
  local missing=() tool
  for tool in sway waybar jq; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    warn "missing core tools: ${missing[*]}"
    warn "install them via the packages stage (run: bootstrap/provision.sh packages) or your package manager"
  else
    log "core tools present: sway waybar jq"
  fi

  # Refuse to clobber an unrelated ~/.config/sway.
  if [ -e "$HOME/.config/sway" ] && [ ! -L "$HOME/.config/sway" ] && [ ! -d "$HOME/.config/sway/.git" ]; then
    warn "$HOME/.config/sway exists and is neither a symlink nor a git checkout"
    warn "move it aside before installing; the sway stage will not touch it"
  fi
}

# --- Steps -------------------------------------------------------------------

checkout_ref() {
  [ -n "$GIT_REF" ] || return 0
  echo "[checkout] $GIT_REF"
  if [ "$CHECK" -eq 1 ]; then
    log "would git -C $REPO_ROOT checkout $GIT_REF"
    return 0
  fi
  git -C "$REPO_ROOT" checkout "$GIT_REF"
}

run_provision() {
  echo "[provision] packages user-units portals sway"
  if [ "$CHECK" -eq 1 ]; then
    bash "$REPO_ROOT/bootstrap/provision.sh" --check packages user-units portals sway
  else
    bash "$REPO_ROOT/bootstrap/provision.sh" packages user-units portals sway
  fi
}

run_setup_defaults() {
  echo "[defaults] terminal, MIME, portal defaults"
  if [ "$CHECK" -eq 1 ]; then
    log "would run scripts/setup-defaults.sh (records its artifacts in the manifest)"
    return 0
  fi
  bash "$REPO_ROOT/scripts/setup-defaults.sh"
}

render_swhkd() {
  echo "[swhkd] media-key fallback"
  if ! command -v swhkd >/dev/null 2>&1; then
    skip "swhkd not installed; not rendering the media-key config"
    return 0
  fi
  local dst="$HOME/.config/swhkd/swhkdrc"
  if [ "$CHECK" -eq 1 ]; then
    log "would render extra/swhkd/swhkdrc -> $dst"
    return 0
  fi
  mkdir -p "$HOME/.config/swhkd"
  sed "s|__SWAY_HOME__|$HOME|" "$REPO_ROOT/extra/swhkd/swhkdrc" > "$dst"
  manifest_add file "$dst" "$(sha256sum "$dst" | cut -d' ' -f1)"
  log "rendered $dst"
}

# Record the artifacts install.sh itself is responsible for. The provision
# stages are idempotent and their artifacts are recorded on uninstall by
# probe (pre-manifest installs predate the manifest); what we record here is
# what install.sh directly creates or can attribute cheaply.
record_manifest() {
  [ "$CHECK" -eq 1 ] && return 0
  # The sway stage's symlink (only when it points at this checkout).
  if [ -L "$HOME/.config/sway" ] && [ "$(readlink "$HOME/.config/sway")" = "$REPO_ROOT" ]; then
    manifest_add symlink "$HOME/.config/sway" "$REPO_ROOT"
  fi
  # The user-units stage's marker-guarded profile block.
  if [ -f "$HOME/.profile" ] && grep -qF '# sync ssh-agent' "$HOME/.profile"; then
    manifest_add marker "$HOME/.profile" "# sync ssh-agent"
  fi
  # The user-units stage's environment.d export (only when we installed the unit).
  if [ -f "$HOME/.config/environment.d/20-ssh-agent.conf" ]; then
    manifest_add file "$HOME/.config/environment.d/20-ssh-agent.conf" \
      "$(sha256sum "$HOME/.config/environment.d/20-ssh-agent.conf" | cut -d' ' -f1)"
  fi
}

# --- Main --------------------------------------------------------------------

main() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --check) CHECK=1 ;;
      --yes|-y) ASSUME_YES=1 ;;
      --help|-h) usage; exit 0 ;;
      -*) printf 'unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
      *) GIT_REF="$1" ;;
    esac
    shift
  done

  printf 'install.sh: %s\n' "$REPO_ROOT"
  [ "$CHECK" -eq 1 ] && printf '(dry run — nothing will change)\n'

  preflight
  if [ "$CHECK" -eq 0 ] && ! confirm 'Proceed with install?'; then
    echo 'aborted'
    exit 0
  fi
  checkout_ref
  run_provision
  run_setup_defaults
  render_swhkd
  record_manifest

  echo
  if [ "$CHECK" -eq 1 ]; then
    echo 'install.sh: dry run done'
  else
    echo "install.sh: done. Log into the Sway session; config.d/waybar and the hooks start automatically."
    echo "Artifacts recorded in $MANIFEST_FILE (uninstall.sh removes exactly these)."
  fi
}

main "$@"
