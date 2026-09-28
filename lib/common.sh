#!/usr/bin/env bash
# Deterministische, sprachunabhaengige Werkzeug-Ausgaben (Parsing sicher auf jedem Sprach-OS).
export LC_ALL=C.UTF-8
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

# ---------------------------------------------------------------- Version ----
# Einzige Wahrheitsquelle ist die Datei VERSION in der Repo-Wurzel.
# Der Installer schreibt sie nach ${PIPORTAL_ETC}/version, damit `piportal
# --version` auch ohne Repo auskunftsfaehig ist.
PIPORTAL_VERSION_FILE="${PIPORTAL_ROOT}/VERSION"
PIPORTAL_INSTALLED_VERSION_FILE="${PIPORTAL_ETC}/version"

# piportal_repo_version – Version aus dem Repo (leer, wenn nicht vorhanden).
piportal_repo_version() {
    [ -r "$PIPORTAL_VERSION_FILE" ] || return 1
    tr -d '[:space:]' < "$PIPORTAL_VERSION_FILE"
}

# piportal_installed_version – Version des installierten Systems.
piportal_installed_version() {
    [ -r "$PIPORTAL_INSTALLED_VERSION_FILE" ] || return 1
    tr -d '[:space:]' < "$PIPORTAL_INSTALLED_VERSION_FILE"
}

PIPORTAL_VERSION="$(piportal_repo_version 2>/dev/null || echo "unbekannt")"

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

# Angriffs-/Pentest-Distributionen (Blacklist). PiPortal ist ein defensives
# Admin-/Labor-Werkzeug und wird auf diesen Systemen bewusst NICHT installiert
# (Security by Design). Alles andere ist erlaubt – es gibt KEINEN DietPi-Zwang.
PIPORTAL_OFFENSIVE_DISTROS="kali parrot blackarch pentoo backbox kali-rolling parrotsec"

# assert_os – reine OS-Blacklist. Wird als ALLERERSTES im Installer aufgerufen,
# noch vor der Root-Prüfung, damit ein Angriffssystem sofort abgewiesen wird.
# Abgleich gegen ID und ID_LIKE aus /etc/os-release (in Subshells, damit die
# os-release-Variablen nicht in die aufrufende Shell leaken).
assert_os() {
    local os_id="" os_like="" os_name="unbekannt"
    if [ -r /etc/os-release ]; then
        os_id="$(. /etc/os-release 2>/dev/null; printf '%s' "${ID:-}")"
        os_like="$(. /etc/os-release 2>/dev/null; printf '%s' "${ID_LIKE:-}")"
        os_name="$(. /etc/os-release 2>/dev/null; printf '%s' "${PRETTY_NAME:-${NAME:-unbekannt}}")"
    fi
    local d
    for d in $PIPORTAL_OFFENSIVE_DISTROS; do
        case " ${os_id} ${os_like} " in
            *" ${d} "*)
                die "Installation auf '${os_name}' verweigert. PiPortal ist ein defensives Admin- und Labor-Werkzeug, kein Angriffssystem, und wird auf Pentest-Distributionen (Kali/Parrot/…) bewusst nicht installiert. Wer das umgehen will, muss den Quelltext bewusst und eigenverantwortlich anpassen."
                ;;
        esac
    done
}

