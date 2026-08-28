# Bootstrap: zero → online

Brings a fresh Arch install to this desktop without building an ISO.
Three layers, in order:

1. **`archinstall/`** — the JSON pair that installs the base system unattended.
2. **`packages/`** — the package manifests (pacman / AUR / flatpak).
3. **`provision.sh`** — a staged, idempotent provisioner that applies the rest
   (services, sway checkout, ssh-agent, portals, secrets, tailscale).

## The flow

1. Boot the [Arch ISO](https://archlinux.org/download/) on the new machine
   (ethernet is DHCP by default; for Wi-Fi, `iwctl` in the live environment).
2. Unattended base install from the JSON pair:
   ```bash
   archinstall --config user_configuration.json --creds user_credentials.json --silent
   ```
   The `.example` files here are deliberately minimal — the schema's disk
   layout section has churned across archinstall versions. The canonical way
   to get a working pair: run `archinstall` once interactively in a VM, then
   copy the files it wrote to `/root/` into this directory (drop the
   `.example` suffix).
3. Reboot and log in (the install enables `sshd`; the password is the one
   from the credentials file).
4. Clone this repo and run the provisioner:
   ```bash
   git clone https://github.com/aajll/dot-sway ~/dot-sway
   ~/dot-sway/bootstrap/provision.sh
   ```
   Cloning straight into `~/.config/sway` also works; the `sway` stage then
   just verifies the checkout. Stages re-run safely — pass names to run a
   subset (`provision.sh tailscale`).
5. Log into Sway. Done.

## Files

| Path | Purpose |
|------|---------|
| `archinstall/user_configuration.json(.example)` | Base install: hostname, locale, keyboard, bootloader, swap. No disk layout on purpose — generate it (step 2). |
| `archinstall/user_credentials.json(.example)` | Username + **password hash** (`openssl passwd -6`). The real file holds a secret: both real files are gitignored. |
| `packages/pacman.txt` | System package manifest — single source of truth; the archinstall JSON's `packages` list stays empty. |
| `packages/aur.txt` | AUR manifest (yay), all commented out by default. |
| `packages/flatpak.txt` | Flatpak app manifest, all commented out by default. |
| `user/systemd/ssh-agent.service` | User unit installed by the `user-units` stage (only if the distro doesn't already ship one). |
| `secrets/` | Age-encrypted secrets, decrypted on each machine. See [`secrets/README.md`](secrets/README.md). |
| `provision.sh` | The provisioner. Stages: `pacman aur flatpak services sway user-units portals secrets tailscale`. |

## Design notes

- **Probe, don't assume.** Every stage degrades to a skip when its tool is
  missing, matching the repo-wide contract in `AGENTS.md`.
- **Idempotent by construction.** Stages converge (package managers, `enable`,
  guarded appends) instead of tracking state; the only persistent outputs are
  the decrypted secrets dir and the marker-guarded `~/.profile` block.
- **`services` ordering matters on a remote box**: `ufw limit 22/tcp` runs
  before `ufw enable` so provisioning over SSH can't lock itself out.
- **Snapper is btrfs-gated**: `archinstall` defaults to ext4, and
  `snapper create-config` refuses anything else. Choose btrfs for `/` in the
  interactive archinstall pass if you want system snapshots.
- **iwd, not NetworkManager**: coherent with `scripts/network-tui.sh` probing
  `impala` first. Don't enable both.
- **Secrets use age's native OpenSSH-key support**: your existing SSH key is
  the identity, no GPG, no plugins.
