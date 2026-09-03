# TODO

Open and future work for the repo. The "birthday" pass (host.env consolidation, swayi delegator, swhkd template, install/uninstall, docs sweep, AGENTS.md, prose-style pass) is complete on branch `feat/host-env`; this file now tracks only what remains.

## Open

### 1. Live-verify install.sh / uninstall.sh on a real session

The install → manifest → uninstall cycle is verified in an isolated sandbox (fake HOME, stubbed sudo/systemctl/git): exact removal, `.profile` restoration, refusal to delete a real checkout, keeping user-edited files under `--yes`, and a no-op `--check`. What is not yet covered is a real systemd user session, where `user-units` (ssh-agent) and `portals` actually run rather than skip.

- [ ] Bring up a disposable Debian 13 and an Arch VM (or a container for the non-session parts), snapshot before the first run, then run `install.sh` and confirm convergence (a second run prints only skips).
- [ ] Run `uninstall.sh` and confirm the box returns to its pre-install state (no marker block, no environment.d conf, no dangling symlinks).
- [ ] Exercise the risky deletion paths twice against the snapshot.
- [ ] Only after both distros pass, consider `install.sh` safe to point at a machine you care about.

## Future (not scheduled)

- [ ] **Event-driven power-events.** `scripts/power-events.sh` polls UPower every 30s, the one place the "event-driven over polling" philosophy bends. UPower exposes D-Bus signals, so an event-driven watcher is possible; the poll is bounded, silent without a battery, and covered by `tests/power-sandbox.sh`, so this is low priority.
- [ ] **swayfx_guard.sh sandbox coverage.** The generator shape is covered via `host-env.sh`, but `swayfx_guard.sh` itself has no suite (it needs a `swaymsg get_version` stub). Revisit if it ever gains logic.
- [ ] **Manage the wofi/mako/kitty configs through install.sh.** `install.sh` does not currently create `~/.config/wofi/style.css`, the mako config symlink, or the seeded kitty files, so `uninstall.sh` has nothing attributable to remove for them. If these become install-managed, add them to the manifest so uninstall covers them too.
- [ ] **Payload subdirectory.** Moving the payload into a `sway/` subdirectory so the install target is a clean subfolder is deferred (see docs/restructure.md): it separates repo meta from payload but forces a path audit across the ~200 hardcoded `~/.config/sway/` references. Revisit only if the repo grows non-dotfile content.
