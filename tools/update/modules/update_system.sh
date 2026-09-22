#!/usr/bin/env bash
# =============================================================================
#  PiPortal Update-Modul: System (APT + DietPi)
#  apt update -> dietpi-update -> apt upgrade (OHNE --ignore-hold) -> autoremove.
#  Erkennt am Ende, ob ein Reboot noetig ist (Kernel-/Firmware-Wechsel), und
#  vermerkt das ueber das Reboot-Flag. Beendet nie selbst – meldet nur.
# =============================================================================
set -uo pipefail
LOG_TAG="SYSTEM"
# shellcheck source=lib_common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib_common.sh"

rc_total=0

# Kernel-Stand VOR dem Upgrade merken (fuer die Reboot-Erkennung).
kernel_before="$(uname -r)"

log "Aktualisiere Paketlisten"
if ! run "apt update" sudo apt-get update -y; then
    log_err "apt update fehlgeschlagen -- alles Folgende arbeitet auf einer alten Liste"
    rc_total=$((rc_total + 1))
fi

# dietpi-update ist als root oft nicht im PATH -> auch den festen Pfad pruefen.
DIETPI_UPDATE="$(command -v dietpi-update 2>/dev/null || true)"
[ -z "$DIETPI_UPDATE" ] && [ -x /boot/dietpi/dietpi-update ] && DIETPI_UPDATE=/boot/dietpi/dietpi-update
if [ -n "$DIETPI_UPDATE" ]; then
    log "DietPi-Update"
    if ! run "dietpi-update" sudo "$DIETPI_UPDATE" 1; then
        log_warn "dietpi-update meldete einen Fehler -- weiter mit APT"
        rc_total=$((rc_total + 1))
    fi
else
    log_skip "dietpi-update nicht vorhanden"
fi

log "APT-Upgrades (gehaltene Pakete bleiben unangetastet)"
if ! run "apt upgrade" sudo apt-get -y upgrade; then
    log_err "apt upgrade fehlgeschlagen"
    rc_total=$((rc_total + 1))
fi

log "Aufraeumen"
if ! run "apt autoremove" sudo apt-get -y autoremove; then
    log_warn "apt autoremove fehlgeschlagen -- kosmetisch, kein Abbruchgrund"
fi

# --- Reboot noetig? ---
# 1) Debian/DietPi-Marker.
if [ -f /var/run/reboot-required ] || [ -f /run/reboot-required ]; then
    mark_reboot_needed "System-Paket verlangt Reboot (/run/reboot-required)"
fi
# 2) Neuerer Kernel installiert als der laufende?
kernel_newest="$(ls -1 /lib/modules 2>/dev/null | sort -V | tail -n1)"
if [ -n "$kernel_newest" ] && [ "$kernel_newest" != "$kernel_before" ] && [ "$kernel_newest" != "$(uname -r)" ]; then
    mark_reboot_needed "neuer Kernel installiert (${kernel_newest}, laeuft ${kernel_before})"
fi

held="$(apt-mark showhold 2>/dev/null | tr '\n' ' ')"
[ -n "$held" ] && log "Gehalten (eigene Module zustaendig): ${held}"

[ "$rc_total" -eq 0 ] && log_ok "System-Updates abgeschlossen" \
                      || log_err "System-Updates mit ${rc_total} Fehler(n)"
exit "$rc_total"
