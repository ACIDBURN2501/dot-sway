#!/usr/bin/env bash
set -euo pipefail

# monitor-hotplug.sh
#
# A robust alternative to Kanshi for handling monitor hotplugging.
# - Listens for Sway output events.
# - Enforces a strict policy: 
#   If ANY external monitor is connected:
#     1. Enable it (active)
#     2. Move all workspaces to it
#     3. Disable the internal display (eDP-1)
#   Else (no external monitor):
#     1. Enable internal display
#     2. Move all workspaces to it
#
# This mimics macOS/clamshell behavior where connecting a dock instantly
# switches everything to the external screen.

# --- Configuration ---
INTERNAL_OUTPUT="eDP-1"
# Target resolution/scale for the external display.
# Adjust these if your 4K monitor needs specific settings.
EXT_RES="3840x2160@60Hz"
EXT_SCALE="1"

# --- Logic ---

LOG_FILE="/tmp/sway-monitor-hotplug.log"
CURRENT_STATE=""

log() {
  echo "[$(date '+%H:%M:%S')] $*" >> "$LOG_FILE"
}

move_workspaces() {
  local target="$1"
  log "Moving all workspaces to $target"
  # Use criteria to move workspaces without switching focus to them
  # This prevents the "jumping" behavior
  for ws in $(swaymsg -t get_workspaces -r | jq -r '.[].name'); do
    swaymsg "[workspace=\"$ws\"] move workspace to output $target" >/dev/null 2>&1 || true
  done
}

update_monitors() {
  # Get all outputs (both active and inactive/disabled)
  outputs_json=$(swaymsg -t get_outputs)
  
  # Find an external monitor.
  # Logic: Select the first output that is NOT the internal one.
  ext_output=$(echo "$outputs_json" | jq -r ".[] | select(.name != \"$INTERNAL_OUTPUT\") | .name" | head -n1)
  
  if [[ -n "$ext_output" && "$ext_output" != "null" ]]; then
    # New state: Docked to specific output
    NEW_STATE="docked:$ext_output"
    
    if [[ "$CURRENT_STATE" != "$NEW_STATE" ]]; then
      log "External detected: $ext_output. Switching to docked mode."
      
      # 1. Enable external
      swaymsg output "$ext_output" enable mode "$EXT_RES" scale "$EXT_SCALE" pos 0 0
      
      # 2. Move workspaces
      move_workspaces "$ext_output"
      
      # 3. Disable internal
      swaymsg output "$INTERNAL_OUTPUT" disable
      
      CURRENT_STATE="$NEW_STATE"
    else
      log "State unchanged ($CURRENT_STATE). Ignoring event."
    fi
    
  else
    # New state: Mobile
    NEW_STATE="mobile"
    
    if [[ "$CURRENT_STATE" != "$NEW_STATE" ]]; then
      log "No external detected. Switching to mobile mode."
      
      # 1. Enable internal
      swaymsg output "$INTERNAL_OUTPUT" enable
      
      # 2. Move workspaces
      move_workspaces "$INTERNAL_OUTPUT"
      
      # No need to disable external as it's gone
      
      CURRENT_STATE="$NEW_STATE"
    else
      log "State unchanged ($CURRENT_STATE). Ignoring event."
    fi
  fi
}

# --- Execution ---

# Run once on startup to set correct state
update_monitors

# Listen for events
# We look for "change" events on the "output" IPC channel
swaymsg -m -t subscribe '["output"]' | \
while read -r event; do
  if echo "$event" | grep -q "change"; then
    # Add a tiny sleep to allow the kernel/sway to settle hardware state
    sleep 0.5
    update_monitors
  fi
done
