#!/usr/bin/env bash
#
# provision.sh: bring a machine (fresh or drifted) to the state this repo
# describes. Stages are idempotent by construction — re-run any time, or
# pass stage names to run a subset.
#
# Usage: bootstrap/provision.sh [stage ...]
#
#   Stages (run in this order when none are given):
#     pacman      install packages from bootstrap/packages/pacman.txt
#     aur         build AUR packages from bootstrap/packages/aur.txt (needs yay)
#     flatpak     install apps from bootstrap/packages/flatpak.txt
#     services    iwd, ufw (SSH rate-limited first), sshd, snapper (btrfs only)
#     sway        verify/refresh ~/.config/sway (never clones from inside itself)
#     user-units  ssh-agent user unit + SSH_AUTH_SOCK via environment.d
#     portals     ensure the wlr + gtk portal backends are present
#     secrets     decrypt bootstrap/secrets/*.age (see bootstrap/secrets/README.md)
#     tailscale   join the tailnet when secrets/tailscale_authkey is present
#
# Conventions follow AGENTS.md: probe, don't assume. A missing tool or
# feature degrades to a skip, not an error.
#
# See bootstrap/README.md for the zero-to-online flow.

set -euo pipefail

# --- Constants ---------------------------------------------------------------

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECRETS_DIR="$HOME/.local/share/dot-sway/secrets"
USER_UNIT_SRC="$REPO_ROOT/bootstrap/user/systemd"
USER_UNIT_DST="$HOME/.config/systemd/user"

ALL_STAGES=(pacman aur flatpak services sway user-units portals secrets tailscale)

# --- Helpers -----------------------------------------------------------------

log()  { printf '  %s\n' "$*"; }
skip() { printf '  ~ skip: %s\n' "$*"; }

# Non-empty, comment-stripped lines of a manifest file.
manifest() {
  grep -vE '^[[:space:]]*(#|$)' "$REPO_ROOT/bootstrap/packages/$1" || true
}

# --- Stages ------------------------------------------------------------------

stage_pacman() {
  local list
  list="$(manifest pacman.txt)"
  if [ -z "$list" ]; then skip "pacman: no manifest or empty"; return 0; fi
  log "pacman: installing packages from packages/pacman.txt"
  printf '%s\n' "$list" | sudo pacman -S --needed -
}

stage_aur() {
  command -v yay >/dev/null 2>&1 || { skip "aur: yay not installed (see packages/pacman.txt)"; return 0; }
  local list
  list="$(manifest aur.txt)"
  if [ -z "$list" ]; then skip "aur: no manifest or empty"; return 0; fi
  log "aur: building $(printf '%s\n' "$list" | wc -l) packages (this can take a while)"
  # shellcheck disable=SC2086  # word-splitting the manifest into args is intended
  yay -S --needed --noconfirm $list
}

stage_flatpak() {
  command -v flatpak >/dev/null 2>&1 || { skip "flatpak: not installed"; return 0; }
  local list
  list="$(manifest flatpak.txt)"
  if [ -z "$list" ]; then skip "flatpak: no manifest or empty"; return 0; fi
  log "flatpak: installing apps from packages/flatpak.txt"
  # shellcheck disable=SC2086  # word-splitting the manifest into args is intended
  flatpak install -y --non-interactive $list
}

stage_services() {
  log "services: network, firewall, ssh, snapshots"

  # Wi-Fi via iwd (pairs with impala in scripts/network-tui.sh). If you prefer
  # NetworkManager instead, swap this for:
  #   sudo systemctl enable --now NetworkManager
  # Do not run both — they conflict.
  if command -v iwd >/dev/null 2>&1; then
    sudo systemctl enable --now iwd
  else
    skip "services: iwd not installed (run the pacman stage)"
  fi

  # Firewall: rate-limit SSH *before* enabling, otherwise a remote
  # provisioning session loses the port it is using.
  if command -v ufw >/dev/null 2>&1; then
    sudo ufw limit 22/tcp
    sudo ufw --force enable
    log "services: ufw enabled (SSH rate-limited)"
  else
    skip "services: ufw not installed (run the pacman stage)"
  fi

  # SSH must survive reboots — it is how remote provisioning happens.
  if command -v sshd >/dev/null 2>&1; then
    sudo systemctl enable --now sshd
  else
    skip "services: sshd not installed"
  fi

  # Btrfs only: snapshot the system so a bad change is a restore away.
  local fs
  fs="$(findmnt -no FSTYPE / || true)"
  if [ "$fs" = "btrfs" ] && command -v snapper >/dev/null 2>&1; then
    if [ ! -f /etc/snapper/configs/@ ]; then
      sudo snapper create-config / --config-template default
    fi
    sudo systemctl enable --now snapper-timeline.timer snapper-cleanup.timer
    log "services: snapper enabled"
  else
    skip "snapper: / is '$fs' (needs btrfs and the snapper package)"
  fi
}

