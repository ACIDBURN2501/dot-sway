# Utility scripts

The following scripts are used in some of the Swayfx configuration or supporting status scripts. They should be placed into:

```bash
$HOME/.local/bin/
```

- `move-ws-to-active.sh`: Moves all workspaces to the currently focused output.
- `move-ws-to-output.sh`: Moves all workspaces to a specific output (arg 1).
- `toggle-touchpad.sh`: Toggles the touchpad on/off and sends a notification.
- `monitor-hotplug.sh`: **(New)** Auto-switches between "Mobile" (internal screen only) and "Docked" (external screen only) modes, moving workspaces automatically. Replaces `kanshi` for a stricter, macOS-like hotplug experience.
