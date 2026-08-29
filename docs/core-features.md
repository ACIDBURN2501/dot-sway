# Core Features — the "just works" matrix

**What:** The capability matrix — what the configuration expects, per distro, and what is verified on the reference machines.
**Where:** this page; the source of truth is `scripts/check-core-features.sh`, which probes the machine and prints the matrix as ✓/!/✗ (exit 1 on any ✗).
**Verified:** the reference columns were checked in 2026-08; re-run the script on any box to re-verify a column.

Each row lists what the configuration expects and the package that provides it per supported distro.

Legend: ✓ working · ! degraded or N/A (box-specific — see notes) · ✗ gap (fix below)

| Feature | Implementation | Arch package | Debian 13 package | Debian 13 (ref.) | Arch (ref.) |
|---------|---------------|--------------|-------------------|--------|-------|
| Terminal | kitty | `kitty` | `kitty` | ✓ | ✓ |
| Launcher | wofi (`Mod+d`) | `wofi` | `wofi` | ✓ | ✓ |
| Notifications | mako daemon + `extra/mako/` theme configs | `mako` | `mako-notifier` | ✓ | ✓ |
| Exit confirm | swaynag (`Mod+Shift+e`) | bundled in `sway` | bundled in `sway` | ✓ | ✓ |
| Screenshots | grim + slurp (`Ctrl+Alt+s`) | `grim` `slurp` | `grim` `slurp` | ✓ | ✓ |
| Lock / idle | swaylock + swayidle | `swaylock` `swayidle` | `swaylock` `swayidle` | ✓ | ✓ |
| Volume | `scripts/volume-control.sh` (wpctl → pactl → silent) | `wireplumber` (ships wpctl) | `wireplumber` (ships wpctl) | ✓ | ✓ |
| Media (MPRIS) | transport keys + waybar `mpris` module (native, libplayerctl; waybar ≥ 0.12) | `playerctl` | `playerctl` | ! (packaged, not yet installed) | ✓ |
| OSD (volume/brightness) | `wob` fed by the control scripts via `scripts/osd-bar.sh` (silent skip when absent) | `wob` | `wob` | ! (packaged, not yet installed) | ! (packaged, not yet installed) |
| Backlight | `brightness-control.sh` (brightnessctl), `external-brightness.sh` (ddcutil) | `brightnessctl` `ddcutil` | `brightnessctl` `ddcutil` | ✓ | ✓ |
| Battery | waybar native module (upower/D-Bus) | `upower` | `upower` | ✓ | ✓ |
| Bluetooth | waybar module + `bluetoothctl` (bluetuith optional) | `bluez` | `bluez` | ✓ | ✓ |
| Network daemon | iwd on Arch, NetworkManager on Debian | `iwd` | `network-manager` (ships `nmcli` **and** `nmtui`) | ✓ (NM) | ✓ (NM) |
| Network TUI | `scripts/network-tui.sh`: impala → nmtui → iwctl → ip | `iwd`, impala via pipx | `networkmanager` (nmtui) | ✓ (nmtui) | ✓ (nmtui) |
| Firewall | ufw, SSH rate-limited before enable | `ufw` | `ufw` | ✗ | ✗ (intentional) |
| Portals | file picker / screenshot / screencast (`wlr;gtk` preference) | `xdg-desktop-portal` `-wlr` `-gtk` | same three | ✓ (wlr+gtk+gnome backends) | ✓ (wlr+gtk+gnome backends) |
| Clipboard | wl-clipboard (standard `Ctrl+C`/`V` in kitty) | `wl-clipboard` | `wl-clipboard` | ✓ | ✓ |
| SSH agent | distro-provided user unit on both (Debian 13: gnome-keyring `ssh-agent.socket`, self-exports `SSH_AUTH_SOCK`; Arch: openssh `ssh-agent.service` + `.socket`); `bootstrap/user/` unit is the fallback for systems without one | `openssh` | `openssh-client` + gnome-keyring | ✓ | ✓ |
| Secrets | age-encrypted, identity = SSH ed25519 key | `age` `rage` | `age` (rage not packaged — encrypt on an Arch box) | ! (age installed; no rage) | ! (age installed; no rage) |
| Tailscale | joins via `secrets/tailscale_authkey` | `tailscale` | not in archive — vendor repo (pkgs.tailscale.com) | ✓ (vendor) | ✓ |
| System snapshots | snapper, btrfs-gated (default installs are ext4 → N/A) | `snapper` | `snapper` | ✗ (ext4 — N/A) | ✗ (ext4 — N/A) |
| Text / PDF / images | gnome-text-editor, evince, loupe (MIME map in `setup-defaults.sh`) | same | same | ✓ | ✓ |
| Theme source of truth | GNOME `gsettings` via GNOME fallback session | `gnome-shell` | `gnome-session` | ✓ | ✓ |

## Known gaps (verified 2026-08)

- **Debian 13 (trixie):** `ufw` and `age` are packaged but not installed by default. Both are one command: `sudo apt-get install -y ufw age`, then the `services` and `secrets` provisioner stages light up.
- **Arch (reference):** **`ufw` is intentionally absent** — this host runs Docker, libvirt, and Tailscale, and enabling ufw would break container/VM networking. The `packages` stage still lists it for fresh boxes (it stays inert until the `services` stage enables it, which never happens on this host). Remaining useful delta on this box: `rage` only if you encrypt new secrets here (`age` was installed in 2026-08); `snapper` stays dormant until btrfs is present.
- **rage on Debian:** not packaged in trixie. Decrypting secrets only needs `age`; to *encrypt* a new secret, do it on an Arch box (rage is packaged there) or via pipx.
- **SSH agent (Arch reference):** the box runs keychain, so `SSH_AUTH_SOCK` comes from keychain rather than the distro `ssh-agent.socket` the matrix row describes. The feature works either way; the distro unit (or the `bootstrap/user/` fallback) is what a fresh box gets.
- **Snapper:** irrelevant until a machine has btrfs on `/` — the default installers give ext4 on purpose (simpler).
- **impala:** PyPI (pipx) on iwd boxes only; Debian's nmtui path covers the TUI without it.

## Per-machine drift (kept local, on purpose)

The provisioner's `sway` stage never touches a checkout with local changes. Known intentional drift pattern:

- **Power menu trimmed** on hardware without suspend/hibernate: local edit to `extra/wofi/wofi-power.sh` (remove those options) with `extra/EXTRA.md` updated to match.
- **NetworkManager instead of iwd** on the wired reference install (no Wi-Fi radio): NetworkManager is the active daemon and iwd was removed in 2026-08 (radio-less box — nothing gained by keeping it dormant). iwd remains the baseline where a radio exists.
- **Keychain over the user ssh-agent** on the reference install: keychain sets `SSH_AGENT_PID`, which keeps the distro ssh-agent unit dormant; the agent works via keychain, not the provisioner's env-export path.
