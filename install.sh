#!/usr/bin/env bash
# =============================================================================
#  PiPortal – One-Click-Installer
#  Idempotent, modular. Führt die Installationsphasen 00–50 aus.
#
#  Aufruf:
#     sudo ./install.sh                     interaktives Menü
#     sudo ./install.sh --all               alle Phasen ohne Menü
#     sudo ./install.sh --only 10_network_usb [--only 40_portal_smb] ...
#     sudo ./install.sh --all --non-interactive   vollautomatisch (CI/Wiederholung)
#     sudo ./install.sh --no-color
#     sudo ./install.sh -h | --help
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"

# Reihenfolge der Phasen (Dateiname ohne .sh, Funktionsname = module_<name>).
PHASES=(00_backup 01_hostname 05_swap 10_network_usb 15_boot_tuning 20_wifi_roaming 30_gadget 40_portal_smb 45_cli 50_extras)

usage() {
    cat <<'EOF'
PiPortal Installer

  sudo ./install.sh [OPTIONEN]

Optionen:
  (ohne)              Interaktives Menü.
  --all               Alle Phasen der Reihe nach ausführen.
  --only <phase>      Nur diese Phase (mehrfach möglich). Namen siehe unten.
  --non-interactive   Keine Rückfragen (nutzt Defaults / Config-Werte).
  --no-color          Ohne Farbausgabe.
  -h, --help          Diese Hilfe.

Phasen:
  00_backup           Backup der betroffenen Systemdateien
  01_hostname         Hostname setzen (Standard: PiPortal)
  05_swap             SD-Swapfile (nach Kartengröße) + zram + swappiness
  10_network_usb      usb0 statische IP + dnsmasq (ohne Gateway-Hijack)
  15_boot_tuning      Wait-for-network abschalten (schneller Boot, AP-Modus)
  20_wifi_roaming     WLAN-Profile + Roaming-Service
  30_gadget           configfs-Composite-Gadget (RNDIS + Mass Storage)
  40_portal_smb       Samba gehärtet + Wegweiser-Image
  45_cli              piportal-CLI (--status/--wifi-switch/--update) + Aliase
  50_extras           SSH-Helper, optional Claude Code CLI
EOF
}

run_phase() {
    local name="$1"
    local file="${PIPORTAL_MODULES_DIR}/${name}.sh"
    [ -f "$file" ] || die "Modul fehlt: $file"
    # shellcheck disable=SC1090
    . "$file"
    "module_${name}"
}

run_all() {
    local p
    for p in "${PHASES[@]}"; do
        run_phase "$p"
    done
    final_summary
}

final_summary() {
    log_step "Fertig"
    log_ok "PiPortal-Installation abgeschlossen."
    if lsmod | grep -q '^g_multi'; then
        log_warn "Ein REBOOT ist nötig, um von Legacy-g_multi auf das configfs-Gadget umzustellen:"
        printf '        sudo reboot\n'
    elif [ -z "$(ls /sys/class/udc 2>/dev/null)" ]; then
        log_warn "Ein REBOOT ist nötig, damit das dwc2-Overlay greift und das USB-Gadget aktiv wird:"
        printf '        sudo reboot\n'
    fi
    log_info "Verbindung vom Windows-PC:  \\\\${USB_LAN_IP}\\${SMB_SHARE_NAME}   bzw.  ssh ${SMB_USER}@${USB_LAN_IP}"
    log_info "Rückgängig machen:  sudo ./uninstall.sh"
}

interactive_menu() {
    log_step "PiPortal Installer – Menü"
    cat <<EOF
  [1] Vollständige Installation (alle Phasen, empfohlen)
  [2] Einzelne Phase wählen
  [3] Ist-Status anzeigen
  [q] Beenden
EOF
    local choice; read -r -p "Auswahl: " choice
    case "$choice" in
        1) run_all ;;
        2) phase_submenu ;;
        3) show_status ;;
        q|Q) exit 0 ;;
        *) log_warn "Ungültige Auswahl."; interactive_menu ;;
    esac
}

phase_submenu() {
    local i=1 p
    echo
    for p in "${PHASES[@]}"; do printf '  [%d] %s\n' "$i" "$p"; i=$((i+1)); done
    local sel; read -r -p "Phase-Nummer: " sel
    if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -le "${#PHASES[@]}" ]; then
        run_phase "${PHASES[$((sel-1))]}"
        final_summary
    else
        log_warn "Ungültige Nummer."
    fi
}

show_status() {
    log_step "PiPortal – Ist-Status"
    printf '  Gadget-Modus:   '; lsmod | grep -q '^g_multi' && echo "Legacy g_multi (Reboot für Umstieg nötig)" || echo "configfs / libcomposite"
    printf '  Gadget-Service: '; systemctl is-active piportal-gadget.service 2>/dev/null || echo "inaktiv"
    printf '  Roaming:        '; systemctl is-active piportal-wifi-roam.service 2>/dev/null || echo "inaktiv"
    printf '  dnsmasq:        '; systemctl is-active dnsmasq 2>/dev/null || echo "inaktiv"
    printf '  Samba (smbd):   '; systemctl is-active smbd 2>/dev/null || echo "nicht installiert"
    printf '  usb0:           '; ip -4 addr show usb0 2>/dev/null | sed -n 's/.*inet \([0-9.]*\).*/\1/p' | head -1 || echo "-"
    printf '  wlan0:          '; ip -4 addr show wlan0 2>/dev/null | sed -n 's/.*inet \([0-9.]*\).*/\1/p' | head -1 || echo "-"
    echo   '  Swap:'; swapon --show 2>/dev/null | sed 's/^/    /' || echo "    (kein Swap)"
}

# ------------------------------------------------------------------- main -----
main() {
    local mode="menu"; local only=()
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --all)             mode="all" ;;
            --only)            mode="only"; shift; only+=("$1") ;;
            --non-interactive) PIPORTAL_NONINTERACTIVE=1 ;;
            --no-color)        PIPORTAL_NO_COLOR=1 ;;
            -h|--help)         usage; exit 0 ;;
            *) die "Unbekannte Option: $1 (siehe --help)" ;;
        esac
        shift || true
    done

    require_root
    assert_target
    load_config
    deploy_runtime_config

    case "$mode" in
        all)  run_all ;;
        only)
            local p
            for p in "${only[@]}"; do run_phase "$p"; done
            final_summary ;;
        menu) interactive_menu ;;
    esac
}

main "$@"
