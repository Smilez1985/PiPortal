#!/usr/bin/env bash
# =============================================================================
#  PiPortal – Wegweiser-Image neu bauen + zur Laufzeit sauber neu einlegen
#
#  Baut ein frisches read-only FAT16-Image aus dem Signpost-Verzeichnis
#  (/srv/piportal/signpost) und legt es am Host neu ein – ohne Aus-/Einstecken.
#  Sauberer Weg: forced_eject (erzwingt den Auswurf, umgeht Windows' "prevent
#  medium removal"), dann neues Medium in lun.0/file. So sieht der Host den
#  aktualisierten Inhalt, statt das read-only Medium weiter zu cachen.
#
#  Aufruf:  piportal-publish.sh   (als root; auch via 'piportal --publish')
# =============================================================================
set -uo pipefail
# Deterministische, sprachunabhaengige Werkzeug-Ausgaben (Parsing sicher auf jedem Sprach-OS).
export LC_ALL=C.UTF-8

CONF="/etc/piportal/piportal.conf"
PORTAL_IMAGE="/srv/piportal/portal.img"
PORTAL_LABEL="PIPORTAL"
SIGNPOST_DIR=""
# shellcheck disable=SC1090
[ -r "$CONF" ] && . "$CONF"
# Signpost-Quelle aus dem Image-Pfad ableiten, falls nicht per Config gesetzt.
SIGNPOST_DIR="${SIGNPOST_DIR:-$(dirname "$PORTAL_IMAGE")/signpost}"

LUN="/sys/kernel/config/usb_gadget/piportal/functions/mass_storage.0/lun.0"
log() { printf '[piportal-publish] %s\n' "$*"; }

[ -d "$SIGNPOST_DIR" ] || { log "FEHLER: Signpost-Quelle fehlt: $SIGNPOST_DIR"; exit 1; }

# --- 1. Frisches FAT16-Image aus dem Signpost-Verzeichnis bauen ---
newimg="$(mktemp --suffix=.img)"
trap 'rm -f "$newimg"' EXIT
truncate -s 16M "$newimg"
if ! mkfs.vfat -F 16 -n "$PORTAL_LABEL" "$newimg" >/dev/null 2>&1; then
    log "FEHLER: FAT-Image konnte nicht erstellt werden."; exit 1
fi
if [ -n "$(find "$SIGNPOST_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
    ( cd "$SIGNPOST_DIR" && MTOOLS_SKIP_CHECK=1 mcopy -i "$newimg" ./* :: ) 2>/dev/null \
        || log "WARN: nicht alle Wegweiser-Dateien konnten kopiert werden."
fi

# --- 2. Persistentes Image aktualisieren ---
install -m 0644 "$newimg" "$PORTAL_IMAGE"
log "Wegweiser-Image neu gebaut: $PORTAL_IMAGE"

# --- 3. Zur Laufzeit am Host neu einlegen (forced_eject -> neues file) ---
if [ -w "${LUN}/file" ]; then
    if [ -e "${LUN}/forced_eject" ] && [ -w "${LUN}/forced_eject" ]; then
        echo 1 > "${LUN}/forced_eject" 2>/dev/null && log "Medium ausgeworfen (forced_eject)."
    else
        # Fallback ohne forced_eject: Backing-Datei lösen.
        echo "" > "${LUN}/file" 2>/dev/null || true
    fi
    sleep 1
    if echo "$PORTAL_IMAGE" > "${LUN}/file" 2>/dev/null; then
        log "Neues Medium eingelegt – der Host sieht jetzt den aktualisierten Inhalt."
    else
        log "WARN: Konnte neues Medium nicht einlegen."
    fi
else
    log "Gadget nicht aktiv – Image gespeichert, greift beim nächsten Gadget-Start."
fi
