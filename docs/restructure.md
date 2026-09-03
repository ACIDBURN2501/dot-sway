# Restructure & distribution review (2026-09)

**What:** the assessment and decisions behind the 2026-09 "birthday" pass. The pass is executed on branch `feat/host-env`; this page keeps the verified findings, the decisions, and what is still open. `TODO.md` at the repo root tracks the actionable items.
**Status:** findings verified against `master @ d214195` on 2026-09-03.

## What was done

Seven changes landed, one commit each, on `feat/host-env`:

1. **host.env consolidation** (`bdbfa4d`) — the six scattered per-machine mechanisms (compose_key.local, wallpaper_dir.local, idle.conf, the unmechanised `DOTSWAY_EXT_*` env vars, and the swayi path) became one gitignored `host.env` behind a shared loader (`scripts/lib/host-env.sh`), precedence env var > host.env > default. New sandbox suites: `host-env` (13) and `monitor-hotplug` (9, its first coverage).
2. **swayi delegator** (`caf6694`) — `config.jsonc` no longer ships the maintainer's `$HOME/Workspace/neuralburn/swayi` path; a vendored `waybar/modules/swayi.sh` + `waybar/menus/swayi.xml` degrade to a hidden pill when `SWAYI_DIR` is unset. Signal-8 delivery through the delegator verified live.
3. **swhkd template** (`9770c2b`) — `extra/swhkd/swhkdrc` is a `__SWAY_HOME__` template rendered at install; `/home/ajl` is gone from the tracked tree.
4. **install.sh / uninstall.sh** (`46948a9`) — a thin preflight delegating to the existing provision stages, plus a manifest-driven uninstall (`scripts/lib/manifest.sh`).
5. **Docs sweep + hygiene** (`7b84807`) — Waybar floor reconciled to 0.10.4 (verified against release tags), stale references fixed, a CONTRIBUTING documentation rule, the secrets recovery note, and a CI personal-path leak gate.
6. **AGENTS.md** (`a8cd404`) — architecture and Testing sections brought in line with the tree.
7. **Prose-style pass** (`ddc3604`, `f0365e4`) — em dashes removed from prose (functional output strings kept), sentence-case headings, the prose standard recorded in CONTRIBUTING.md.

## Decisions worth keeping

- **Distribution: clone + symlink, not packaging.** Packages own FHS paths, not `$HOME`; the payload is read-write (`.theme_state`, `colors.css`, `wp.png`, the runtime snippets, `host.env`) where a package payload is read-only; and two packaging toolchains buy nothing over the per-distro manifests consumed natively by `provision.sh`. chezmoi/Stow are likewise rejected: they handle dotfile placement and templating but not system packages, user units, or portals (the harder half, which the provisioner already does). Revisit only if this becomes a multi-user distro preset.
- **Clean breaks, no fallbacks, no migration script.** The old `.local` files were removed outright; migration is a one-time snippet in the PR body, not a permanent script.
- **Uninstall is manifest-driven.** It removes exactly what the install recorded, keeping any file whose checksum changed since install; heuristics are the fallback for pre-manifest installs.
- **The leak gate is the durable fix for the F1/F2 bug class.** CI now fails on any `/home/<user>` literal in tracked files.

## Still open

- **Live-verify install.sh / uninstall.sh on a real session.** The cycle is verified in an isolated sandbox (stubbed sudo/systemctl/git); a real systemd user session (where `user-units` and `portals` run rather than skip) is the remaining gate before pointing `install.sh` at a machine that matters. See TODO.md.

## Future (not scheduled)

- **Event-driven power-events.** `scripts/power-events.sh` polls UPower every 30s, the one bend in the "event-driven over polling" rule. Low priority: bounded, silent without a battery, covered by `tests/power-sandbox.sh`.
- **Payload subdirectory.** Moving the payload into a `sway/` subdirectory is deferred: it separates repo meta from payload but forces a path audit across the ~200 hardcoded `~/.config/sway/` references, and `~/.config/sway` containing `docs/` and `tests/` via the symlink is harmless. Revisit only if the repo grows non-dotfile content.
- **swayfx_guard.sh coverage**, **install-managed wofi/mako/kitty configs** — see TODO.md.
