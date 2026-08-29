# Bootstrap: zero → online

Brings a fresh install to this desktop without building an ISO. Two supported targets — **Arch Linux (rolling)** and **Debian 13 (trixie)** — with three layers, in order:

1. **`archinstall/`** — the JSON pair that installs the Arch base system unattended.
2. **`packages/`** — per-distro package manifests (pacman / apt / AUR / flatpak).
3. **`provision.sh`** — a staged, idempotent provisioner that applies the rest (services, sway checkout, ssh-agent, portals, secrets, tailscale).

## The flow

### Arch (unattended)

1. Boot the [Arch ISO](https://archlinux.org/download/) on the new machine (ethernet is DHCP by default; for Wi-Fi, `iwctl` in the live environment).
2. Unattended base install from the JSON pair:
   ```bash
   archinstall --config user_configuration.json --creds user_credentials.json --silent
   ```
   The `.example` files here are deliberately minimal — the schema's disk layout section has churned across archinstall versions. The canonical way to get a working pair: run `archinstall` once interactively in a VM, then copy the files it wrote to `/root/` into this directory (drop the `.example` suffix).
3. Reboot and log in (the install enables `sshd`; the password is the one from the credentials file).
4. Clone this repo and run the provisioner:
   ```bash
   git clone https://github.com/aajll/sync ~/sync
   ~/sync/bootstrap/provision.sh
   ```
5. Log into Sway. Done.

### Debian 13 (standard installer, then one command)

Debian has no archinstall equivalent, so the base install is the standard [debian-installer](https://www.debian.org/CD/) run (~10 minutes; choose the "desktop environment: none" task set and add `ssh-server`). Then:

```bash
git clone https://github.com/aajll/sync ~/sync
~/sync/bootstrap/provision.sh
```

The provisioner detects the distro and switches manifests (`debian.txt` via `apt-get`), service units (`ssh` not `sshd`), and network backend (NetworkManager — the Debian baseline; `nmtui` is the network TUI). A `preseed.cfg` for fully unattended Debian installs is a possible later addition, not a current one.

Both flows end at the same point: `provision.sh` stages re-run safely — pass names to run a subset (`provision.sh tailscale`). `provision.sh --check` reports what any stage would do without changing anything — run it first on a box you care about. Cloning straight into `~/.config/sway` also works; the `sway` stage then just verifies the checkout. If `~/.config/sway` already has local edits, the `sway` stage leaves it alone — per-machine drift (e.g. a trimmed power menu) is preserved on purpose.

## Files

| Path | Purpose |
|------|---------|
| `archinstall/user_configuration.json(.example)` | Arch base install: hostname, locale, keyboard, bootloader, swap. No disk layout on purpose — generate it (step 2). |
| `archinstall/user_credentials.json(.example)` | Username + **password hash** (`openssl passwd -6`). The real file holds a secret: both real files are gitignored. |
| `packages/pacman.txt` | Arch package manifest. |
| `packages/debian.txt` | Debian 13 package manifest, verified on a trixie reference install. |
| `packages/aur.txt` | AUR manifest (yay), all commented out by default. |
| `packages/flatpak.txt` | Flatpak app manifest, all commented out by default. |
| `user/systemd/ssh-agent.service` | User unit installed by the `user-units` stage (only if the distro doesn't already ship one). |
| `secrets/` | Age-encrypted secrets, decrypted on each machine. See [`secrets/README.md`](secrets/README.md). |
| `provision.sh` | The provisioner. Stages: `packages aur flatpak services sway user-units portals secrets tailscale`. `--check` dry-runs any stage; `--help` lists them. |

## Non-repo tools

Three tiers, in preference order — codifying what already exists on the machines (nvim, teams-for-linux under `/opt` with `/usr/local/bin` symlinks):

1. **Distro package** — always first; the manifests carry it.
2. **Language-native tool** — `pipx install <name>` for Python (e.g. `impala` on iwd boxes) or `cargo install <name>` for Rust (e.g. `wayland-pipewire-idle-inhibit`). These land in `~/.local/bin` / `~/.cargo/bin`, already on `PATH`.
3. **GitHub release binary** — install to `/opt/<name>/`, symlink the binaries into `/usr/local/bin` (which is in sudo's `secure_path` and in every default `PATH`). Use `scripts/install-release.sh <name> <url> <sha256>`: it pins the exact release URL, verifies the sha256 before touching system dirs, installs, and symlinks (see `scripts/SCRIPTS.md`). Keep the URL + sha256 in the release notes so re-downloads re-verify.

## Design notes

- **Probe, don't assume.** Every stage degrades to a skip when its tool is missing, matching the repo-wide contract in `AGENTS.md`.
- **Idempotent by construction.** Stages converge (package managers, `enable`, guarded appends) instead of tracking state; the only persistent outputs are the decrypted secrets dir and the marker-guarded `~/.profile` block.
- **`services` ordering matters on a remote box**: `ufw limit 22/tcp` runs before `ufw enable` so provisioning over SSH can't lock itself out.
- **Snapper is btrfs-gated** on both distros: the default installers give ext4, and `snapper create-config` refuses anything else. Choose btrfs for `/` if you want system snapshots.
- **Network backend is a per-distro baseline**: iwd on Arch (impala is the TUI), NetworkManager on Debian (nmtui is the TUI). Don't run both on one box; `scripts/network-tui.sh` probes either.
- **ssh-agent follows the distro**: both supported distros ship a user unit (Debian 13: gnome-keyring's `ssh-agent.socket`, self-exporting `SSH_AUTH_SOCK`; Arch: openssh's `ssh-agent.service` + `.socket`). The `user-units` stage probes first and only installs `user/systemd/ssh-agent.service` as a fallback on systems without one, exporting the socket via `environment.d` in that case.
- **Secrets use age's native OpenSSH-key support**: your existing SSH key is the identity, no GPG, no plugins.
