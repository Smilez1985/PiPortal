#!/usr/bin/env bash
# =============================================================================
#  PiPortal – Modul 30: USB-Composite-Gadget (configfs)
#  - Aktiviert dwc2, lädt libcomposite früh.
#  - Ersetzt Legacy-g_multi in cmdline.txt durch den configfs-Weg.
#  - Installiert Gadget-Skript + systemd-Unit.
#
#  ACHTUNG: Der Umbau kann die USB-Verbindung kurz unterbrechen. Vor dem
#  Ausführen sicherstellen, dass der Pi auch über WLAN per SSH erreichbar ist.
# =============================================================================

module_30_gadget() {
    log_step "Phase 3 – USB-Composite-Gadget (configfs / libcomposite)"

    local cfg="/boot/firmware/config.txt"
    local cmd="/boot/firmware/cmdline.txt"

    # --- 1. dwc2-Overlay sicherstellen ---
    ensure_line "$cfg" "dtoverlay=dwc2"

    # --- 2. libcomposite früh laden ---
    ensure_line /etc/modules-load.d/piportal.conf "dwc2"
    ensure_line /etc/modules-load.d/piportal.conf "libcomposite"

    # --- 3. Legacy-g_multi aus cmdline.txt entfernen ---
    # cmdline.txt MUSS eine einzige Zeile bleiben.
    if grep -q 'g_multi' "$cmd"; then
        local line
        line="$(tr -d '\n' < "$cmd")"
        # Alle g_multi-Tokens und ein evtl. mitgeführtes modules-load=dwc2,g_multi entfernen.
        line="$(printf '%s' "$line" \
            | sed -E 's/ *modules-load=dwc2,g_multi//g; s/ *g_multi\.[^ ]*//g')"

        # Sanity vor dem Schreiben: cmdline.txt ist die Datei, ohne die der Pi
        # nicht mehr bootet. Fehlt root= oder ist die Zeile leer, wird NICHT
        # geschrieben. Gleiche Absicherung wie bei der SAE-Haertung in
        # lib/common.sh und bei wpa_supplicant.conf in Modul 20.
        if [ -z "$line" ] || ! printf '%s' "$line" | grep -q 'root='; then
            log_err "cmdline-Sanity fehlgeschlagen (kein root= oder leer) – cmdline.txt bleibt unveraendert."
            log_warn "Legacy-g_multi wurde NICHT entfernt. Bitte /boot/firmware/cmdline.txt von Hand pruefen."
        else
            backup_now "$cmd" >/dev/null
            # dwc2 wird jetzt über /etc/modules-load.d geladen – kein modules-load nötig.
            printf '%s\n' "$line" | write_file_if_changed "$cmd" 0755
            log_ok "Legacy-g_multi aus cmdline.txt entfernt (Umstellung auf configfs)."
        fi
    else
        log_skip "cmdline.txt enthält kein g_multi mehr."
    fi

    # --- 3b. Legacy-g_multi-Altlast wegräumen ---
    # Das alte 50-MB-FAT-Image wird vom configfs-Weg nicht mehr genutzt.
    # Nicht löschen, sondern archivieren (Modul 00 hat es zusätzlich gesichert).
    if [ -f /pi-usb-drive.img ]; then
        ensure_dir /srv/piportal/legacy 0755
        mv /pi-usb-drive.img "/srv/piportal/legacy/pi-usb-drive.img.$(date +%Y%m%d_%H%M%S)"
        log_ok "Altes g_multi-Image archiviert nach /srv/piportal/legacy/"
    else
        log_skip "Kein /pi-usb-drive.img vorhanden (bereits migriert)."
    fi
    # Verwaiste g_multi-Zeilen in /etc/modules entfernen (falls dort eingetragen).
    if [ -f /etc/modules ] && grep -q 'g_multi' /etc/modules 2>/dev/null; then
        sed -i '/g_multi/d' /etc/modules
        log_ok "g_multi aus /etc/modules entfernt."
    fi

    # --- 4. Gadget-Skript + Unit installieren ---
    ensure_dir "${PIPORTAL_ETC}" 0755
    install_file "${PIPORTAL_CONFIG_DIR}/piportal.conf" "${PIPORTAL_ETC}/piportal.conf" 0640
    install_file "${PIPORTAL_ASSETS_DIR}/gadget/piportal-gadget.sh" "${PIPORTAL_SBIN}/piportal-gadget.sh" 0755
    install_file "${PIPORTAL_ASSETS_DIR}/systemd/piportal-gadget.service" /etc/systemd/system/piportal-gadget.service 0644
    # Auto-Erkennung NCM/RNDIS (Fallback) – Skript + Unit.
    install_file "${PIPORTAL_ASSETS_DIR}/gadget/piportal-net-detect.sh" "${PIPORTAL_SBIN}/piportal-net-detect.sh" 0755
    install_file "${PIPORTAL_ASSETS_DIR}/systemd/piportal-net-detect.service" /etc/systemd/system/piportal-net-detect.service 0644

    # --- 5. Aktivieren. Neustart des laufenden g_multi erfolgt erst beim Reboot ---
    systemctl daemon-reload
    if ! systemctl is-enabled --quiet piportal-gadget.service 2>/dev/null; then
        systemctl enable piportal-gadget.service >/dev/null 2>&1 && log_ok "piportal-gadget.service aktiviert."
    else
        log_skip "piportal-gadget.service bereits aktiviert."
    fi
    systemctl enable piportal-net-detect.service >/dev/null 2>&1 || true

    if lsmod | grep -q '^g_multi'; then
        # Migrations-Fall: Legacy-g_multi belegt den UDC.
        log_warn "Legacy-g_multi ist noch geladen. Sauberer Umstieg erfolgt beim nächsten REBOOT."
        log_info "Grund: g_multi belegt den UDC; ein Live-Wechsel würde die USB-Verbindung kappen."
    elif [ -z "$(ls /sys/class/udc 2>/dev/null)" ]; then
        # Frisch-Installation: dtoverlay=dwc2 wurde gerade erst gesetzt und greift
        # erst beim nächsten Boot -> es gibt noch keinen UDC zum Binden.
        log_warn "USB-Controller (dwc2) noch nicht aktiv – das dwc2-Overlay greift erst beim nächsten REBOOT."
        log_info "Das Gadget startet nach dem Reboot automatisch (systemd-Unit ist aktiviert)."
    else
        # dwc2 bereits aktiv und kein g_multi -> Live-Start möglich.
        systemctl start piportal-gadget.service && log_ok "Gadget live gestartet."
    fi
}
