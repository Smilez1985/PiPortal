#!/usr/bin/env bash
# =============================================================================
#  PiPortal – Modul 45: CLI-Werkzeug
#  Installiert den Befehl `piportal` (--status / --wifi-switch / --update)
#  sowie die Komfort-Aliase (cls, clean, pp, ppstatus).
# =============================================================================

module_45_cli() {
    log_step "Phase 4.5 – PiPortal-CLI"

    # Haupt-CLI nach /usr/local/bin (liegt im PATH aller Benutzer).
    install_file "${PIPORTAL_ASSETS_DIR}/cli/piportal" /usr/local/bin/piportal 0755

    # Komfort-Aliase systemweit für interaktive Login-Shells.
    install_file "${PIPORTAL_ASSETS_DIR}/cli/piportal-aliases.sh" /etc/profile.d/piportal-aliases.sh 0644

    log_ok "CLI installiert: 'piportal --status | --wifi-switch | --update'"
    log_info "Aliase (cls, clean, pp, ppstatus) greifen ab der nächsten Anmeldung."
}
