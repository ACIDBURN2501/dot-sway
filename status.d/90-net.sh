#!/usr/bin/env bash

set -euo pipefail

# Icons (Nerd-Font compatible)
ICON_WIFI=' ' # Wi-Fi
ICON_ETH='󰈀 '  # Ethernet

# ---- helpers ---------------------------------------------------------------

is_wireless() {
  # True if interface has a wireless directory
  [[ -d "/sys/class/net/$1/wireless" ]]
}

is_vpn_like() {
  # Skip common VPN/tunnel interfaces in this widget
  case "$1" in
  lo | tun* | tap* | wg* | tailscale* | ts* | zt* | vpn*) return 0 ;;
  *) return 1 ;;
  esac
}

has_carrier_1() {
  local f="/sys/class/net/$1/carrier"
  [[ -r "$f" ]] && {
    IFS= read -r val <"$f"
    [[ "$val" -eq 1 ]]
  }
}

is_oper_up() {
  local f="/sys/class/net/$1/operstate"
  [[ -r "$f" ]] && {
    IFS= read -r val <"$f"
    [[ "$val" == "up" ]]
  }
}

is_linked() {
  # Prefer carrier when available; otherwise fall back to operstate
  if has_carrier_1 "$1"; then
    return 0
  else
    is_oper_up "$1"
  fi
}

default_route_iface() {
  # Parse /proc/net/route without external tools; return iface for the default
  # Route lines: Iface  Destination  Gateway  Flags  RefCnt  Use  Metric  Mask ...
  local line iface dest mask
  # shellcheck disable=SC2162
  while IFS=$'\t ' read -r iface dest _ _ _ _ _ mask _; do
    # default route: Destination == 00000000 and Mask == 00000000
    [[ "$dest" == "00000000" && "$mask" == "00000000" ]] || continue
    printf '%s\n' "$iface"
    return 0
  done </proc/net/route
  return 1
}

emit_icon_for_iface() {
  if is_wireless "$1"; then
    printf '%s\n' "$ICON_WIFI"
  else
    printf '%s\n' "$ICON_ETH"
  fi
}

# ---- selection logic -------------------------------------------------------

# 1) If we have a default route iface that isn't VPN-like and is linked, use it.
if ifdef="$(default_route_iface)"; then
  if ! is_vpn_like "$ifdef" && is_linked "$ifdef"; then
    emit_icon_for_iface "$ifdef"
    exit 0
  fi
fi

# 2) Otherwise, prefer any linked Wi-Fi over Ethernet.
best_wifi=""
best_wired=""
for path in /sys/class/net/*; do
  iface="${path##*/}"
  is_vpn_like "$iface" && continue
  [[ "$iface" == "lo" ]] && continue
  if is_linked "$iface"; then
    if is_wireless "$iface"; then
      best_wifi="$iface"
      break # any linked Wi-Fi is good enough
    else
      # remember a wired candidate in case no Wi-Fi is linked
      best_wired="${best_wired:-$iface}"
    fi
  fi
done

if [[ -n "${best_wifi}" ]]; then
  emit_icon_for_iface "$best_wifi"
  exit 0
fi

if [[ -n "${best_wired}" ]]; then
  emit_icon_for_iface "$best_wired"
  exit 0
fi

# 3) Nothing linked = emit nothing (keep bar clean)
exit 0
