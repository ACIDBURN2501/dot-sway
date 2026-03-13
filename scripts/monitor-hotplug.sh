#!/usr/bin/env bash
set -euo pipefail
# monitor-hotplug.sh
# Robust monitor hotplugging and clamshell mode for Sway

# --- Configuration ---
# Internal display: auto-detected (any eDP-* output).
# Override with DOTSWAY_INTERNAL_OUTPUT env var or set directly here.
INTERNAL_OUTPUT="${DOTSWAY_INTERNAL_OUTPUT:-}"

# External monitor settings. Environment variables override everything.
# Otherwise, the script uses per-monitor profile overrides from
# ~/.config/sway/scripts/monitor-profiles.local.sh when available, and finally
# falls back to universal defaults.
#   DOTSWAY_EXT_RES    — mode string passed to `swaymsg output … mode`
#                        Default fallback: "1920x1080@60Hz"
#   DOTSWAY_EXT_SCALE  — output scale factor
#                        Default fallback: 1
#   DOTSWAY_EXT_ADAPTIVE_SYNC — "on" or "off"
#                        Default fallback: "off"
DEFAULT_EXT_RES="1920x1080@60Hz"
DEFAULT_EXT_SCALE="1"
DEFAULT_EXT_ADAPTIVE_SYNC="off"
MONITOR_PROFILES_FILE="${DOTSWAY_MONITOR_PROFILES_FILE:-$HOME/.config/sway/scripts/monitor-profiles.local.sh}"
LOG_FILE="/tmp/sway-monitor-hotplug.log"
SUSPEND_DELAY=5

# Set to "false" to enable extended mode (both screens on) when external is connected
DISABLE_INTERNAL_ON_EXTERNAL="true"

# --- State ---
CURRENT_STATE=""
PROFILE_EXT_RES=""
PROFILE_EXT_SCALE=""
PROFILE_EXT_ADAPTIVE_SYNC=""

if [[ -f "$MONITOR_PROFILES_FILE" ]]; then
  # shellcheck disable=SC1090
  . "$MONITOR_PROFILES_FILE"
fi

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

sanitize_jq_value() {
  local value="${1:-}"
  if [[ "$value" == "null" ]]; then
    printf ''
    return 0
  fi
  printf '%s' "$value"
}

set_monitor_profile() {
  PROFILE_EXT_RES="${1:-}"
  PROFILE_EXT_SCALE="${2:-}"
  PROFILE_EXT_ADAPTIVE_SYNC="${3:-}"
}

reset_monitor_profile() {
  PROFILE_EXT_RES=""
  PROFILE_EXT_SCALE=""
  PROFILE_EXT_ADAPTIVE_SYNC=""
}

resolve_external_settings() {
  local output_json="$1"
  local output_name make model serial
  local resolved_res resolved_scale resolved_adaptive_sync
  local res_source scale_source adaptive_sync_source

  output_name=$(sanitize_jq_value "$(jq -r '.name // empty' <<< "$output_json")")
  make=$(sanitize_jq_value "$(jq -r '.make // empty' <<< "$output_json")")
  model=$(sanitize_jq_value "$(jq -r '.model // empty' <<< "$output_json")")
  serial=$(sanitize_jq_value "$(jq -r '.serial // empty' <<< "$output_json")")

  reset_monitor_profile
  if declare -F dotsway_monitor_profile >/dev/null 2>&1; then
    dotsway_monitor_profile "$output_name" "$make" "$model" "$serial" || true
  fi

  resolved_res="$DEFAULT_EXT_RES"
  res_source="default"
  if [[ -n "$PROFILE_EXT_RES" ]]; then
    resolved_res="$PROFILE_EXT_RES"
    res_source="profile"
  fi
  if [[ -n "${DOTSWAY_EXT_RES:-}" ]]; then
    resolved_res="$DOTSWAY_EXT_RES"
    res_source="env"
  fi

  resolved_scale="$DEFAULT_EXT_SCALE"
  scale_source="default"
  if [[ -n "$PROFILE_EXT_SCALE" ]]; then
    resolved_scale="$PROFILE_EXT_SCALE"
    scale_source="profile"
  fi
  if [[ -n "${DOTSWAY_EXT_SCALE:-}" ]]; then
    resolved_scale="$DOTSWAY_EXT_SCALE"
    scale_source="env"
  fi

  resolved_adaptive_sync="$DEFAULT_EXT_ADAPTIVE_SYNC"
  adaptive_sync_source="default"
  if [[ -n "$PROFILE_EXT_ADAPTIVE_SYNC" ]]; then
    resolved_adaptive_sync="$PROFILE_EXT_ADAPTIVE_SYNC"
    adaptive_sync_source="profile"
  fi
  if [[ -n "${DOTSWAY_EXT_ADAPTIVE_SYNC:-}" ]]; then
    resolved_adaptive_sync="$DOTSWAY_EXT_ADAPTIVE_SYNC"
    adaptive_sync_source="env"
  fi

  log "Resolved external settings for $output_name ($make $model ${serial:-no-serial}): mode=$resolved_res [$res_source], scale=$resolved_scale [$scale_source], adaptive_sync=$resolved_adaptive_sync [$adaptive_sync_source]"

  printf '%s|%s|%s\n' "$resolved_res" "$resolved_scale" "$resolved_adaptive_sync"
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
  local ext_output_json
  local resolved_ext_settings
  local ext_res
  local ext_scale
  local ext_adaptive_sync
  ext_output_json=$(echo "$outputs_json" | jq -c '.[] | select(.name | startswith("eDP") | not)' | head -n1)
  if [[ -n "$ext_output_json" ]]; then
    ext_output=$(sanitize_jq_value "$(jq -r '.name // empty' <<< "$ext_output_json")")
  else
    ext_output=""
  fi
  
  if [[ -n "$ext_output" ]]; then
    NEW_STATE="docked:$ext_output:$lid_state"
    
    if [[ "$CURRENT_STATE" != "$NEW_STATE" ]]; then
      log "Action: Docked mode. Output: $ext_output, Lid: $lid_state"
      resolved_ext_settings=$(resolve_external_settings "$ext_output_json")
      IFS='|' read -r ext_res ext_scale ext_adaptive_sync <<< "$resolved_ext_settings"
      
      # Enable external and wait for DRM atomic commit to settle
      swaymsg output "$ext_output" enable mode "$ext_res" scale "$ext_scale" pos 0 0 adaptive_sync "$ext_adaptive_sync" || log "Warning: Failed to enable $ext_output"
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
