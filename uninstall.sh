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
        local d found=0
        for d in "${BACKUP_DIR}"/*/; do
            [ -d "$d" ] || continue
            case "$d" in */latest/) continue ;; esac
            echo "  $d"; found=1
        done
        [ "$found" = "1" ] || log_info "Keine Backups gefunden."
    else
        log_info "Kein Backup-Verzeichnis vorhanden."
    fi
}

stop_services() {
    log_step "PiPortal-Dienste stoppen"
    # Kein 'list-unit-files | grep -q'-Guard: unter 'set -o pipefail' liefert die
    # Pipeline bei einem frühen grep-Treffer via SIGPIPE einen Fehler, wodurch die
    # if-Bedingung fälschlich falsch würde und der Block übersprungen bliebe.
    # Stop/Disable sind ohnehin idempotent – wir versuchen sie direkt.
    local unit
    for unit in piportal-gadget.service piportal-net-detect.service piportal-wifi-roam.service; do
        systemctl stop "$unit"    >/dev/null 2>&1 || true
        systemctl disable "$unit" >/dev/null 2>&1 || true
        # Verbliebene Wants-Symlinks sicher entfernen (Gürtel + Hosenträger).
        rm -f "/etc/systemd/system/sysinit.target.wants/${unit}" \
              "/etc/systemd/system/multi-user.target.wants/${unit}" 2>/dev/null || true
        log_ok "Gestoppt/deaktiviert: $unit"
    done
    systemctl daemon-reload 2>/dev/null || true
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
        # GESCHUETZT: wpa_supplicant.conf (WLAN-Zugang) und cmdline.txt (SAE-Haertung)
        # werden NIE zurueckgespielt – das Geraet muss nach dem Uninstall im WLAN
        # (und damit per SSH) erreichbar bleiben.
        case "$item" in
            */wpa_supplicant.conf|*/cmdline.txt)
                log_skip "Geschuetzt (WLAN/SSH bleibt erhalten): $item"; continue ;;
        esac
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

# Entfernt das Wegweiser-Image (generierter Signpost, KEIN Nutzerdatum). Immer
# sicher: das PiPortal-Laufwerk verschwindet damit nach dem Reboot.
remove_portal_image() {
    local img="${PORTAL_IMAGE:-/srv/piportal/portal.img}"
    if [ -f "$img" ]; then
        rm -f "$img"
        log_ok "Portal-Image entfernt: $img (PiPortal-Laufwerk verschwindet nach dem Reboot)."
    else
        log_skip "Kein Portal-Image vorhanden ($img)."
    fi
}

purge_files() {
    log_step "PiPortal-Dateien entfernen (--purge)"
    local f
    for f in \
        /etc/systemd/system/piportal-gadget.service \
        /etc/systemd/system/piportal-net-detect.service \
        /etc/systemd/system/piportal-wifi-roam.service \
        /usr/local/sbin/piportal-gadget.sh \
        /usr/local/sbin/piportal-net-detect.sh \
        /usr/local/sbin/piportal-wifi-roam.sh \
        /usr/local/bin/piportal \
        /etc/profile.d/piportal-aliases.sh \
        /etc/profile.d/piportal-update.sh \
        /etc/modules-load.d/piportal.conf \
        /etc/dnsmasq.d/piportal-usb.conf \
        /etc/piportal/piportal.conf
    do
        [ -e "$f" ] && { rm -f "$f"; log_ok "Entfernt: $f"; }
    done
    rm -rf /usr/local/lib/piportal 2>/dev/null || true
    rmdir /etc/piportal 2>/dev/null || true
    # Bei --purge auch den Share-Inhalt (mögliche Nutzerdaten!) entfernen.
    if [ -d /srv/piportal ]; then
        log_warn "Entferne /srv/piportal inkl. Share-Inhalt (--purge – Nutzerdaten werden gelöscht!)."
        rm -rf /srv/piportal
        log_ok "Entfernt: /srv/piportal"
    fi
    systemctl daemon-reload
    log_info "PiPortal-Dateien entfernt. WLAN-Zugang und SAE-Härtung bleiben erhalten."
}

# Stellt sicher, dass das Geraet nach dem Uninstall per WLAN/SSH erreichbar bleibt.
ensure_remote_access() {
    log_step "WLAN/SSH-Erreichbarkeit sicherstellen"
    # SAE-Haertung nachziehen (falls doch entfernt) – Funktion aus lib/common.sh.
    harden_wlan_sae
    local wpa="/etc/wpa_supplicant/wpa_supplicant.conf"
    if [ -f "$wpa" ] && grep -q 'network={' "$wpa" 2>/dev/null; then
        log_ok "wpa_supplicant.conf enthält WLAN-Netzwerke – bleibt erhalten."
    else
        log_warn "wpa_supplicant.conf ohne Netzwerk – WLAN-Zugang bitte prüfen!"
    fi
    # Direkt versuchen (kein 'list-unit-files | grep -q'-Guard wegen des
    # pipefail/SIGPIPE-Problems). Fehlt der Dienst, faengt '|| true' das ab.
    local s
    for s in dropbear ssh; do
        systemctl enable --now "$s" >/dev/null 2>&1 && log_ok "SSH-Dienst aktiv: $s" || true
    done
    return 0
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
    remove_portal_image
    [ "$purge" = "1" ] && purge_files

    # Der Uninstall darf das Geraet nicht aus dem WLAN werfen: SAE-Haertung
    # nachziehen, WLAN-Netzwerke pruefen und den SSH-Dienst am Leben halten.
    ensure_remote_access

    log_step "Fertig"
    log_warn "Für vollständige Rückkehr zum Ausgangszustand ggf. neu starten:  sudo reboot"
    log_info "WLAN-Zugang und SAE-Härtung wurden bewusst erhalten – SSH bleibt erreichbar."
}

main "$@"
