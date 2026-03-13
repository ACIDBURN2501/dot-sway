#!/usr/bin/env bash

# monitor-profiles.example.sh — per-monitor settings for monitor-hotplug.sh
#
# Copy this file to ~/.config/sway/scripts/monitor-profiles.local.sh and edit
# as needed. The hotplug script sources it automatically on startup.
#
# The script calls dotsway_monitor_profile() for each connected external output
# with the following arguments:
#   $1 = output name (e.g. DP-2, HDMI-A-1)
#   $2 = make        (e.g. "Dell Inc.")
#   $3 = model       (e.g. "DELL U2725QE")
#   $4 = serial      (e.g. "18J0584", or empty if not reported)
#
# To find these values for your monitor, run:
#   swaymsg -t get_outputs -r | jq -r '.[] | select(.name | startswith("eDP") | not) | [.name, .make, .model, .serial] | @tsv'
#
# Inside the function, call set_monitor_profile with three positional arguments:
#   set_monitor_profile MODE SCALE ADAPTIVE_SYNC
#
#   MODE          — mode string passed to `swaymsg output … mode`
#                   (e.g. '3840x2160@120Hz', '1920x1080@60Hz')
#   SCALE         — output scale factor (e.g. '1', '1.25', '2')
#   ADAPTIVE_SYNC — 'on' or 'off'
#
# Leave any argument empty to keep the script's fallback default for that field.
#
# Match on serial when you want to target one specific physical unit.
# Omit the serial (leave it empty in the pattern) to match any monitor of that
# make and model regardless of which unit it is.
#
# After editing, run:
#   swaymsg reload && ~/.config/sway/scripts/monitor-hotplug.sh --once
#
# Check /tmp/sway-monitor-hotplug.log to confirm which source was applied
# (default / profile / env).

dotsway_monitor_profile() {
  local _output_name="$1"
  local make="$2"
  local model="$3"
  local serial="$4"

  case "$make|$model|$serial" in

    # --- 4K 120 Hz display (match any unit of this model) ---
    # 'ExampleMake|ExampleModel|')
    #   set_monitor_profile '3840x2160@120Hz' '1' 'on'
    #   ;;

    # --- 1080p 60 Hz display (match a specific serial) ---
    # 'ExampleMake|ExampleModel|SERIALHERE')
    #   set_monitor_profile '1920x1080@60Hz' '1' 'off'
    #   ;;

    *)
      : # fall through to universal default
      ;;
  esac
}
