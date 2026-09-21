#!/usr/bin/env bash
# =============================================================================
#  PiPortal – USB-Composite-Gadget (configfs / libcomposite)
#  Baut RNDIS (Windows) + CDC-ECM (Linux/macOS) + Mass Storage (CD-ROM, RO).
#
#  Wird von der systemd-Unit piportal-gadget.service aufgerufen.
#  Aufruf:  piportal-gadget.sh {up|down|restart|status}
#
#  Idempotent: 'up' räumt ein evtl. bestehendes Gadget vorher sauber ab
#  (Teardown), bevor es neu baut. 'up' auf einem bereits laufenden Gadget
#  ist damit gefahrlos wiederholbar.
# =============================================================================
set -euo pipefail

GADGET_NAME="piportal"
CONFIGFS="/sys/kernel/config/usb_gadget"
G="${CONFIGFS}/${GADGET_NAME}"
CONF="/etc/piportal/piportal.conf"

# ------------------------------------------------------------ Konfiguration --
# Defaults, per /etc/piportal/piportal.conf überschreibbar.
GADGET_VENDOR_ID="0x1d6b"
GADGET_PRODUCT_ID="0xa4ac"
GADGET_MANUFACTURER="PiPortal"
GADGET_PRODUCT="PiPortal Composite Gadget"
GADGET_SERIAL=""
ENABLE_RNDIS="1"
ENABLE_ECM="0"
ENABLE_NCM="0"
ENABLE_MASS_STORAGE="1"
PORTAL_IMAGE="/srv/piportal/portal.iso"

# shellcheck disable=SC1090
[ -f "$CONF" ] && . "$CONF"

log() { printf '[piportal-gadget] %s\n' "$*"; }

derive_mac() {
    local suffix="$1" hash
    hash="$(printf '%s' "$(cat /etc/machine-id 2>/dev/null)${suffix}" | sha256sum | head -c 12)"
    printf '02:%s:%s:%s:%s:%s\n' \
        "${hash:0:2}" "${hash:2:2}" "${hash:4:2}" "${hash:6:2}" "${hash:8:2}"
}

# ----------------------------------------------------------------- Teardown --
gadget_down() {
    if [ ! -d "$G" ]; then
        log "Kein Gadget vorhanden – nichts abzubauen."
        return 0
    fi
    local l cfg f
    # 1. Vom UDC lösen.
    if [ -e "${G}/UDC" ]; then
        echo "" > "${G}/UDC" 2>/dev/null || true
    fi
    # 2. os_desc-Config-Links entfernen (NUR Symlinks wie os_desc/c.1,
    #    nicht die Attribut-Dateien b_vendor_code/qw_sign/use). Muss vor dem
    #    Config-Abbau geschehen, sonst schlägt ein späteres 'ln' fehl.
    for l in "${G}/os_desc/"*; do
        [ -L "$l" ] && rm -f "$l"
    done
    # 3. Funktions-Links aus allen Configs entfernen, dann Strings + Config.
    for cfg in "${G}/configs/"*/; do
        [ -d "$cfg" ] || continue
        for f in "${cfg}"*; do
            [ -L "$f" ] && rm -f "$f"
        done
        [ -d "${cfg}strings/0x409" ] && rmdir "${cfg}strings/0x409" 2>/dev/null || true
        rmdir "$cfg" 2>/dev/null || true
    done
    # 4. Funktionen entfernen.
    for f in "${G}/functions/"*/; do
        [ -d "$f" ] && rmdir "$f" 2>/dev/null || true
    done
    # 5. Gadget-Strings + Gadget entfernen.
    [ -d "${G}/strings/0x409" ] && rmdir "${G}/strings/0x409" 2>/dev/null || true
    rmdir "$G" 2>/dev/null || true
    log "Gadget abgebaut."
}

