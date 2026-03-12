#!/usr/bin/env bash
set -euo pipefail
# monitor-hotplug.sh
# Robust monitor hotplugging and clamshell mode for Sway

# --- Configuration ---
# Internal display: auto-detected (any eDP-* output).
# Override with DOTSWAY_INTERNAL_OUTPUT env var or set directly here.
INTERNAL_OUTPUT="${DOTSWAY_INTERNAL_OUTPUT:-}"

# External monitor settings. Override via environment variables before starting Sway,
# e.g. in ~/.config/sway/config.d/local or your shell profile.
#   DOTSWAY_EXT_RES    — mode string passed to `swaymsg output … mode`
#                        Default: "preferred" (uses the display's native/preferred mode)
#   DOTSWAY_EXT_SCALE  — output scale factor
#                        Default: 1 (no scaling; safe for any display)
#   DOTSWAY_EXT_ADAPTIVE_SYNC — "on" or "off"
#                        Default: "on" (not supported on all hardware/drivers)
EXT_RES="${DOTSWAY_EXT_RES:-preferred}"
EXT_SCALE="${DOTSWAY_EXT_SCALE:-1}"
EXT_ADAPTIVE_SYNC="${DOTSWAY_EXT_ADAPTIVE_SYNC:-on}"
LOG_FILE="/tmp/sway-monitor-hotplug.log"
SUSPEND_DELAY=5

# Set to "false" to enable extended mode (both screens on) when external is connected
DISABLE_INTERNAL_ON_EXTERNAL="true"

# --- State ---
CURRENT_STATE=""

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

disable_output() {
  local output="$1"
  local i
  for i in 1 2 3; do
    if swaymsg output "$output" disable 2>/dev/null; then
      log "Disabled $output (attempt $i)"
      return 0
    fi
    log "Warning: Failed to disable $output (attempt $i/3), retrying..."
    sleep 1
  done
  log "Error: Could not disable $output after 3 attempts"
  return 1
}

