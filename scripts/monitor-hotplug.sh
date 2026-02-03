#!/usr/bin/env bash
set -euo pipefail
# monitor-hotplug.sh
# Robust monitor hotplugging and clamshell mode for Sway
# Optimized for ThinkPad T480

# --- Configuration ---
INTERNAL_OUTPUT="eDP-1"
EXT_RES="3840x2160@60Hz"
EXT_SCALE="1"
LOG_FILE="/tmp/sway-monitor-hotplug.log"
SUSPEND_DELAY=5

# Set to "false" to enable extended mode (both screens on) when external is connected
DISABLE_INTERNAL_ON_EXTERNAL="true"

# --- State ---
CURRENT_STATE=""

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

get_lid_state() {
  if [[ -f /proc/acpi/button/lid/LID/state ]]; then
    awk '{print $2}' /proc/acpi/button/lid/LID/state
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
  
  local lid_state
  lid_state=$(get_lid_state)
  
  # Find an external monitor
  local ext_output
  ext_output=$(echo "$outputs_json" | jq -r ".[] | select(.name != \"$INTERNAL_OUTPUT\") | .name" | head -n1)
  
  if [[ -n "$ext_output" && "$ext_output" != "null" ]]; then
    NEW_STATE="docked:$ext_output:$lid_state"
    
    if [[ "$CURRENT_STATE" != "$NEW_STATE" ]]; then
      log "Action: Docked mode. Output: $ext_output, Lid: $lid_state"
      
      # Enable external
      swaymsg output "$ext_output" enable mode "$EXT_RES" scale "$EXT_SCALE" pos 0 0 || log "Warning: Failed to enable $ext_output"
      
      # Move workspaces
      move_workspaces "$ext_output"
      
      # Handle internal display
      if [[ "$lid_state" == "closed" ]] || [[ "$DISABLE_INTERNAL_ON_EXTERNAL" == "true" ]]; then
        log "Disabling internal display $INTERNAL_OUTPUT (Lid: $lid_state, Config: $DISABLE_INTERNAL_ON_EXTERNAL)"
        swaymsg output "$INTERNAL_OUTPUT" disable || true
      else
        log "Enabling internal display $INTERNAL_OUTPUT (extended)"
        swaymsg output "$INTERNAL_OUTPUT" enable pos 3840 0 || true
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
      ext_output=$(echo "$outputs_json" | jq -r ".[] | select(.name != \"$INTERNAL_OUTPUT\") | .name" | head -n1)
      
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
      log "Action: Mobile mode. Enabling $INTERNAL_OUTPUT"
      
      # Be extremely aggressive about enabling the internal display
      swaymsg output "$INTERNAL_OUTPUT" enable pos 0 0 || true
      swaymsg output "$INTERNAL_OUTPUT" dpms on || true
      
      # Move workspaces
      move_workspaces "$INTERNAL_OUTPUT"
      
      # Verify if it's actually active
      local active
      active=$(swaymsg -t get_outputs | jq -r ".[] | select(.name == \"$INTERNAL_OUTPUT\") | .active")
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
  fi
done