stage_sway() {
  # This script lives inside the checkout, so it can only verify or refresh
  # ~/.config/sway — never clone the repo from inside itself.
  if [ -L "$HOME/.config/sway" ]; then
    log "sway: ~/.config/sway is a symlink -> $(readlink "$HOME/.config/sway")"
  elif [ -d "$HOME/.config/sway/.git" ]; then
    if [ -n "$(git -C "$HOME/.config/sway" status --porcelain 2>/dev/null)" ]; then
      skip "sway: ~/.config/sway has local changes; git pull left to you"
    else
      git -C "$HOME/.config/sway" pull --ff-only
      log "sway: refreshed"
    fi
  elif [ -e "$HOME/.config/sway" ]; then
    skip "sway: ~/.config/sway exists but is not a git checkout; left alone"
  else
    mkdir -p "$HOME/.config"
    ln -sfn "$REPO_ROOT" "$HOME/.config/sway"
    log "sway: linked ~/.config/sway -> $REPO_ROOT"
  fi
}

stage_user_units() {
  # SSH agent: use the distro's unit if openssh ships one, otherwise install
  # ours. Probe first — this repo's contract is probe-and-degrade.
  if systemctl --user cat ssh-agent.service >/dev/null 2>&1; then
    skip "user-units: ssh-agent.service already provided by the system"
  else
    mkdir -p "$USER_UNIT_DST"
    cp "$USER_UNIT_SRC/ssh-agent.service" "$USER_UNIT_DST/ssh-agent.service"
    log "user-units: installed ssh-agent.service"
  fi
  systemctl --user daemon-reload 2>/dev/null || true
  systemctl --user enable ssh-agent.service
  if systemctl --user is-active ssh-agent.service >/dev/null 2>&1; then
    log "user-units: ssh-agent running"
  else
    skip "user-units: ssh-agent starts at next login (or: loginctl enable-linger $(id -un))"
  fi

  # Feed the socket path to the systemd user session (and thus Sway).
  # environment.d expands ${XDG_RUNTIME_DIR}; /etc/environment does not.
  # Follows the established pattern of environment.d/10-terminal.conf.
  mkdir -p "$HOME/.config/environment.d"
  printf 'SSH_AUTH_SOCK=${XDG_RUNTIME_DIR}/ssh-agent.socket\n' \
    > "$HOME/.config/environment.d/20-ssh-agent.conf"

  # Plain SSH logins don't go through the systemd user manager, so give
  # login shells the socket too. Guarded block: re-runs never duplicate.
  if [ -f "$HOME/.profile" ] && grep -qF '# dot-sway ssh-agent' "$HOME/.profile"; then
    skip "user-units: ~/.profile already carries the ssh-agent export"
  else
    cat >> "$HOME/.profile" <<'EOF'

# dot-sway ssh-agent: socket path for plain (non-systemd-user) login shells.
[ -n "${SSH_AUTH_SOCK:-}" ] || export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR:-/tmp}/ssh-agent.socket"
EOF
    log "user-units: appended ssh-agent export to ~/.profile"
  fi
}

stage_portals() {
  # The wlroots stack: wlr for screencopy/screencast, gtk for file picker
  # and settings. The xdg-desktop-portal package already prefers wlr;gtk
  # for Sway (see docs/xdg-defaults.md).
  local pkg
  local missing=()
  for pkg in xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk; do
    if ! pacman -Qi "$pkg" >/dev/null 2>&1; then
      missing+=("$pkg")
    fi
  done
  if [ ${#missing[@]} -gt 0 ]; then
    log "portals: installing missing backends: ${missing[*]}"
    sudo pacman -S --needed "${missing[@]}"
  else
    log "portals: wlr + gtk backends present"
  fi
}

stage_secrets() {
  local script="$REPO_ROOT/bootstrap/secrets/bootstrap-secrets.sh"
  if [ ! -f "$script" ]; then skip "secrets: no bootstrap helper"; return 0; fi
  bash "$script"
}

stage_tailscale() {
  command -v tailscale >/dev/null 2>&1 || { skip "tailscale: not installed"; return 0; }
  local key_file="$SECRETS_DIR/tailscale_authkey"
  [ -f "$key_file" ] || { skip "tailscale: no authkey in $SECRETS_DIR"; return 0; }
  if tailscale status --json 2>/dev/null | jq -e '.BackendState == "Running"' >/dev/null; then
    skip "tailscale: already on the tailnet"
    return 0
  fi
  log "tailscale: joining tailnet"
  sudo tailscale up --authkey="$(cat "$key_file")"
}

run_stage() {
  case "$1" in
    user-units) stage_user_units ;;
    *) "stage_$1" ;;
  esac
}

# --- Main --------------------------------------------------------------------

main() {
  local stages=()
  if [ $# -gt 0 ]; then
    local arg
    for arg in "$@"; do
      case " ${ALL_STAGES[*]} " in
        *" $arg "*) stages+=("$arg") ;;
        *) printf 'unknown stage: %s (available: %s)\n' "$arg" "${ALL_STAGES[*]}" >&2; exit 1 ;;
      esac
    done
  else
    stages=("${ALL_STAGES[@]}")
  fi
  local stage
  for stage in "${stages[@]}"; do
    printf '[provision] %s\n' "$stage"
    run_stage "$stage"
  done
  printf '[provision] done\n'
}

main "$@"