# Plattform-Plausibilität (nur Hinweise, kein Abbruch – kein DietPi-Zwang).
assert_target() {
    local os_id=""
    [ -r /etc/os-release ] && os_id="$(. /etc/os-release 2>/dev/null; printf '%s' "${ID:-}")"
    [ "${os_id}" = "dietpi" ] || log_info "Kein DietPi erkannt – PiPortal ist für DietPi entwickelt, läuft aber grundsätzlich auf Debian-Derivaten."
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

# write_file_if_changed <ziel> <modus> [--allow-empty]
#   Liest den Inhalt von stdin und schreibt nur, wenn er sich unterscheidet.
#
# Schreibt ueber eine Sidecar-Datei NEBEN dem Ziel und benennt sie atomar um –
# dasselbe Muster, das die SAE-Haertung fuer cmdline.txt schon nutzt. Gruende:
#
#   * Kein /tmp noetig. `mktemp` liefert einen leeren Pfad, wenn TMPDIR auf ein
#     nicht existierendes Verzeichnis zeigt oder die RAM-Disk voll ist. Ohne
#     Pruefung lief `cat > ""` ins Leere und `install` bekam eine leere Quelle –
#     die Zieldatei war danach leer. Bei /boot/firmware/cmdline.txt bedeutet
#     das ein Geraet, das nicht mehr bootet.
#   * `mv` auf derselben Partition ist atomar: Es gibt keinen Moment, in dem
#     die Zieldatei halb geschrieben ist. Ein Stromausfall mittendrin laesst
#     entweder die alte oder die neue Fassung zurueck, nie eine kaputte.
#   * Kein zusaetzlicher Schreibzyklus ueber /tmp -> SD. Die Sidecar-Datei
#     liegt ohnehin auf derselben Partition wie das Ziel.
#
# Leerer Inhalt ersetzt eine nicht-leere Datei NICHT – das ist fast immer ein
# Fehler in der aufrufenden Pipeline. Wer bewusst leeren will, uebergibt
# --allow-empty.
write_file_if_changed() {
    local dst="$1" mode="${2:-0644}" allow_empty=0 tmp rc
    [ "${3:-}" = "--allow-empty" ] && allow_empty=1

    [ -n "$dst" ] || die "write_file_if_changed: kein Zielpfad angegeben"
    ensure_dir "$(dirname "$dst")"

    tmp="${dst}.piportal-tmp.$$"
    # Fehlschlaegt hier etwas, bleibt das Ziel unangetastet.
    if ! cat > "$tmp"; then
        rc=$?
        rm -f "$tmp"
        die "Konnte nicht nach ${tmp} schreiben (Exit ${rc}) – Ziel unveraendert: $dst"
    fi

    if [ ! -s "$tmp" ] && [ "$allow_empty" -eq 0 ]; then
        rm -f "$tmp"
        if [ -s "$dst" ]; then
            die "Leerer Inhalt fuer ${dst} – vorhandene Datei bleibt unveraendert. (Beabsichtigt? Dann --allow-empty uebergeben.)"
        fi
        log_warn "Leerer Inhalt fuer ${dst} – nichts geschrieben."
        return 0
    fi

    if [ -f "$dst" ] && cmp -s "$tmp" "$dst"; then
        log_skip "Unverändert: $dst"
        rm -f "$tmp"
        return 0
    fi

    chmod "$mode" "$tmp"
    # Besitzer/Gruppe des Ziels uebernehmen, falls vorhanden (mv erhaelt sie
    # sonst von der Sidecar-Datei, die root gehoert).
    if [ -e "$dst" ]; then
        chown --reference="$dst" "$tmp" 2>/dev/null || true
    fi
    mv -f "$tmp" "$dst" || { rm -f "$tmp"; die "Konnte ${dst} nicht ersetzen"; }
    log_ok "Geschrieben: $dst"
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

# ----------------------------------------------------- WLAN SAE-Haertung -----
# Verhindert die brcmfmac-WPA3/SAE-Regression, die ein Update-Reboot an einem
# WPA2/WPA3-Transition-AP das WLAN kosten kann: SAE_EXT (Bit 25) zusaetzlich
# abschalten -> feature_disable=0x282000 | 0x2000000 = 0x2282000. Wirksam ist
# die Kernel-Kommandozeile (gilt immer), modprobe.d ist die zweite Absicherung.
# Nur bei brcmfmac, idempotent, atomar, mit Backup. Wirkt erst nach einem Reboot.
harden_wlan_sae() {
    local drv
    drv="$(basename "$(readlink -f /sys/class/net/wlan0/device/driver 2>/dev/null)" 2>/dev/null)"
    if [ "$drv" != "brcmfmac" ]; then
        log_skip "WLAN-Chip '${drv:-unbekannt}' – keine SAE-Haertung noetig."
        return 0
    fi
    printf 'options brcmfmac roamoff=1 feature_disable=0x2282000\n' \
        | write_file_if_changed /etc/modprobe.d/rpi-brcmfmac-sae.conf 0644

    local cmd="/boot/firmware/cmdline.txt" tok="brcmfmac.feature_disable=0x2282000"
    if [ ! -f "$cmd" ]; then
        log_warn "cmdline.txt fehlt – SAE-Haertung nur ueber modprobe.d gesetzt."
    elif grep -q 'feature_disable=0x2282000' "$cmd"; then
        log_skip "WLAN-SAE-Haertung in cmdline bereits gesetzt."
    else
        backup_now "$cmd" >/dev/null
        local line; line="$(tr -d '\n' < "$cmd")"
        printf '%s %s\n' "$line" "$tok" > "${cmd}.new"
        if [ "$(wc -l < "${cmd}.new")" -eq 1 ] && grep -q 'root=' "${cmd}.new" && grep -q "$tok" "${cmd}.new"; then
            mv "${cmd}.new" "$cmd"
            log_ok "WLAN-SAE-Haertung in cmdline gesetzt (wirkt nach dem naechsten Reboot)."
        else
            rm -f "${cmd}.new"
            log_warn "cmdline-Sanity fehlgeschlagen – SAE-Haertung in cmdline uebersprungen."
        fi
    fi
}
