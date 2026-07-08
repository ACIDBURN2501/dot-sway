# XDG Defaults (Terminal, MIME, Portals)

Session-level defaults that make Sway behave like a first-class desktop on a GNOME-based distro. None of this lives in the Sway `config` file; it is XDG/session state, applied by [`scripts/setup-defaults.sh`](../scripts/setup-defaults.sh) (idempotent; user-level steps run without root, root steps are printed).

> **Scope — Debian/Ubuntu family with a GNOME fallback session.** This is where the "GNOME owns the app defaults, Sway has to co-exist" friction actually shows up, so the commands below assume `apt` and Debian's package names. The *mechanisms* are cross-distro — the four terminal layers, `.desktop` entries, `xdg-mime`, `secure_path` — but **package names and paths are not.** The Nautilus terminal extension is the sharp edge: its Python binding is upstream-named `nautilus-python` (Debian/Ubuntu rename it `python3-nautilus`), and `nautilus-open-any-terminal` isn't packaged for Debian at all (it *is* on the Arch AUR, Fedora COPR, etc.). On a non-Debian distro, translate the package names and consult the upstream project's per-distro install matrix rather than pasting these verbatim.

## Session environment

The one variable that matters for both portals and MIME routing is `XDG_CURRENT_DESKTOP`. The main `config` exports it and the Wayland/session vars into the D-Bus and systemd user environments so portals and launched apps see them:

```
exec dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=sway XDG_SESSION_TYPE=wayland
```

`XDG_CURRENT_DESKTOP=sway` is also what selects the desktop-specific `sway-portals.conf` and (if present) `sway-mimeapps.list` variants.

## Default terminal

There are **four independent "default terminal" layers** on a Debian + Sway box. `setup-defaults.sh` sets the first three; the Nautilus one needs a package swap.

