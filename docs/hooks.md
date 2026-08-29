# Event Hooks

**What:** A drop-in extension point for per-event automation: on each event, every executable in the event's hook directory runs, in sorted order. Tracked hooks ship in the repo; machine-local hooks live in a gitignored overlay.
**Where:** `scripts/hooks.sh` (dispatcher), `hooks/<event>.d/` (tracked), `hooks.local/<event>.d/` (machine-local, gitignored).
**Verified:** `tests/theme-sandbox.sh` (dispatcher section) in CI, plus shellcheck on the dispatcher.

## Events

| Event | Fires | Wired from |
|---|---|---|
| `post-boot` | Once per Sway session start. `exec` (not `exec_always`), so a `swaymsg reload` does not re-fire it. | end of `config` |
| `theme-set` | After every theme flip, as the last side effect of `toggle_theme.sh` (after the flag write, waybar repaint, kitty, and mako). `init` does not fire it. | `scripts/toggle_theme.sh` |

Adding a new event is a one-line change: call `scripts/hooks.sh <event>` from wherever the event happens. The dispatcher is event-agnostic.

## Hook contract

- A hook is any **executable** file in the event's directory. `.sample` files are non-executable and never run; they document the contract.
- A hook receives the **event name as `$1`**.
- A **missing directory is a silent no-op** — the common case on a machine with no hooks.
- A **non-zero exit is logged to stderr and skipped**; the remaining hooks still run. Hooks are fire-and-forget, in sorted filename order.
- The dispatcher resolves the hook directories from its own location, so it works from any install path (including a symlinked `$HOME/.config/sway`).

To activate a hook:

```bash
cp hooks/theme-set.d/theme-set.sample hooks/theme-set.d/myhook.sh
chmod +x hooks/theme-set.d/myhook.sh
```

## Per-machine hooks

`hooks.local/<event>.d/` is executed **after** the tracked hooks for the same event and is ignored by git (explicit `.gitignore` entry, like the other `.local` machine overrides). Machine-specific automation lands in the overlay; tracked samples and hooks stay generic.