# ------------------------------------------------------------------- Aufbau --
gadget_up() {
    modprobe libcomposite 2>/dev/null || true
    [ -d "$CONFIGFS" ] || { log "FEHLER: configfs nicht gemountet."; exit 1; }

    # Sauberer Neuaufbau => erst abräumen.
    gadget_down

    # Seriennummer bestimmen.
    local serial="$GADGET_SERIAL"
    [ -z "$serial" ] && serial="$(cat /etc/machine-id 2>/dev/null | head -c 16)"

    mkdir -p "$G"
    echo "$GADGET_VENDOR_ID"  > "${G}/idVendor"
    echo "$GADGET_PRODUCT_ID" > "${G}/idProduct"
    echo 0x0200 > "${G}/bcdUSB"       # USB 2.0
    echo 0x0100 > "${G}/bcdDevice"    # v1.0.0
    # Composite-Device-Klasse (0xEF/0x02/0x01) für IAD.
    echo 0xEF > "${G}/bDeviceClass"
    echo 0x02 > "${G}/bDeviceSubClass"
    echo 0x01 > "${G}/bDeviceProtocol"

    mkdir -p "${G}/strings/0x409"
    echo "$serial"              > "${G}/strings/0x409/serialnumber"
    echo "$GADGET_MANUFACTURER" > "${G}/strings/0x409/manufacturer"
    echo "$GADGET_PRODUCT"      > "${G}/strings/0x409/product"

    # --- MS-OS-Descriptors auf Gadget-Ebene (für RNDIS-Auto-Bind unter Windows).
    if [ "$ENABLE_RNDIS" = "1" ]; then
        echo 1        > "${G}/os_desc/use"
        echo 0xcd     > "${G}/os_desc/b_vendor_code"
        echo "MSFT100" > "${G}/os_desc/qw_sign"
    fi

    local dev_mac host_mac
    dev_mac="$(derive_mac dev)"
    host_mac="$(derive_mac host)"

    # ------------------------------------------------------------ Funktionen --
    # RNDIS zuerst anlegen (Interface-Reihenfolge: Windows erwartet RNDIS vorn).
    if [ "$ENABLE_RNDIS" = "1" ]; then
        mkdir -p "${G}/functions/rndis.usb0"
        echo "$dev_mac"  > "${G}/functions/rndis.usb0/dev_addr"
        echo "$host_mac" > "${G}/functions/rndis.usb0/host_addr"
        # Compat-IDs, damit Windows den RNDIS-6.0-Inbox-Treiber lädt.
        echo "RNDIS"    > "${G}/functions/rndis.usb0/os_desc/interface.rndis/compatible_id"
        echo "5162001"  > "${G}/functions/rndis.usb0/os_desc/interface.rndis/sub_compatible_id"
    fi
    if [ "$ENABLE_ECM" = "1" ]; then
        mkdir -p "${G}/functions/ecm.usb0"
        echo "$dev_mac"  > "${G}/functions/ecm.usb0/dev_addr"
        echo "$host_mac" > "${G}/functions/ecm.usb0/host_addr"
    fi
    if [ "$ENABLE_NCM" = "1" ]; then
        mkdir -p "${G}/functions/ncm.usb0"
        echo "$dev_mac"  > "${G}/functions/ncm.usb0/dev_addr"
        echo "$host_mac" > "${G}/functions/ncm.usb0/host_addr"
    fi
    if [ "$ENABLE_MASS_STORAGE" = "1" ]; then
        mkdir -p "${G}/functions/mass_storage.0"
        echo 1 > "${G}/functions/mass_storage.0/stall"
        local L="${G}/functions/mass_storage.0/lun.0"
        # Read-only Wechseldatenträger als "Wegweiser".
        # Hinweis: cdrom=1 (ISO9660-Emulation) lehnt der RPi-Kernel 6.18 beim
        # file-Binding mit Fehler 525 ab. Deshalb ro=1 + FAT-Image – Windows
        # behandelt es als schreibgeschützten USB-Stick (kein Schreibmüll).
        # ro und removable MÜSSEN vor 'file' gesetzt werden.
        echo 1 > "${L}/ro"
        echo 1 > "${L}/removable"
        if [ -f "$PORTAL_IMAGE" ]; then
            echo "$PORTAL_IMAGE" > "${L}/file"
        else
            log "WARN: Portal-Image fehlt ($PORTAL_IMAGE) – LUN startet ohne Medium."
        fi
    fi

    # ---------------------------------------------------------------- Configs --
    # Config 1 = RNDIS (Windows) + Mass Storage. Muss die OS-Descriptor-Config sein.
    mkdir -p "${G}/configs/c.1/strings/0x409"
    echo "PiPortal RNDIS" > "${G}/configs/c.1/strings/0x409/configuration"
    echo 250 > "${G}/configs/c.1/MaxPower"
    if [ "$ENABLE_RNDIS" = "1" ]; then
        ln -sf "${G}/functions/rndis.usb0" "${G}/configs/c.1/rndis.usb0"
        # OS-Descriptor auf Config 1 zeigen lassen.
        ln -sf "${G}/configs/c.1" "${G}/os_desc/c.1"
    fi
    [ "$ENABLE_MASS_STORAGE" = "1" ] && ln -sf "${G}/functions/mass_storage.0" "${G}/configs/c.1/mass_storage.0"

    # Config 2 = ECM/NCM (Linux/macOS) + Mass Storage.
    if [ "$ENABLE_ECM" = "1" ] || [ "$ENABLE_NCM" = "1" ]; then
        mkdir -p "${G}/configs/c.2/strings/0x409"
        echo "PiPortal CDC" > "${G}/configs/c.2/strings/0x409/configuration"
        echo 250 > "${G}/configs/c.2/MaxPower"
        [ "$ENABLE_ECM" = "1" ] && ln -sf "${G}/functions/ecm.usb0" "${G}/configs/c.2/ecm.usb0"
        [ "$ENABLE_NCM" = "1" ] && ln -sf "${G}/functions/ncm.usb0" "${G}/configs/c.2/ncm.usb0"
        [ "$ENABLE_MASS_STORAGE" = "1" ] && ln -sf "${G}/functions/mass_storage.0" "${G}/configs/c.2/mass_storage.0"
    fi

    # ----------------------------------------------------------- an UDC binden --
    # Auf den UDC warten: dwc2 wird beim Boot asynchron geladen, der Controller
    # ist evtl. noch nicht da, wenn diese Unit anläuft (bis ~10 s warten).
    local udc="" i
    for i in $(seq 1 50); do
        udc="$(ls /sys/class/udc 2>/dev/null | head -n1 || true)"
        [ -n "$udc" ] && break
        sleep 0.2
    done
    [ -n "$udc" ] || { log "FEHLER: kein UDC gefunden nach 10 s (dwc2 aktiv? g_multi in cmdline entfernt?)."; exit 1; }

    # Binden mit Retry: falls der UDC kurz belegt ist (z. B. Legacy-g_multi noch
    # nicht vollständig gelöst), mehrfach versuchen statt hart abzubrechen.
    for i in $(seq 1 25); do
        if echo "$udc" > "${G}/UDC" 2>/dev/null; then
            log "Gadget gebunden an UDC: $udc"
            return 0
        fi
        sleep 0.2
    done
    log "FEHLER: Binden an UDC '$udc' fehlgeschlagen (belegt? Läuft noch g_multi? Dann Reboot nötig)."
    exit 1
}

# ------------------------------------------------------------------ Status ---
gadget_status() {
    if [ -d "$G" ]; then
        local udc; udc="$(cat "${G}/UDC" 2>/dev/null || true)"
        if [ -n "$udc" ]; then
            log "Gadget aktiv, gebunden an: $udc"
        else
            log "Gadget existiert, aber nicht an UDC gebunden."
        fi
        ls "${G}/functions" 2>/dev/null | sed 's/^/  Funktion: /'
    else
        log "Kein Gadget aktiv."
    fi
}

case "${1:-}" in
    up)      gadget_up ;;
    down)    gadget_down ;;
    restart) gadget_down; gadget_up ;;
    status)  gadget_status ;;
    *) echo "Aufruf: $0 {up|down|restart|status}"; exit 2 ;;
esac
