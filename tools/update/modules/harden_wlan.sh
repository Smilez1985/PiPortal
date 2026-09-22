#!/usr/bin/env bash
# =============================================================================
#  PiPortal Update-Modul: WLAN-Haertung gegen die SAE/brcmfmac-Regression
#
#  Hintergrund: 'wpasupplicant 2:2.10-24+rpt1' meldet SAE-Faehigkeit, die
#  Broadcom-Firmware (brcmfmac) kann den externen SAE-Handshake aber nicht.
#  An einem WPA2/WPA3-Transition-AP scheitert die 802.11-Authentifizierung nach
#  einem Reboot -> WLAN weg. Gegenmittel: SAE_EXT (Bit 25) zusaetzlich abschalten
#  (feature_disable 0x282000 + 0x2000000 = 0x2282000). Wirksam ist die
#  Kernel-Kommandozeile (gilt immer), modprobe.d ist die zweite Absicherung.
#
#  Dieses Modul ist idempotent: es aendert nur, was fehlt, mit Backup, und
#  vermerkt bei einer Aenderung, dass ein Reboot noetig ist.
# =============================================================================
set -uo pipefail
LOG_TAG="WLAN"
# shellcheck source=lib_common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib_common.sh"

CMDLINE="/boot/firmware/cmdline.txt"
MODPROBE="/etc/modprobe.d/rpi-brcmfmac-sae.conf"
TOKEN="brcmfmac.feature_disable=0x2282000"

# Nur auf Broadcom-brcmfmac-Chips relevant.
driver="$(basename "$(readlink -f /sys/class/net/wlan0/device/driver 2>/dev/null)" 2>/dev/null)"
if [ "$driver" != "brcmfmac" ]; then
    log_skip "WLAN-Treiber ist '${driver:-unbekannt}', nicht brcmfmac -- SAE-Haertung nicht noetig"
    exit 0
fi

changed=0

# --- 1) modprobe.d-Absicherung (idempotent) ---
want_modprobe="options brcmfmac roamoff=1 feature_disable=0x2282000"
if [ -f "$MODPROBE" ] && grep -qF "feature_disable=0x2282000" "$MODPROBE"; then
    log_skip "modprobe.d bereits gesetzt: $MODPROBE"
else
    if [ "$DRY_RUN" = "1" ]; then
        log "TROCKEN wuerde schreiben: $MODPROBE"
    else
        printf '%s\n' "$want_modprobe" | sudo tee "$MODPROBE" >/dev/null && log_ok "modprobe.d gesetzt: $MODPROBE"
    fi
    changed=1
fi

# --- 2) Kernel-Kommandozeile (der zuverlaessige Weg), atomar mit Backup ---
if [ ! -f "$CMDLINE" ]; then
    log_warn "cmdline nicht gefunden ($CMDLINE) -- uebersprungen (modprobe.d greift dennoch)"
elif grep -q "feature_disable=0x2282000" "$CMDLINE"; then
    log_skip "cmdline traegt den SAE-Fix bereits"
else
    if [ "$DRY_RUN" = "1" ]; then
        log "TROCKEN wuerde '$TOKEN' an $CMDLINE anhaengen"
        changed=1
    else
        bak="$(backup_file "$CMDLINE" cmdline.txt)" || { log_err "Kein Backup -- cmdline unangetastet"; exit 1; }
        line="$(tr -d '\n' < "$CMDLINE")"
        printf '%s %s\n' "$line" "$TOKEN" | sudo tee "${CMDLINE}.new" >/dev/null
        # Sanity: genau eine Zeile, root= erhalten, Token vorhanden.
        if [ "$(wc -l < "${CMDLINE}.new")" -eq 1 ] && grep -q 'root=' "${CMDLINE}.new" && grep -q "$TOKEN" "${CMDLINE}.new"; then
            sudo mv "${CMDLINE}.new" "$CMDLINE"
            log_ok "SAE-Fix an cmdline angehaengt (Backup: $bak)"
            changed=1
        else
            sudo rm -f "${CMDLINE}.new"
            log_err "cmdline-Sanity fehlgeschlagen -- nichts geaendert"
            exit 1
        fi
    fi
fi

if [ "$changed" = "1" ]; then
    # Aktiv wird die Aenderung erst nach einem Reboot.
    grep -q "feature_disable=0x2282000" /proc/cmdline 2>/dev/null \
        || mark_reboot_needed "WLAN-SAE-Haertung neu gesetzt (Kernel-cmdline)"
    log_ok "WLAN-SAE-Haertung sichergestellt"
else
    log_ok "WLAN-SAE-Haertung war bereits vollstaendig"
fi
exit 0
