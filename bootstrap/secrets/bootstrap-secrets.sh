#!/usr/bin/env bash
#
# bootstrap-secrets.sh: decrypt bootstrap/secrets/*.age into
# ~/.local/share/sync/secrets/ (0600 files in a 0700 dir).
#
# Identity: prefers the user's SSH ed25519 key — age accepts OpenSSH keys
# natively, so the key you already carry for git is the key that unlocks
# the secrets. Falls back to a dedicated age key at ~/.config/sync/age.key,
# created once and printed for offline backup.
#
# Idempotent: re-running re-decrypts over existing files; it never
# re-creates the age key.

set -euo pipefail

# --- Constants ---------------------------------------------------------------

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$REPO_ROOT/secrets"
OUT_DIR="$HOME/.local/share/sync/secrets"
FALLBACK_KEY="$HOME/.config/sync/age.key"

# --- Helpers -----------------------------------------------------------------

log() { printf '  %s\n' "$*"; }

resolve_identity() {
  if [ -f "$HOME/.ssh/id_ed25519" ]; then
    printf '%s' "$HOME/.ssh/id_ed25519"
    return 0
  fi
  if [ ! -f "$FALLBACK_KEY" ]; then
    mkdir -p "$(dirname "$FALLBACK_KEY")"
    age-keygen -o "$FALLBACK_KEY" 2>/dev/null
    chmod 600 "$FALLBACK_KEY"
    log "secrets: created a new age key at $FALLBACK_KEY — back it up now:"
    log "secrets: $(cat "$FALLBACK_KEY")"
  fi
  printf '%s' "$FALLBACK_KEY"
}

# --- Main --------------------------------------------------------------------

main() {
  command -v age >/dev/null 2>&1 || { log "secrets: age not installed; skipping"; return 0; }
  command -v age-keygen >/dev/null 2>&1 || { log "secrets: age-keygen not installed; skipping"; return 0; }

  local files
  files="$(find "$SRC_DIR" -maxdepth 1 -name '*.age' | sort)"
  if [ -z "$files" ]; then
    log "secrets: nothing to decrypt (add *.age files to bootstrap/secrets/)"
    return 0
  fi

  local identity
  identity="$(resolve_identity)"
  mkdir -p "$OUT_DIR"
  chmod 700 "$OUT_DIR"

  local src
  local out
  while IFS= read -r src; do
    out="$OUT_DIR/$(basename "$src" .age)"
    age --decrypt --identity "$identity" "$src" > "$out"
    chmod 600 "$out"
    log "secrets: $(basename "$src") -> $out"
  done <<<"$files"
}

main "$@"
