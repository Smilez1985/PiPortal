#!/usr/bin/env bash
# =============================================================================
#  PiPortal – Modul 48: Versionsstempel
#
#  Schreibt die Version aus der Repo-Datei VERSION nach /etc/piportal/version,
#  damit `piportal --version` auch ohne das Repo Auskunft geben kann.
#
#  Idempotent nach dem Muster des Projekts:
#    - Datei fehlt        -> anlegen
#    - Version gleich     -> unveraendert lassen
#    - Version verschieden-> aktualisieren und Migrationen ausfuehren
#
#  Migrationen: Ein Versionssprung darf eine bestehende Installation NIE
#  brechen. Passt ein neues Release etwas an, das alte Installationen
#  betrifft, gehoert der Umbau in migrate_from(), nicht in eine
#  Release-Notiz "bitte neu installieren".
# =============================================================================

# ver_lte <a> <b> – wahr, wenn Version a <= b (SemVer, numerisch je Feld).
ver_lte() {
    [ "$1" = "$2" ] && return 0
    local lowest
    lowest="$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)"
    [ "$lowest" = "$1" ]
}

# ver_lt <a> <b> – wahr, wenn Version a < b.
ver_lt() {
    [ "$1" != "$2" ] && ver_lte "$1" "$2"
}

# migrate_from <alte_version> <neue_version>
#
# Wird nur bei einem echten Versionswechsel aufgerufen. Jeder Block prueft
# mit ver_lt, ob die Migration fuer die vorhandene Installation noch noetig
# ist. Bloecke bleiben dauerhaft stehen – wer von 1.0.0 auf 1.5.0 springt,
# durchlaeuft alle zutreffenden.
migrate_from() {
    local from="$1" to="$2"
    log_info "Migration: ${from} → ${to}"

    # Beispiel fuer kuenftige Umbauten (bewusst als Vorlage belassen):
    #
    # if ver_lt "$from" "1.3.0"; then
    #     # 1.3.0 hat den Konfigurationsschluessel X in Y umbenannt.
    #     if [ -f "${PIPORTAL_ETC}/piportal.conf" ] \
    #        && grep -q '^X=' "${PIPORTAL_ETC}/piportal.conf"; then
    #         sed -i 's/^X=/Y=/' "${PIPORTAL_ETC}/piportal.conf"
    #         log_ok "Konfiguration migriert: X → Y"
    #     fi
    # fi

    log_ok "Migrationen abgeschlossen."
}

module_48_version() {
    log_step "Phase 4.8 – Versionsstempel"

    local repo_version installed
    repo_version="$(piportal_repo_version 2>/dev/null || true)"

    if [ -z "$repo_version" ]; then
        log_warn "Datei VERSION fehlt oder ist leer – Versionsstempel uebersprungen."
        return 0
    fi

    ensure_dir "${PIPORTAL_ETC}" 0755

    # if not exist -> setzen
    if ! installed="$(piportal_installed_version 2>/dev/null)" || [ -z "$installed" ]; then
        printf '%s\n' "$repo_version" | write_file_if_changed \
            "${PIPORTAL_INSTALLED_VERSION_FILE}" 0644
        log_ok "Version gesetzt: ${repo_version}"
        return 0
    fi

    # if exist -> pruefen
    if [ "$installed" = "$repo_version" ]; then
        log_skip "Version unveraendert: ${installed}"
        return 0
    fi

    # Abweichung -> aktualisieren
    if ver_lt "$repo_version" "$installed"; then
        # Downgrade: im nicht-interaktiven Lauf NICHT automatisch zurueckstufen.
        # (confirm() liefert bei --non-interactive immer "ja" – hier waere das
        # die falsche Voreinstellung.)
        log_warn "Installierte Version (${installed}) ist neuer als diese Quelle (${repo_version})."
        if [ "${PIPORTAL_NONINTERACTIVE:-0}" = "1" ]; then
            log_skip "Nicht-interaktiv: Versionsstempel unveraendert gelassen."
            return 0
        fi
        if ! confirm "Trotzdem auf ${repo_version} zurueckstufen?"; then
            log_skip "Versionsstempel unveraendert gelassen."
            return 0
        fi
    else
        migrate_from "$installed" "$repo_version"
    fi

    printf '%s\n' "$repo_version" | write_file_if_changed \
        "${PIPORTAL_INSTALLED_VERSION_FILE}" 0644
    log_ok "Version aktualisiert: ${installed} → ${repo_version}"
}
