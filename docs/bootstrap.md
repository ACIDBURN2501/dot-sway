# Bootstrap (Zero to Online)

**What:** How a fresh Arch or Debian 13 machine becomes this desktop without an ISO — unattended base install, per-distro package manifests, and a staged, idempotent provisioner.
**Where:** `bootstrap/` — the detailed reference lives beside the code it describes, in [`bootstrap/README.md`](../bootstrap/README.md).
**Verified:** package manifests checked against reference installs (trixie + Arch rolling); `provision.sh --check` dry-runs any stage on your own box before it changes anything.

## The shape of it

Three layers, in order (the README has the file-by-file details and the step-by-step flows):

1. **`archinstall/`** — the JSON pair that installs the Arch base system unattended. Arch only — Debian uses the standard installer with no desktop task set.
2. **`packages/`** — the per-distro manifests: `pacman.txt`, `debian.txt`, `aur.txt`, `flatpak.txt`. The single source of truth for system packages; edit to taste.
3. **`provision.sh`** — the provisioner. Stages: `packages aur flatpak services sway user-units portals secrets tailscale`. Pass names to run a subset (`provision.sh tailscale`); `--check` reports what a stage would do without doing it.

Both flows end the same way: clone the repo, run `provision.sh`, log into Sway. Stages are idempotent and probe-first — a missing tool degrades to a skip, matching the repo-wide contract in [requirements.md](requirements.md).

## Adjacent topics

- **What "core" means** — the capability matrix and what is verified per distro: [core-features.md](core-features.md).
- **Secrets** — age-encrypted, identity = your SSH key: [`bootstrap/secrets/README.md`](../bootstrap/secrets/README.md).
- **Non-repo tools** — three tiers (distro package → pipx/cargo → pinned GitHub release via `scripts/install-release.sh`), codified in the README.
