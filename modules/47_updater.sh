#!/usr/bin/env bash
# =============================================================================
#  PiPortal – Modul 47: Update-Routine
#  Installiert die modulare Wartungsroutine (tools/update) nach
#  /usr/local/lib/piportal/update und den Login-Hook, der beim interaktiven
#  Login nach einem faelligen Wartungslauf fragt (kein Auto-Update beim Boot).
# =============================================================================

module_47_updater() {
    log_step "Phase 4b – Update-Routine + Login-Abfrage"

    local src="${PIPORTAL_ROOT}/tools/update"
    local dst="/usr/local/lib/piportal/update"

    if [ ! -f "${src}/update_orchestrator.sh" ]; then
        log_warn "tools/update nicht gefunden (${src}) – Update-Routine übersprungen."
        return 0
    fi

    ensure_dir "${dst}/modules" 0755
    install_file "${src}/update_orchestrator.sh" "${dst}/update_orchestrator.sh" 0755
    install_file "${src}/README.md"              "${dst}/README.md"              0644
    local m
    for m in lib_common update_system harden_wlan update_piportal update_claude; do
        install_file "${src}/modules/${m}.sh" "${dst}/modules/${m}.sh" 0755
    done

    # Login-Abfrage-Hook (fragt beim Login, ob ein faelliger Lauf jetzt soll).
    install_file "${PIPORTAL_ASSETS_DIR}/profile.d/piportal-update.sh" \
                 /etc/profile.d/piportal-update.sh 0644

    # Zustandsverzeichnis (Zeitstempel des letzten Laufs).
    ensure_dir /var/lib/piportal 0755

    log_ok "Update-Routine installiert: ${dst}"
    log_info "Wartung läuft NICHT automatisch beim Boot – es wird beim Login gefragt"
    log_info "(fällig alle ${UPDATE_INTERVAL_DAYS:-14} Tage). Manuell:  sudo ${dst}/update_orchestrator.sh"
}
