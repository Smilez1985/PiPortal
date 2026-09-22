#!/usr/bin/env bash
# =============================================================================
#  PiPortal Update-Routine – Orchestrator
#  Ruft die Update-Module der Reihe nach auf, protokolliert jedes Ergebnis und
#  laeuft WEITER, wenn eines scheitert. Der Exit-Code ist die Anzahl der
#  gescheiterten Module (0 = alles sauber), damit Cron/Boot den Unterschied merkt.
#
#  Aufruf:
#    sudo ./update_orchestrator.sh                scharf
#    DRY_RUN=1 ./update_orchestrator.sh           Trockenlauf (aendert nichts)
#    MODULES="system" ./update_orchestrator.sh    nur bestimmte Module
#
#  Reboot-Politik (UPDATE_REBOOT_MODE aus /etc/piportal/piportal.conf oder Env):
#    ask     (Default) im Terminal fragen; ohne Terminal -> Warnung, kein Auto-Reboot
#    auto    am Ende automatisch  'sync && reboot now'
#    manual  nie automatisch – nur Warnung hinterlegen
# =============================================================================
set -uo pipefail
# Deterministische, sprachunabhaengige Werkzeug-Ausgaben (Parsing sicher auf jedem Sprach-OS).
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="${MODULE_DIR:-${SCRIPT_DIR}/modules}"
export LOG_FILE="${LOG_FILE:-/var/log/piportal-update.log}"
export BACKUP_DIR="${BACKUP_DIR:-/var/backups/piportal-update}"
# DRY_RUN strikt auf 0/1 normalisieren (sonst zeigt ${DRY_RUN:+…} auch bei "0" an).
case "${DRY_RUN:-0}" in 1|true|yes|on) DRY_RUN=1 ;; *) DRY_RUN=0 ;; esac
export DRY_RUN
export REBOOT_FLAG="${REBOOT_FLAG:-/run/piportal-reboot-required}"

LOG_TAG="ORCHESTRATOR"
# shellcheck source=modules/lib_common.sh
source "${MODULE_DIR}/lib_common.sh"

# PiPortal-Config einlesen (nur fuer UPDATE_REBOOT_MODE u. a.), falls vorhanden.
PIPORTAL_CONF="${PIPORTAL_CONF:-/etc/piportal/piportal.conf}"
# Eine Env-Vorgabe (z. B. vom Login-Hook: auto/manual) hat Vorrang vor der Config.
_ENV_REBOOT_MODE="${UPDATE_REBOOT_MODE:-}"
# shellcheck disable=SC1090
# Nur einlesen, wenn lesbar (0640 root) – beim Trockenlauf als Nutzer sonst nur Rauschen.
[ -r "$PIPORTAL_CONF" ] && . "$PIPORTAL_CONF"
UPDATE_REBOOT_MODE="${_ENV_REBOOT_MODE:-${UPDATE_REBOOT_MODE:-ask}}"

# Reihenfolge ist Absicht: erst System (frische Paketliste), dann WLAN-Haertung
# (vor einem evtl. Reboot), dann PiPortal selbst, dann optionale Software.
MODULES="${MODULES:-system harden_wlan piportal claude}"

MOTD_DROPIN="/run/motd.d/50-piportal-update"
motd_write() { [ -d /run/motd.d ] && { printf '%s\n' "$*" | sudo tee "$MOTD_DROPIN" >/dev/null 2>&1 || true; }; }
motd_clear() { sudo rm -f "$MOTD_DROPIN" 2>/dev/null || true; }

# --- Start ---
clear_reboot_flag
motd_write "PiPortal-Update laeuft – bitte warten, bis es abgeschlossen ist."
if [ "$DRY_RUN" = "1" ]; then
    log "=== PiPortal-Updateroutine gestartet (TROCKENLAUF) ==="
    log "TROCKENLAUF -- es wird nichts veraendert"
else
    log "=== PiPortal-Updateroutine gestartet ==="
fi
log "Module: ${MODULES}  | Reboot-Modus: ${UPDATE_REBOOT_MODE}"

failed=0
declare -a results=()
for mod in $MODULES; do
    script="${MODULE_DIR}/update_${mod}.sh"
    [ "$mod" = "harden_wlan" ] && script="${MODULE_DIR}/harden_wlan.sh"
    if [ ! -f "$script" ]; then
        log_warn "Modul ${mod}: Datei fehlt (${script}) -- uebersprungen"
        results+=("${mod}: FEHLT"); failed=$((failed + 1)); continue
    fi
    log "--- Modul ${mod} ---"
    # Module regeln Privilegien selbst (sudo intern). Env wird vererbt (exportiert).
    if bash "$script"; then
        log_ok "Modul ${mod} abgeschlossen"; results+=("${mod}: OK")
    else
        rc=$?
        log_err "Modul ${mod} meldet Fehler (rc=${rc}) -- Kette laeuft weiter"
        results+=("${mod}: FEHLER rc=${rc}"); failed=$((failed + 1))
    fi
done

log "=== Zusammenfassung ==="
for r in "${results[@]}"; do log "    ${r}"; done
[ "$failed" -eq 0 ] && log_ok "Alle Module sauber durchgelaufen" \
                    || log_err "${failed} Modul(e) mit Fehler -- siehe oben"

# Lauf vermerken -> startet die Pause bis zur naechsten Login-Abfrage.
record_run

# --- Reboot-Behandlung ---
if reboot_needed; then
    reasons="$(tr '\n' ';' < "$REBOOT_FLAG" 2>/dev/null | sed 's/;$//')"
    log_warn "Ein REBOOT ist noetig (${reasons})."
    motd_write "PiPortal: Update eingespielt – ein REBOOT ist noetig (${reasons})."
    if [ "$DRY_RUN" = "1" ]; then
        log "TROCKEN wuerde Reboot-Modus '${UPDATE_REBOOT_MODE}' anwenden."
    else
        case "$UPDATE_REBOOT_MODE" in
            auto)
                log_warn "Reboot-Modus auto -- starte in 5 s neu (sync && reboot)."
                sync; sleep 5; sudo systemctl reboot ;;
            manual)
                log_warn "Reboot-Modus manual -- bitte selbst neu starten:  sudo reboot" ;;
            ask|*)
                if [ -t 0 ] && [ -t 1 ]; then
                    echo
                    read -r -p "Reboot jetzt automatisch durchfuehren? [j/N] " ans
                    case "$ans" in
                        [jJyY]|[jJ][aA]) log_warn "Auto-Reboot gewaehlt."; sync; sleep 2; sudo systemctl reboot ;;
                        *) log_warn "Manuell gewaehlt -- bitte spaeter:  sudo reboot" ;;
                    esac
                else
                    log_warn "Kein Terminal (Boot/Cron) -- kein Auto-Reboot. Bitte manuell:  sudo reboot"
                fi ;;
        esac
    fi
else
    motd_clear
fi

exit "$failed"
