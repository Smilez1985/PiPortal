#!/usr/bin/env bash
# =============================================================================
#  PiPortal – Modul 15: Boot-Tuning
#  Schaltet "Wait for network" beim Boot ab. Im WLAN-AP-/Hotspot-Modus führt
#  das Warten auf ein Netzwerk sonst zu langen Boot-Verzögerungen oder Hängern,
#  während der Pi über usb0 ohnehin sofort erreichbar sein soll.
# =============================================================================

module_15_boot_tuning() {
    log_step "Phase 1.5 – Boot-Tuning (Wait-for-network aus)"

    # 1. DietPi-Schalter in /boot/dietpi.txt (idempotent).
    local dt="/boot/dietpi.txt"
    if [ -f "$dt" ]; then
        if grep -q '^AUTO_SETUP_BOOT_WAIT_FOR_NETWORK=' "$dt"; then
            if grep -q '^AUTO_SETUP_BOOT_WAIT_FOR_NETWORK=0' "$dt"; then
                log_skip "AUTO_SETUP_BOOT_WAIT_FOR_NETWORK bereits 0."
            else
                sed -i 's/^AUTO_SETUP_BOOT_WAIT_FOR_NETWORK=.*/AUTO_SETUP_BOOT_WAIT_FOR_NETWORK=0/' "$dt"
                log_ok "AUTO_SETUP_BOOT_WAIT_FOR_NETWORK auf 0 gesetzt."
            fi
        else
            printf 'AUTO_SETUP_BOOT_WAIT_FOR_NETWORK=0\n' >> "$dt"
            log_ok "AUTO_SETUP_BOOT_WAIT_FOR_NETWORK=0 ergänzt."
        fi
    else
        log_skip "/boot/dietpi.txt nicht vorhanden – DietPi-Schalter übersprungen."
    fi

    # 2. systemd-networkd-wait-online deaktivieren (blockiert sonst boot bei fehlendem Netz).
    if systemctl list-unit-files 2>/dev/null | grep -q '^systemd-networkd-wait-online.service'; then
        if systemctl is-enabled --quiet systemd-networkd-wait-online.service 2>/dev/null; then
            systemctl disable systemd-networkd-wait-online.service >/dev/null 2>&1
            systemctl mask systemd-networkd-wait-online.service >/dev/null 2>&1 || true
            log_ok "systemd-networkd-wait-online deaktiviert."
        else
            log_skip "systemd-networkd-wait-online bereits deaktiviert."
        fi
    fi

    # 3. Analog NetworkManager-wait-online, falls vorhanden.
    if systemctl list-unit-files 2>/dev/null | grep -q '^NetworkManager-wait-online.service'; then
        systemctl disable NetworkManager-wait-online.service >/dev/null 2>&1 || true
        log_ok "NetworkManager-wait-online deaktiviert (falls aktiv)."
    fi

    log_info "Der Pi bootet ohne Netzwerk-Wartezeit durch – usb0 ist sofort erreichbar."
}