| Layer | File / mechanism | Read by |
|-------|------------------|---------|
| freedesktop / GLib | `~/.config/xdg-terminals.list` ([`xdg-terminal-exec` spec](https://github.com/Vladimir-csp/xdg-terminal-exec)) | GLib ≥ 2.79 "launch in terminal", anything honoring the spec |
| `$TERMINAL` env | `~/.config/environment.d/10-terminal.conf` | `xdg-terminal-exec` fallback, many CLI tools |
| Debian alternative | `x-terminal-emulator` (`update-alternatives`) | tools that exec `x-terminal-emulator` |
| GNOME legacy | `org.gnome.desktop.default-applications.terminal` gsettings | some GNOME components |

### Nautilus "Open in Terminal"

Served by the `nautilus-extension-gnome-terminal` package, which is **hardwired to gnome-terminal and ignores every layer above**. To make it open kitty, replace it with [`nautilus-open-any-terminal`](https://github.com/Stunkymonkey/nautilus-open-any-terminal).

This is a Nautilus **Python extension**: Nautilus loads it with the *system* `python3` interpreter (via `python3-nautilus`), so the package has to be importable by that interpreter and its files have to land in the shared XDG dirs. That rules out isolated installers like `pipx` or `uv tool` — they bury the package in a private venv Nautilus can't import from, and never lay down the extension/schema. Use a plain `--user` install:

```bash
# Drop the hardwired extension
sudo apt remove nautilus-extension-gnome-terminal

# Loader + GTK4 typelib the extension needs (nautilus-open-any-terminal isn't in Debian apt)
sudo apt install python3-nautilus gir1.2-gtk-4.0 python3-pip

# Install into the system user-site so Nautilus's python3 can import it.
# Debian's Python is externally managed (PEP 668), hence --break-system-packages.
pip install --user --break-system-packages nautilus-open-any-terminal

# Compile the schema it dropped in ~/.local, point it at kitty, restart Nautilus
glib-compile-schemas ~/.local/share/glib-2.0/schemas/
gsettings set com.github.stunkymonkey.nautilus-open-any-terminal terminal kitty
nautilus -q
```

The gsettings key is global, so "Open in Terminal" opens kitty in **both** Sway and the GNOME fallback.

## MIME defaults

The authoritative file is `~/.config/mimeapps.list`; its `[Default Applications]` section overrides all system defaults. Lookup precedence (highest first):

1. `~/.config/sway-mimeapps.list` — desktop-specific; only for Sway≠GNOME divergence
2. **`~/.config/mimeapps.list`** — shared across both sessions (what we use)
3. `/etc/xdg/mimeapps.list`, then system `/usr/share/applications/…`

Drive it with `xdg-mime` (writes the correct file for you) rather than editing by hand:

```bash
gio mime application/pdf                                  # query
xdg-mime default org.gnome.Evince.desktop application/pdf # set
```

`setup-defaults.sh` sets sane defaults (text → GNOME Text Editor, PDF → Evince, images → Loupe) only when the target app is installed. Edit its `MIME_MAP` to taste.

## Manually-installed apps in "Open With"

GUI file managers only list apps that ship a **`.desktop` entry** in a standard applications dir (`/usr/share/applications`, `~/.local/share/applications`, …). An app you unpacked by hand — e.g. a Neovim tarball under `/opt` — has no entry, so it never shows up in Nautilus's **Open With…**, regardless of being on your `PATH`. Drop a user-level entry:

```ini
# ~/.local/share/applications/nvim.desktop
[Desktop Entry]
Type=Application
Name=Neovim
Comment=Edit text files in Neovim (opens in a terminal)
Exec=kitty -e nvim %F
Terminal=false
Icon=/opt/nvim-linux-x86_64/share/icons/hicolor/128x128/apps/nvim.png
Categories=Utility;TextEditor;
MimeType=text/plain;text/markdown;text/x-shellscript;application/json;
```

Then `update-desktop-database ~/.local/share/applications/`. Because Neovim is a TUI, launch it *through* a terminal (`kitty -e nvim %F`) with `Terminal=false`, rather than `Terminal=true` — the latter hands off to whatever the session's terminal-launcher resolves to, which is unreliable in a mixed Sway/GNOME setup. Adjust `MimeType=` to control which file types offer Neovim. (Paths here are examples: `/opt/nvim-linux-x86_64/...` is where the official Linux tarball lands — substitute your own.)

### `sudo <tool>` can't find a hand-installed binary

Same root cause, different surface. `sudo` ignores your shell's `PATH` and uses the `secure_path` compiled into `/etc/sudoers` (Debian default `/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin`). A binary you export from `~/.bashrc` (say `/opt/nvim-linux-x86_64/bin`) is on *your* PATH but invisible to root. Symlink it into a dir that's already in `secure_path` rather than widening `secure_path` itself:

```bash
sudo ln -s /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim
```

The binary still resolves its own runtime through the symlink. (The `secure_path` dir set varies by distro — check your `/etc/sudoers` if `/usr/local/bin` isn't in it.)

## Portals

The canonical wlroots stack is **`xdg-desktop-portal-gtk`** (file chooser, settings, open-with) **+ `xdg-desktop-portal-wlr`** (screenshot / screencast). `/usr/share/xdg-desktop-portal/sway-portals.conf` already requests `wlr;gtk`:

```
[preferred]
default=wlr;gtk;
```

If screensharing fails to find a source, the wlr backend is missing:

```bash
sudo apt install xdg-desktop-portal-wlr
systemctl --user restart xdg-desktop-portal.service
```

`xdg-desktop-portal-gnome` may stay installed (pulled in by the GNOME fallback session); the preference list above steers Sway to wlr/gtk regardless.

## Verifying

```bash
cat ~/.config/xdg-terminals.list                 # kitty.desktop
gio mime text/plain                              # org.gnome.TextEditor.desktop
ls /usr/share/xdg-desktop-portal/portals/        # gtk + wlr present
```