get_lid_state() {
  local lid_file
  lid_file=$(ls /proc/acpi/button/lid/*/state 2>/dev/null | head -n1)
  if [[ -n "$lid_file" ]]; then
    awk '{print $2}' "$lid_file"
  else
    echo "unknown"
  fi
}

move_workspaces() {
  local target="$1"
  log "Moving all workspaces to $target"
  local workspaces_json
  workspaces_json=$(swaymsg -t get_workspaces -r 2>/dev/null | jq -c . || echo "[]")
  
  echo "$workspaces_json" | jq -r '.[].name' 2>/dev/null | while read -r ws; do
    if [[ -n "$ws" ]]; then
      # Use the workspace name exactly as read (handles spaces)
      swaymsg "[workspace=\"$ws\"] move workspace to output $target" >/dev/null 2>&1 || true
    fi
  done
}

update_monitors() {
  log "Updating monitor state..."

  local outputs_json
  outputs_json=$(swaymsg -t get_outputs 2>/dev/null)
  if [[ -z "$outputs_json" ]]; then
    log "Error: Could not get outputs from swaymsg."
    return 1
  fi

  # Auto-detect internal display if not explicitly configured
  local internal_output="$INTERNAL_OUTPUT"
  if [[ -z "$internal_output" ]]; then
    internal_output=$(echo "$outputs_json" | jq -r '.[] | select(.name | startswith("eDP")) | .name' | head -n1)
    if [[ -z "$internal_output" ]]; then
      log "Warning: Could not detect internal eDP display."
    fi
  fi

  local lid_state
  lid_state=$(get_lid_state)

  # Find an external monitor (anything that is not an eDP built-in panel)
  local ext_output
  ext_output=$(echo "$outputs_json" | jq -r '.[] | select(.name | startswith("eDP") | not) | .name' | head -n1)
  
  if [[ -n "$ext_output" && "$ext_output" != "null" ]]; then
    NEW_STATE="docked:$ext_output:$lid_state"
    
    if [[ "$CURRENT_STATE" != "$NEW_STATE" ]]; then
      log "Action: Docked mode. Output: $ext_output, Lid: $lid_state"
      
      # Enable external and wait for DRM atomic commit to settle
      swaymsg output "$ext_output" enable mode "$EXT_RES" scale "$EXT_SCALE" pos 0 0 adaptive_sync "$EXT_ADAPTIVE_SYNC" || log "Warning: Failed to enable $ext_output"
      sleep 1

      # Move workspaces
      move_workspaces "$ext_output"
      
      # Handle internal display
      if [[ -n "$internal_output" ]]; then
        if [[ "$lid_state" == "closed" ]] || [[ "$DISABLE_INTERNAL_ON_EXTERNAL" == "true" ]]; then
          log "Disabling internal display $internal_output (Lid: $lid_state, Config: $DISABLE_INTERNAL_ON_EXTERNAL)"
          disable_output "$internal_output" || true
        else
          log "Enabling internal display $internal_output (extended)"
          swaymsg output "$internal_output" enable pos 3840 0 || true
        fi
      fi
      
      CURRENT_STATE="$NEW_STATE"
    fi
  else
    # No external monitor detected
    if [[ "$lid_state" == "closed" ]]; then
      log "Lid closed and no external monitor. Grace period ${SUSPEND_DELAY}s..."
      sleep $SUSPEND_DELAY
      
      # Re-check
      outputs_json=$(swaymsg -t get_outputs 2>/dev/null || echo "[]")
      ext_output=$(echo "$outputs_json" | jq -r '.[] | select(.name | startswith("eDP") | not) | .name' | head -n1)
      
      if [[ -n "$ext_output" && "$ext_output" != "null" ]]; then
        log "External monitor detected after grace period. Continuing."
        CURRENT_STATE="" # Force update
        update_monitors
        return
      fi
      
      log "Action: Suspending system (Lid closed, no external)"
      CURRENT_STATE="" 
      systemctl suspend
      return
    fi

    # Mobile mode
    NEW_STATE="mobile:$lid_state"
    if [[ "$CURRENT_STATE" != "$NEW_STATE" ]]; then
      log "Action: Mobile mode. Enabling $internal_output"

      # Be extremely aggressive about enabling the internal display
      swaymsg output "$internal_output" enable pos 0 0 || true
      swaymsg output "$internal_output" dpms on || true

      # Move workspaces
      move_workspaces "$internal_output"

      # Verify if it's actually active
      local active
      active=$(swaymsg -t get_outputs | jq -r ".[] | select(.name == \"$internal_output\") | .active")
      if [[ "$active" != "true" ]]; then
        log "Warning: Internal output still not active. Forcing reload..."
        swaymsg reload
      fi
      
      CURRENT_STATE="$NEW_STATE"
    fi
  fi
}

# --- Main Daemon ---

if [[ "${1:-}" == "--once" ]]; then
  update_monitors || exit 1
  exit 0
fi

# Singleton: Kill other instances
current_pid=$$
for pid in $(pgrep -f "monitor-hotplug.sh"); do
    if [[ "$pid" != "$current_pid" ]]; then
        echo "Killing old instance: $pid" >> "$LOG_FILE"
        kill "$pid" 2>/dev/null || true
    fi
done

log "Monitor hotplug daemon started (PID: $$)"
update_monitors || true

while true; do
  # Subscribe to output events only.
  # Use jq to ensure we read one valid JSON object per line.
  if ! swaymsg -m -t subscribe '["output"]' 2>/dev/null | jq --unbuffered -c '.' | while read -r event; do
    # Log the event for debugging
    # log "Sway event: $(echo "$event" | jq -c .change 2>/dev/null || echo "switch")"
    
    # Process output events
    update_monitors || true
  done; then
    log "Warning: swaymsg subscription lost. Restarting in 2s..."
    sleep 2
    update_monitors || true  # Re-apply after sway reload/restart
  fi
done
