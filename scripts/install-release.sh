#!/usr/bin/env bash
# Install a non-repo tool from a pinned release into /opt/<name>/ with
# /usr/local/bin symlinks — this repo's standard pattern for tools the
# distro doesn't package well (nvim, teams-for-linux, ...).
#
# Usage: scripts/install-release.sh <name> <url> <sha256>
#
#   <name>    tool name (e.g. nvim): becomes /opt/<name>/ and the
#             /usr/local/bin symlink names
#   <url>     exact pinned download URL (the release notes carry it)
#   <sha256>  expected SHA256 of the download
#
# Verifies the checksum before touching system dirs. Tarballs extract into
# /opt/<name>/ and executables from a bin/ dir (or the tarball root) get
# symlinked; a plain file lands in /opt/<name>/ and is symlinked as <name>.
# Refuses to overwrite an existing /opt/<name>. Sudo is needed for the
# install steps.
set -euo pipefail

# Scratch dir for the download + staged payload; cleaned by the EXIT trap.
TMP_DIR=""

usage() {
  cat <<'EOF'
Usage: scripts/install-release.sh <name> <url> <sha256>

Install a non-repo tool from a pinned release: download, verify SHA256,
install to /opt/<name>/, symlink executables into /usr/local/bin.

  <name>    tool name (e.g. nvim): /opt/<name>/ + symlink names
  <url>     exact pinned download URL
  <sha256>  expected SHA256 of the download

Tarballs: executables from a bin/ dir (or the tarball root) are
symlinked. Plain files: symlinked into /usr/local/bin as <name>.
Refuses to overwrite an existing /opt/<name> — remove it first
(sudo rm -rf /opt/<name>). Sudo is needed for the install steps.
EOF
}

# Echoes space-separated, stage-relative paths of the executables to
# symlink. Prefers a bin/ dir (FHS layout, or a single top-level directory
# with its own bin/), then falls back to top-level executables.
resolve_bins() {
  local stage="$1"
  local entry dirs=() bin_dir="" f found=""
  for entry in "$stage"/*; do
    [ -d "$entry" ] || continue
    dirs+=("${entry#"$stage"/}")
  done
  if [ -d "$stage/bin" ]; then
    bin_dir="bin"
  elif [ ${#dirs[@]} -eq 1 ] && [ -d "$stage/${dirs[0]}/bin" ]; then
    bin_dir="${dirs[0]}/bin"
  elif [ ${#dirs[@]} -eq 0 ]; then
    bin_dir="."
  fi
  [ -n "$bin_dir" ] || return 0
  for f in "$stage/$bin_dir"/*; do
    [ -f "$f" ] || continue
    [ -x "$f" ] || continue
    case "$(basename "$f")" in
    *.so*) continue ;;
    esac
    found="$found ${f#"$stage"/}"
  done
  printf '%s' "${found# }"
}

# --- Main --------------------------------------------------------------------

main() {
  if [ $# -lt 3 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
    exit 1
  fi

  local name url sha256
  name="$1"
  url="$2"
  sha256="${3,,}"

  if ! [[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ ]]; then
    echo "error: name must be a plain path component (letters, digits, . _ + -)" >&2
    exit 1
  fi
  if ! [[ "$sha256" =~ ^[0-9a-f]{64}$ ]]; then
    echo "error: sha256 must be 64 hex characters" >&2
    exit 1
  fi
  command -v curl >/dev/null 2>&1 || { echo "error: curl not found" >&2; exit 1; }
  command -v sudo >/dev/null 2>&1 || { echo "error: sudo not found" >&2; exit 1; }
  if [ -e "/opt/$name" ]; then
    echo "error: /opt/$name already exists — remove it first (sudo rm -rf /opt/$name)" >&2
    exit 1
  fi

  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT

  local file="$TMP_DIR/$name"
  local stage="$TMP_DIR/stage"
  mkdir -p "$stage"

  echo "Fetching $url"
  curl -fL --retry 3 -o "$file" "$url"

  local actual
  actual="$(sha256sum "$file" | cut -d' ' -f1)"
  if [ "$actual" != "$sha256" ]; then
    echo "error: SHA256 mismatch — nothing installed" >&2
    echo "  expected: $sha256" >&2
    echo "  actual:   $actual" >&2
    exit 1
  fi
  echo "SHA256 ok"

  # --- Stage the payload (user context; no sudo yet) --------------------------
  # Detect the payload from its content, not the name: the tool name (nvim)
  # rarely matches the artifact filename (nvim-linux-x86_64.tar.gz).
  local mode bins=""
  if tar -tf "$file" >/dev/null 2>&1; then
    mode="tar"
    tar -xf "$file" -C "$stage"
    bins="$(resolve_bins "$stage")"
    if [ -z "$bins" ]; then
      echo "warning: no executables found in the tarball — installing without symlinks" >&2
    fi
  else
    mode="file"
    cp "$file" "$stage/$name"
  fi

  # --- System-facing steps, in one sudo call ----------------------------------
  echo "Installing to /opt/$name"
  sudo bash -c '
    set -euo pipefail
    # `bash -c` assigns the first argument after the script to $0, so the
    # payload starts at $1 (the _ above is $0).
    name=$1; stage=$2; mode=$3; bins=$4
    install -d "/opt/$name" /usr/local/bin
    cp -a "$stage/." "/opt/$name/"
    if [ "$mode" = "tar" ]; then
      for b in $bins; do
        ln -sfn "/opt/$name/$b" "/usr/local/bin/$(basename "$b")"
        echo "  linked /usr/local/bin/$(basename "$b") -> /opt/$name/$b"
      done
    else
      chmod +x "/opt/$name/$name"
      ln -sfn "/opt/$name/$name" "/usr/local/bin/$name"
      echo "  linked /usr/local/bin/$name -> /opt/$name/$name"
    fi
  ' _ "$name" "$stage" "$mode" "$bins"
  echo "Installed $name to /opt/$name"
}

main "$@"
