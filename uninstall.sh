#!/usr/bin/env bash
# =============================================================================
#  PiPortal – Uninstaller / Rollback
#  Stoppt die PiPortal-Dienste und spielt das jüngste automatische Backup
#  zurück (oder ein per --from angegebenes).
#
#  Aufruf:
#     sudo ./uninstall.sh                  jüngstes Backup zurückspielen
#     sudo ./uninstall.sh --from /var/backups/piportal/20260803_181500
#     sudo ./uninstall.sh --purge          zusätzlich PiPortal-Dateien entfernen
#     sudo ./uninstall.sh --list           verfügbare Backups anzeigen
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"

BACKUP_DIR="/var/backups/piportal"
[ -f "${PIPORTAL_CONFIG_DIR}/piportal.conf" ] && . "${PIPORTAL_CONFIG_DIR}/piportal.conf"

usage() {
    cat <<'EOF'
PiPortal Uninstaller

  sudo ./uninstall.sh [OPTIONEN]

  --from <dir>   Bestimmtes Backup-Verzeichnis zurückspielen.
  --purge        PiPortal-eigene Dateien/Dienste zusätzlich entfernen.
  --list         Verfügbare Backups auflisten.
  -h, --help     Diese Hilfe.
EOF
}

list_backups() {
    log_step "Verfügbare Backups in ${BACKUP_DIR}"
    if [ -d "$BACKUP_DIR" ]; then
        ls -1dt "${BACKUP_DIR}"/*/ 2>/dev/null | grep -v '/latest/$' || log_info "Keine Backups gefunden."
    else
        log_info "Kein Backup-Verzeichnis vorhanden."
    fi
}

stop_services() {
    log_step "PiPortal-Dienste stoppen"
    local unit
    for unit in piportal-gadget.service piportal-wifi-roam.service; do
        if systemctl list-unit-files 2>/dev/null | grep -q "^${unit}"; then
            systemctl disable --now "$unit" >/dev/null 2>&1 || true
            log_ok "Gestoppt/deaktiviert: $unit"
        fi
    done
}

restore_backup() {
    local src="$1"
    [ -d "$src" ] || die "Backup-Verzeichnis nicht gefunden: $src"
    local manifest="${src}/MANIFEST.txt"
    [ -f "$manifest" ] || die "Kein MANIFEST.txt in $src – kein gültiges PiPortal-Backup."

    log_step "Backup zurückspielen: $src"
    local item
    while IFS= read -r item; do
        case "$item" in ''|'#'*|'PiPortal-Backup'*|'Host:'*|'---') continue ;; esac
        local stored="${src}${item}"
        if [ -e "$stored" ]; then
            ensure_dir "$(dirname "$item")" >/dev/null
            cp -a "$stored" "$item"
            log_ok "Wiederhergestellt: $item"
        else
            log_skip "Im Backup nicht enthalten: $item"
        fi
    done < "$manifest"
    log_ok "Rücksicherung abgeschlossen."
}

purge_files() {
    log_step "PiPortal-Dateien entfernen (--purge)"
    local f
    for f in \
        /etc/systemd/system/piportal-gadget.service \
        /etc/systemd/system/piportal-wifi-roam.service \
        /usr/local/sbin/piportal-gadget.sh \
        /usr/local/sbin/piportal-wifi-roam.sh \
        /etc/modules-load.d/piportal.conf \
        /etc/dnsmasq.d/piportal-usb.conf \
        /etc/piportal/piportal.conf
    do
        [ -e "$f" ] && { rm -f "$f"; log_ok "Entfernt: $f"; }
    done
    rmdir /etc/piportal 2>/dev/null || true
    systemctl daemon-reload
    log_info "Portal-Image und Share unter /srv/piportal wurden NICHT gelöscht (Datenschutz)."
}

main() {
    local from="" purge=0
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --from)  shift; from="$1" ;;
            --purge) purge=1 ;;
            --list)  list_backups; exit 0 ;;
            -h|--help) usage; exit 0 ;;
            *) die "Unbekannte Option: $1" ;;
        esac
        shift || true
    done

    require_root

    [ -z "$from" ] && from="$(readlink -f "${BACKUP_DIR}/latest" 2>/dev/null || true)"
    [ -z "$from" ] && die "Kein Backup gefunden. Verfügbare:  sudo ./uninstall.sh --list"

    if ! confirm "Backup '${from}' zurückspielen und PiPortal-Dienste stoppen?"; then
        log_info "Abgebrochen."
        exit 0
    fi

    stop_services
    restore_backup "$from"
    [ "$purge" = "1" ] && purge_files

    log_step "Fertig"
    log_warn "Für vollständige Rückkehr zum Ausgangszustand ggf. neu starten:  sudo reboot"
}

main "$@"
