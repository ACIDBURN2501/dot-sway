#!/usr/bin/env bash
# lib/manifest.sh — the install manifest: a record of every artifact the
# install created, so uninstall removes exactly that list instead of
# guessing.
#
# Sourced, not executed. The manifest lives at
# ${XDG_STATE_HOME:-$HOME/.local/state}/sync/install-manifest, one line per
# artifact, tab-separated:
#
#   type <TAB> path <TAB> detail
#
#   type    symlink | file | marker | unit
#   path    absolute path of the artifact
#   detail  symlink: the link target
#           file:    sha256 at creation (to detect later user edits)
#           marker:  the marker string identifying a block inside a file
#           unit:    (unused)
#
#   manifest_add <type> <path> [detail]
#     Append a line, replacing any existing line for the same type+path.
#     Creates the state directory on first use.
#
#   manifest_lines
#     Print the manifest, or nothing when it does not exist.

MANIFEST_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/sync/install-manifest"

manifest_add() {
  local type="$1" path="$2" detail="${3:-}"
  mkdir -p "${MANIFEST_FILE%/*}"
  local tmp
  tmp="$(mktemp)"
  if [[ -f "$MANIFEST_FILE" ]]; then
    grep -v -F "$(printf '%s\t%s\t' "$type" "$path")" "$MANIFEST_FILE" > "$tmp" 2>/dev/null || true
  fi
  printf '%s\t%s\t%s\n' "$type" "$path" "$detail" >> "$tmp"
  mv "$tmp" "$MANIFEST_FILE"
}

manifest_lines() {
  [[ -f "$MANIFEST_FILE" ]] || return 0
  cat "$MANIFEST_FILE"
}
