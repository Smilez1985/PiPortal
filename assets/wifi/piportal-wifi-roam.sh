#!/usr/bin/env bash
# =============================================================================
#  PiPortal – WLAN-Roaming-Daemon
#  Bevorzugt das Heim-WLAN, nutzt den Handy-Hotspot als Fallback und wechselt
#  aktiv zurück, sobald das Heimnetz wieder in Reichweite ist.
#
#  Läuft dauerhaft unter der systemd-Unit piportal-wifi-roam.service.
#  SSIDs kommen aus /etc/piportal/piportal.conf – nichts ist hier hartcodiert.
# =============================================================================
set -uo pipefail

CONF="/etc/piportal/piportal.conf"
WIFI_HOME_SSID=""
WIFI_ROAM_INTERVAL="15"
# shellcheck disable=SC1090
[ -f "$CONF" ] && . "$CONF"

IFACE="wlan0"
INTERVAL="${WIFI_ROAM_INTERVAL:-15}"

log() { printf '[piportal-wifi-roam] %s\n' "$*"; }

wpa() { wpa_cli -i "$IFACE" "$@" 2>/dev/null; }

# Findet die Netzwerk-ID eines SSID in der wpa_supplicant-Konfiguration.
net_id_for() {
    local ssid="$1"
    wpa list_networks | awk -F'\t' -v s="$ssid" '$2==s {print $1; exit}'
}

log "gestartet (Intervall ${INTERVAL}s, Heim-SSID: ${WIFI_HOME_SSID:-<keine>})"

while true; do
    # 1. Keine IP => Verbindungsaufbau neu anstoßen.
    if ! ip -4 addr show "$IFACE" 2>/dev/null | grep -q 'inet '; then
        wpa reconfigure >/dev/null
        wpa reassociate >/dev/null
    else
        # 2. Verbunden – wenn NICHT im Heim-WLAN, prüfen ob es erreichbar ist.
        if [ -n "$WIFI_HOME_SSID" ]; then
            current="$(wpa status | sed -n 's/^ssid=//p')"
            if [ "$current" != "$WIFI_HOME_SSID" ]; then
                home_id="$(net_id_for "$WIFI_HOME_SSID")"
                if [ -n "$home_id" ]; then
                    if wpa scan_results | awk -F'\t' '{print $NF}' | grep -qxF "$WIFI_HOME_SSID"; then
                        log "Heim-WLAN in Reichweite – wechsle zurück (id ${home_id})."
                        wpa select_network "$home_id" >/dev/null
                    else
                        wpa scan >/dev/null
                    fi
                fi
            fi
        fi
    fi
    sleep "$INTERVAL"
done
