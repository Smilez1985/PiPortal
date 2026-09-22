#!/usr/bin/env bash
# =============================================================================
#  PiPortal Update-Routine – lib_common.sh
#  Gemeinsame Bausteine: Logging, Backup, Rollback, Dienstprüfung, apt-Gates,
#  Reboot-Flag. Wird von jedem Modul per `source` eingebunden. Nicht direkt
#  ausführen.
#
#  Herkunft: abgeleitet aus der bewährten PiHole-Updateroutine desselben Autors,
#  auf PiPortal zugeschnitten. Zwei Grundsätze bleiben:
#    1. Ein Backup, das nicht angelegt werden konnte, ist kein Backup.
#    2. Ein Modul meldet nur – der Orchestrator entscheidet, wie es weitergeht.
# =============================================================================
set -uo pipefail

LOG_FILE="${LOG_FILE:-/var/log/piportal-update.log}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/piportal-update}"
DRY_RUN="${DRY_RUN:-0}"
# Flag-Datei: ein Modul, das einen Reboot nötig macht, hinterlässt sie hier.
REBOOT_FLAG="${REBOOT_FLAG:-/run/piportal-reboot-required}"
# Zustand: Zeitstempel des letzten Laufs (steuert die Pause zwischen Läufen).
STATE_DIR="${STATE_DIR:-/var/lib/piportal}"
STATE_LAST_RUN="${STATE_LAST_RUN:-${STATE_DIR}/update-last-run}"
LOG_TAG="${LOG_TAG:-ALLGEMEIN}"

# ------------------------------------------------------------------ Logging --
# Reines ASCII – Symbole kamen auf dem Gerät verstümmelt an.
log() {
    local line
    line="$(date '+%Y-%m-%d %H:%M:%S') - [${LOG_TAG}] $*"
    echo "$line"
    echo "$line" | sudo tee -a "$LOG_FILE" >/dev/null 2>&1 || true
}
log_ok()   { log "OK      $*"; }
log_warn() { log "WARNUNG $*"; }
log_err()  { log "FEHLER  $*"; }
log_skip() { log "SKIP    $*"; }

# ------------------------------------------------------------ run <desc> ... --
# Führt aus, protokolliert, respektiert DRY_RUN. Gibt den Exit-Code zurück –
# beendet nie selbst.
run() {
    local desc="$1"; shift
    if [ "$DRY_RUN" = "1" ]; then
        log "TROCKEN wuerde ausfuehren: $desc  ->  $*"
        return 0
    fi
    log "        $desc"
    "$@"
}

# --------------------------------------------------------------- Reboot-Flag --
mark_reboot_needed() {
    local reason="${1:-unbekannt}"
    if [ "$DRY_RUN" = "1" ]; then
        log "TROCKEN wuerde Reboot-Flag setzen: $reason"
        return 0
    fi
    echo "$reason" | sudo tee -a "$REBOOT_FLAG" >/dev/null 2>&1 || true
    log_warn "Reboot noetig vermerkt: $reason"
}
reboot_needed() { [ -s "$REBOOT_FLAG" ]; }
clear_reboot_flag() { sudo rm -f "$REBOOT_FLAG" 2>/dev/null || true; }

# --------------------------------------------------------- Lauf-Zeitstempel --
# Nach jedem Lauf gesetzt; die Login-Abfrage nutzt ihn fuer die Pause.
record_run() {
    [ "$DRY_RUN" = "1" ] && { log "TROCKEN wuerde Lauf-Zeitstempel setzen"; return 0; }
    sudo mkdir -p "$STATE_DIR" 2>/dev/null || true
    date +%s | sudo tee "$STATE_LAST_RUN" >/dev/null 2>&1 || true
}

# ---------------------------------------------------------- Backup-Verzeichnis --
ensure_backup_dir() {
    [ -d "$BACKUP_DIR" ] && return 0
    if [ "$DRY_RUN" = "1" ]; then log "TROCKEN wuerde anlegen: $BACKUP_DIR"; return 0; fi
    if sudo mkdir -p "$BACKUP_DIR" 2>/dev/null; then
        log_ok "Backup-Verzeichnis angelegt: $BACKUP_DIR"; return 0
    fi
    log_err "Backup-Verzeichnis $BACKUP_DIR nicht anlegbar"; return 1
}

# ------------------------------------------------ backup_file <src> <name> -----
# Gibt den Backup-Pfad auf stdout aus; Rueckgabe 1 = kein brauchbares Backup.
# Der Aufrufer MUSS das auswerten: ohne Backup kein Eingriff.
backup_file() {
    local src="$1" name="$2" dest
    dest="${BACKUP_DIR}/${name}.$(date '+%Y%m%d-%H%M%S')"
    ensure_backup_dir || return 1
    if [ ! -e "$src" ]; then log_warn "Quelle fuer Backup fehlt: $src"; return 1; fi
    if [ "$DRY_RUN" = "1" ]; then log "TROCKEN wuerde sichern: $src -> $dest"; echo "$dest"; return 0; fi
    if ! sudo cp -a "$src" "$dest" 2>/dev/null; then log_err "Backup fehlgeschlagen: $src -> $dest"; return 1; fi
    if ! sudo test -s "$dest"; then log_err "Backup leer/fehlt nach dem Kopieren: $dest"; return 1; fi
    log_ok "Backup angelegt: $dest"
    sudo bash -c "ls -1t '${BACKUP_DIR}/${name}.'* 2>/dev/null | tail -n +6 | xargs -r rm -f" 2>/dev/null || true
    echo "$dest"
}

# ------------------------------------- restore_file <bak> <ziel> [dienst] ------
restore_file() {
    local bak="$1" dest="$2" svc="${3:-}"
    if [ -z "$bak" ] || ! sudo test -s "$bak"; then
        log_err "ROLLBACK NICHT MOEGLICH -- kein brauchbares Backup ($bak)"; return 1
    fi
    log_warn "Rollback: $bak -> $dest"
    sudo cp -a "$bak" "$dest" || { log_err "Rollback-Kopie fehlgeschlagen"; return 1; }
    if [ -n "$svc" ]; then
        sudo systemctl restart "$svc" 2>/dev/null || true
        if service_healthy "$svc"; then log_ok "Rollback erfolgreich, $svc laeuft wieder"; return 0; fi
        log_err "Rollback eingespielt, aber $svc laeuft NICHT -- Handarbeit noetig"; return 1
    fi
    log_ok "Rollback eingespielt"
}

# ------------------------------------- service_healthy <dienst> [sekunden] -----
# "is-active" direkt nach dem Start ist eine Momentaufnahme. Also warten + mehrfach nachsehen.
service_healthy() {
    local svc="$1" wait_s="${2:-10}" i
    [ "$DRY_RUN" = "1" ] && { log "TROCKEN wuerde pruefen: $svc"; return 0; }
    for ((i = 0; i < wait_s; i++)); do
        sleep 1
        systemctl is-active --quiet "$svc" || return 1
    done
    return 0
}

# ------------------------------------------------- apt-Gates (hold-sicher) -----
apt_upgrade_available() {
    local pkg="$1" inst cand
    inst="$(apt-cache policy "$pkg" 2>/dev/null | awk '/Installed:/ {print $2}')"
    cand="$(apt-cache policy "$pkg" 2>/dev/null | awk '/Candidate:/ {print $2}')"
    [ -z "$inst" ] || [ "$inst" = "(none)" ] && return 1
    [ -z "$cand" ] || [ "$cand" = "(none)" ] && return 1
    [ "$inst" != "$cand" ]
}
apt_candidate_version() { apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ {print $2}'; }
