#!/usr/bin/env bash
# =============================================================================
#  PiPortal – lib/common.sh
#  Gemeinsame Funktionen: Logging, Idempotenz-Helfer, Backup, Config-Loader.
#  Wird von install.sh, uninstall.sh und allen Modulen gesourct.
#  Nicht direkt ausführen.
# =============================================================================

# Doppel-Sourcing verhindern.
[ -n "${PIPORTAL_COMMON_LOADED:-}" ] && return 0
PIPORTAL_COMMON_LOADED=1

# ----------------------------------------------------------------- Pfade -----
# Repo-Wurzel = Elternverzeichnis dieser Datei.
PIPORTAL_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPORTAL_ROOT="$(cd "${PIPORTAL_LIB_DIR}/.." && pwd)"
PIPORTAL_CONFIG_DIR="${PIPORTAL_ROOT}/config"
PIPORTAL_MODULES_DIR="${PIPORTAL_ROOT}/modules"
PIPORTAL_ASSETS_DIR="${PIPORTAL_ROOT}/assets"

# Zielpfade auf dem installierten System.
PIPORTAL_ETC="/etc/piportal"
PIPORTAL_SBIN="/usr/local/sbin"

# ----------------------------------------------------------------- Farben ----
if [ -t 1 ] && [ "${PIPORTAL_NO_COLOR:-0}" != "1" ]; then
    C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'
    C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[34m'; C_CYAN=$'\033[36m'
else
    C_RESET=""; C_BOLD=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_CYAN=""
fi

# ----------------------------------------------------------------- Logging ---
log_step()  { printf '\n%s==>%s %s%s%s\n' "$C_BOLD$C_BLUE" "$C_RESET" "$C_BOLD" "$*" "$C_RESET"; }
log_info()  { printf '%s  •%s %s\n' "$C_CYAN" "$C_RESET" "$*"; }
log_ok()    { printf '%s  ✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
log_skip()  { printf '%s  ↷%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
log_warn()  { printf '%s  !%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
log_err()   { printf '%s  ✗%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
die()       { log_err "$*"; exit 1; }

# ----------------------------------------------------------------- Guards ----
require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        die "Bitte mit sudo/root ausführen:  sudo $0"
    fi
}

# Prüft, ob wir auf einem plausiblen DietPi/Raspberry-Ziel laufen.
assert_target() {
    [ -d /sys/kernel/config ] || log_warn "configfs (/sys/kernel/config) nicht gefunden – Gadget-Modul wird scheitern."
    [ -f /boot/firmware/config.txt ] || log_warn "/boot/firmware/config.txt nicht gefunden – abweichender Boot-Pfad?"
}

# ------------------------------------------------------------- Config-Loader -
# Lädt config/piportal.conf; fällt NICHT automatisch auf .example zurück,
# damit niemand versehentlich mit Platzhaltern installiert.
load_config() {
    local cfg="${PIPORTAL_CONFIG_DIR}/piportal.conf"
    if [ ! -f "$cfg" ]; then
        log_err "Konfiguration fehlt: ${cfg}"
        log_info "Anlegen mit:  cp config/piportal.conf.example config/piportal.conf"
        die "Abbruch."
    fi
    # shellcheck disable=SC1090
    . "$cfg"
    log_ok "Konfiguration geladen: ${cfg}"
}

# ------------------------------------------------------- Idempotenz-Helfer ---

# ensure_pkg <paket> [paket...] – installiert nur fehlende Pakete.
ensure_pkg() {
    local missing=()
    local p
    for p in "$@"; do
        if ! dpkg -s "$p" >/dev/null 2>&1; then
            missing+=("$p")
        fi
    done
    if [ "${#missing[@]}" -eq 0 ]; then
        log_skip "Pakete bereits vorhanden: $*"
        return 0
    fi
    log_info "Installiere: ${missing[*]}"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq || die "apt-get update fehlgeschlagen"
    apt-get install -y --no-install-recommends "${missing[@]}" || die "Installation fehlgeschlagen: ${missing[*]}"
    log_ok "Installiert: ${missing[*]}"
}

# ensure_dir <pfad> [modus] [besitzer] – legt Verzeichnis idempotent an.
ensure_dir() {
    local dir="$1" mode="${2:-}" owner="${3:-}"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        log_ok "Verzeichnis angelegt: $dir"
    else
        log_skip "Verzeichnis vorhanden: $dir"
    fi
    [ -n "$mode" ]  && chmod "$mode" "$dir"
    [ -n "$owner" ] && chown "$owner" "$dir"
    return 0
}

# ensure_line <datei> <zeile> – fügt eine exakte Zeile hinzu, falls sie fehlt.
ensure_line() {
    local file="$1" line="$2"
    touch "$file"
    if grep -qxF -- "$line" "$file"; then
        log_skip "Zeile bereits in ${file##*/}: $line"
    else
        printf '%s\n' "$line" >> "$file"
        log_ok "Zeile ergänzt in ${file##*/}: $line"
    fi
}

# install_file <quelle> <ziel> [modus] – kopiert nur bei Unterschied (idempotent).
install_file() {
    local src="$1" dst="$2" mode="${3:-0644}"
    [ -f "$src" ] || die "Quelldatei fehlt: $src"
    ensure_dir "$(dirname "$dst")"
    if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
        log_skip "Unverändert: $dst"
    else
        install -m "$mode" "$src" "$dst"
        log_ok "Installiert: $dst"
    fi
}

# write_file_if_changed <ziel> <modus> – liest Inhalt von stdin, schreibt nur bei Änderung.
write_file_if_changed() {
    local dst="$1" mode="${2:-0644}" tmp
    tmp="$(mktemp)"
    cat > "$tmp"
    ensure_dir "$(dirname "$dst")"
    if [ -f "$dst" ] && cmp -s "$tmp" "$dst"; then
        log_skip "Unverändert: $dst"
        rm -f "$tmp"
    else
        install -m "$mode" "$tmp" "$dst"
        rm -f "$tmp"
        log_ok "Geschrieben: $dst"
    fi
}

# enable_service <unit> – aktiviert + startet nur, wenn nötig.
enable_service() {
    local unit="$1"
    systemctl daemon-reload
    if ! systemctl is-enabled --quiet "$unit" 2>/dev/null; then
        systemctl enable "$unit" >/dev/null 2>&1 && log_ok "Aktiviert: $unit"
    else
        log_skip "Bereits aktiviert: $unit"
    fi
    systemctl restart "$unit" && log_ok "Gestartet: $unit"
}

# ----------------------------------------------------------------- Backup ----
# backup_now <pfad...> – sichert existierende Dateien nach BACKUP_DIR/<ts>/.
# Setzt PIPORTAL_BACKUP_PATH auf das erzeugte Verzeichnis.
backup_now() {
    local base="${BACKUP_DIR:-/var/backups/piportal}"
    local ts; ts="$(date +%Y%m%d_%H%M%S)"
    local dest="${base}/${ts}"
    ensure_dir "$dest" 0700
    local manifest="${dest}/MANIFEST.txt"
    {
        echo "PiPortal-Backup ${ts}"
        echo "Host: $(hostname)  Kernel: $(uname -r)"
        echo "---"
    } > "$manifest"
    local item
    for item in "$@"; do
        if [ -e "$item" ]; then
            local target="${dest}${item}"
            ensure_dir "$(dirname "$target")" >/dev/null
            cp -a "$item" "$target"
            echo "$item" >> "$manifest"
            log_ok "Gesichert: $item"
        else
            echo "# fehlt (nicht gesichert): $item" >> "$manifest"
            log_skip "Existiert nicht, übersprungen: $item"
        fi
    done
    ln -sfn "$dest" "${base}/latest"
    PIPORTAL_BACKUP_PATH="$dest"
    log_info "Backup-Verzeichnis: $dest"
}

# ----------------------------------------------------------------- Prompts ---
# confirm <frage> – Ja/Nein; im Non-Interactive-Modus automatisch Ja.
confirm() {
    local q="$1"
    if [ "${PIPORTAL_NONINTERACTIVE:-0}" = "1" ]; then
        return 0
    fi
    local ans
    read -r -p "${q} [j/N] " ans
    case "$ans" in
        [jJyY]|[jJ][aA]) return 0 ;;
        *) return 1 ;;
    esac
}

# ask <frage> <variablenname> [default] – Freitext-Eingabe.
ask() {
    local q="$1" var="$2" def="${3:-}"
    if [ "${PIPORTAL_NONINTERACTIVE:-0}" = "1" ]; then
        printf -v "$var" '%s' "$def"
        return 0
    fi
    local ans
    if [ -n "$def" ]; then
        read -r -p "${q} [${def}]: " ans
        ans="${ans:-$def}"
    else
        read -r -p "${q}: " ans
    fi
    printf -v "$var" '%s' "$ans"
}

# ask_secret <frage> <variablenname> – verdeckte Eingabe (Passwörter).
ask_secret() {
    local q="$1" var="$2" ans
    if [ "${PIPORTAL_NONINTERACTIVE:-0}" = "1" ]; then
        printf -v "$var" '%s' ""
        return 0
    fi
    read -r -s -p "${q}: " ans; echo
    printf -v "$var" '%s' "$ans"
}

# ------------------------------------------------- Laufzeit-Config deployen --
# Kopiert config/piportal.conf nach /etc/piportal/piportal.conf, damit die
# installierten Dienste (Gadget, WLAN-Roaming) sie lesen können. Früh aufrufen.
deploy_runtime_config() {
    ensure_dir "${PIPORTAL_ETC}" 0755
    install_file "${PIPORTAL_CONFIG_DIR}/piportal.conf" "${PIPORTAL_ETC}/piportal.conf" 0640
}

# ----------------------------------------------------- deterministische MAC --
# derive_mac <suffix> – erzeugt eine stabile, lokal-administrierte Unicast-MAC
# aus /etc/machine-id + Suffix (z. B. "dev" oder "host").
derive_mac() {
    local suffix="$1"
    local hash
    hash="$(printf '%s' "$(cat /etc/machine-id 2>/dev/null)${suffix}" | sha256sum | head -c 12)"
    # Erstes Oktett: lokal administriert (bit 1) + unicast (bit 0 = 0) => 0x02.
    printf '02:%s:%s:%s:%s:%s\n' \
        "${hash:0:2}" "${hash:2:2}" "${hash:4:2}" "${hash:6:2}" "${hash:8:2}"
}
