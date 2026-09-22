#!/usr/bin/env bash
# =============================================================================
#  PiPortal – WLAN-Roaming-Daemon
#  Bevorzugt das Heim-WLAN, nutzt weitere Netze (z. B. Handy-Hotspot) als
#  Fallback und wechselt aktiv zurück, sobald das Heimnetz wieder in Reichweite
#  ist.
#
#  Quelle der Wahrheit ist das OS (wpa_supplicant.conf, von DietPi verwaltet):
#  Netze, Passwörter UND die Reihenfolge (priority=) liegen dort. Das
#  bevorzugte „Heimnetz" wird live aus der höchsten priority abgeleitet –
#  kein Watcher, kein Kopieren in die Config nötig; ein in DietPi neu
#  hinzugefügtes/höher priorisiertes Netz greift von selbst.
#
#  WIFI_HOME_SSID aus /etc/piportal/piportal.conf ist ein OPTIONALER Override:
#  ist er gesetzt, gilt er; ist er leer (Standard), entscheidet die OS-priority.
#
#  Läuft dauerhaft unter der systemd-Unit piportal-wifi-roam.service.
# =============================================================================
set -uo pipefail
# Deterministische, sprachunabhaengige Werkzeug-Ausgaben (Parsing sicher auf jedem Sprach-OS).
export LC_ALL=C.UTF-8

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

# Bevorzugtes „Heimnetz" bestimmen:
#   1) expliziter Override WIFI_HOME_SSID aus der Config (falls gesetzt), sonst
#   2) das Netz mit der höchsten priority aus dem OS (wpa_supplicant) – live.
# Gibt die SSID aus (oder leer, wenn nichts ermittelbar).
preferred_home_ssid() {
    if [ -n "$WIFI_HOME_SSID" ]; then
        printf '%s\n' "$WIFI_HOME_SSID"
        return 0
    fi
    local best_ssid="" best_prio=-1 id prio ssid
    while IFS=$'\t' read -r id _; do
        case "$id" in ''|'network id'*|*[!0-9]*) continue ;; esac
        prio="$(wpa get_network "$id" priority 2>/dev/null)"
        case "$prio" in ''|*[!0-9-]*) prio=0 ;; esac
        if [ "$prio" -gt "$best_prio" ]; then
            ssid="$(wpa get_network "$id" ssid 2>/dev/null | tr -d '"')"
            best_prio="$prio"
            best_ssid="$ssid"
        fi
    done <<EOF
$(wpa list_networks | tail -n +2)
EOF
    printf '%s\n' "$best_ssid"
}

if [ -n "$WIFI_HOME_SSID" ]; then
    log "gestartet (Intervall ${INTERVAL}s, Heim-Vorzug: '${WIFI_HOME_SSID}' via Config-Override)"
else
    log "gestartet (Intervall ${INTERVAL}s, Heim-Vorzug: höchste OS-priority aus wpa_supplicant)"
fi

while true; do
    # 1. Keine IP => Verbindungsaufbau neu anstoßen.
    if ! ip -4 addr show "$IFACE" 2>/dev/null | grep -q 'inet '; then
        wpa reconfigure >/dev/null
        wpa reassociate >/dev/null
    else
        # 2. Verbunden – Heim-Vorzug LIVE bestimmen (OS-priority oder Override).
        home="$(preferred_home_ssid)"
        if [ -n "$home" ]; then
            current="$(wpa status | sed -n 's/^ssid=//p')"
            # Nur eingreifen, wenn wir NICHT schon im bevorzugten Netz sind.
            if [ "$current" != "$home" ]; then
                home_id="$(net_id_for "$home")"
                if [ -n "$home_id" ]; then
                    if wpa scan_results | awk -F'\t' '{print $NF}' | grep -qxF "$home"; then
                        log "Bevorzugtes Netz '${home}' in Reichweite – wechsle zurück (id ${home_id})."
                        wpa select_network "$home_id" >/dev/null
                        # Nach dem gezielten Wechsel alle Netze wieder als Kandidaten
                        # zulassen, damit Fallback/Reconnect weiter funktioniert.
                        wpa enable_network all >/dev/null
                    else
                        wpa scan >/dev/null
                    fi
                fi
            fi
        fi
    fi
    sleep "$INTERVAL"
done
