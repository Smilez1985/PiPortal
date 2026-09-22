#!/usr/bin/env bash
# =============================================================================
#  PiPortal – Modul 20: WLAN-Roaming
#  - Schreibt zwei WLAN-Profile (Heim bevorzugt, Hotspot Fallback) in
#    wpa_supplicant.conf – nur wenn SSIDs in der Config gesetzt sind.
#  - Installiert den Roaming-Daemon als systemd-Service (ersetzt das alte
#    custom.sh im DietPi-Autostart).
# =============================================================================

module_20_wifi_roaming() {
    log_step "Phase 2 – WLAN-Roaming (Heim bevorzugt, Hotspot Fallback)"

    # WLAN-Werkzeuge sicherstellen (wpa_cli wird vom Roaming-Dienst gebraucht).
    ensure_pkg wpasupplicant iw

    local wpa="/etc/wpa_supplicant/wpa_supplicant.conf"

    if [ -z "${WIFI_HOME_SSID}" ] && [ -z "${WIFI_HOTSPOT_SSID}" ]; then
        log_skip "Keine SSIDs in config/piportal.conf – vorhandene WLAN-Konfiguration bleibt unangetastet."
    else
        # Sicherheitsnetz: funktionierende wpa_supplicant.conf VOR dem Schreiben
        # als .tgz sichern – sie darf nie mit leeren/kaputten Werten enden.
        local wpa_bak=""
        if [ -f "$wpa" ]; then
            wpa_bak="${BACKUP_DIR:-/var/backups/piportal}/wpa_supplicant.conf.$(date +%Y%m%d_%H%M%S).tgz"
            ensure_dir "$(dirname "$wpa_bak")" 0700 >/dev/null
            if tar czf "$wpa_bak" -C / "etc/wpa_supplicant/wpa_supplicant.conf" 2>/dev/null; then
                log_ok "wpa_supplicant.conf gesichert: $wpa_bak"
            else
                log_warn "Backup der wpa_supplicant.conf fehlgeschlagen"; wpa_bak=""
            fi
        fi

        # Interaktiv fehlende Passwörter nachfragen.
        [ -n "${WIFI_HOME_SSID}" ]    && [ -z "${WIFI_HOME_PSK}" ]    && ask_secret "Passwort für Heim-WLAN '${WIFI_HOME_SSID}'" WIFI_HOME_PSK
        [ -n "${WIFI_HOTSPOT_SSID}" ] && [ -z "${WIFI_HOTSPOT_PSK}" ] && ask_secret "Passwort für Hotspot '${WIFI_HOTSPOT_SSID}'" WIFI_HOTSPOT_PSK

        {
            echo "# Von PiPortal verwaltet."
            echo "country=${WIFI_COUNTRY}"
            echo "ctrl_interface=DIR=/run/wpa_supplicant GROUP=netdev"
            echo "update_config=1"
            echo "bgscan=\"${WIFI_BGSCAN}\""
            echo ""
            if [ -n "${WIFI_HOME_SSID}" ]; then
                echo "# ID 0: Heim-WLAN (bevorzugt)"
                echo "network={"
                echo "    ssid=\"${WIFI_HOME_SSID}\""
                echo "    psk=\"${WIFI_HOME_PSK}\""
                echo "    scan_ssid=1"
                echo "    key_mgmt=WPA-PSK"
                echo "    priority=100"
                echo "}"
                echo ""
            fi
            if [ -n "${WIFI_HOTSPOT_SSID}" ]; then
                echo "# ID 1: Handy-Hotspot (Fallback)"
                echo "network={"
                echo "    ssid=\"${WIFI_HOTSPOT_SSID}\""
                echo "    psk=\"${WIFI_HOTSPOT_PSK}\""
                echo "    scan_ssid=1"
                echo "    key_mgmt=WPA-PSK"
                echo "    priority=1"
                echo "}"
            fi
        } | write_file_if_changed "$wpa" 0600

        # Verifizieren: enthaelt die neue Datei ueberhaupt ein network={...}?
        # Wenn nicht (leer/kaputt), sofort aus dem Backup zurueckspielen.
        if ! grep -q 'network={' "$wpa" 2>/dev/null; then
            log_err "Neue wpa_supplicant.conf enthaelt kein Netzwerk – stelle Backup wieder her."
            if [ -n "$wpa_bak" ] && [ -f "$wpa_bak" ]; then
                tar xzf "$wpa_bak" -C / && log_ok "wpa_supplicant.conf aus Backup wiederhergestellt."
            else
                log_err "Kein Backup verfuegbar – bitte WLAN-Konfiguration von Hand pruefen!"
            fi
        fi

        wpa_cli -i wlan0 reconfigure >/dev/null 2>&1 || true
        log_ok "WLAN-Profile geschrieben."
    fi

    # --- Roaming-Daemon installieren ---
    install_file "${PIPORTAL_ASSETS_DIR}/wifi/piportal-wifi-roam.sh" "${PIPORTAL_SBIN}/piportal-wifi-roam.sh" 0755
    install_file "${PIPORTAL_ASSETS_DIR}/systemd/piportal-wifi-roam.service" /etc/systemd/system/piportal-wifi-roam.service 0644

    # Altes DietPi-custom.sh-Roaming stilllegen, falls vorhanden.
    local old="/var/lib/dietpi/dietpi-autostart/custom.sh"
    if [ -f "$old" ] && grep -q 'wpa_cli' "$old" 2>/dev/null && ! grep -q 'PiPortal deaktiviert' "$old" 2>/dev/null; then
        {
            echo "#!/bin/bash"
            echo "# PiPortal deaktiviert: Roaming läuft jetzt über piportal-wifi-roam.service."
            echo "exit 0"
        } | write_file_if_changed "$old" 0755
        log_ok "Altes custom.sh-Roaming stillgelegt (durch systemd-Service ersetzt)."
    fi

    enable_service piportal-wifi-roam.service

    # WLAN gegen die SAE/brcmfmac-Regression haerten (sonst kann ein
    # Update-Reboot das WLAN an einem WPA2/WPA3-Transition-AP abwuergen).
    # Die Funktion liegt in lib/common.sh (auch vom Uninstaller genutzt).
    harden_wlan_sae
}
