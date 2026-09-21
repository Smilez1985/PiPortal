#!/usr/bin/env bash
# =============================================================================
#  PiPortal – Modul 40: SMB-Portal
#  - Installiert & härtet Samba (SMB2+/SMB3, kein Gast, ein User, nur usb0).
#  - Baut das read-only CD-ROM-Wegweiser-Image (ISO9660).
# =============================================================================

module_40_portal_smb() {
    log_step "Phase 4 – SMB-Portal + Wegweiser-Image"

    ensure_pkg samba samba-common-bin dosfstools mtools

    # --- 0. Unix-Benutzer sicherstellen (smbpasswd -a braucht ihn) ---
    if id -u "${SMB_USER}" >/dev/null 2>&1; then
        log_skip "Systembenutzer '${SMB_USER}' vorhanden."
    else
        log_info "Systembenutzer '${SMB_USER}' fehlt – wird angelegt."
        useradd -m -s /bin/bash "${SMB_USER}" || die "Konnte Benutzer '${SMB_USER}' nicht anlegen."
        log_ok "Benutzer '${SMB_USER}' angelegt."
    fi

    # --- 1. Share-Verzeichnis ---
    ensure_dir "${SMB_SHARE_PATH}" 2775 "${SMB_USER}:${SMB_USER}"

    # --- 2. Gehärtete Samba-Konfiguration (PiPortal-Block, restliche smb.conf bleibt) ---
    write_file_if_changed /etc/samba/smb.conf 0644 <<EOF
# Von PiPortal verwaltet. Gehärtet: SMB2+/SMB3, kein Gast, ein Benutzer, nur usb0.
[global]
   workgroup = WORKGROUP
   server string = PiPortal
   server role = standalone server

   # Nur auf dem USB-Gadget-Interface lauschen.
   interfaces = lo usb0 ${USB_LAN_IP}
   bind interfaces only = yes
   smb ports = 445

   # Protokoll-Härtung: kein SMB1.
   server min protocol = SMB2
   client min protocol = SMB2
   server max protocol = SMB3_11
   server signing = mandatory
$( [ "${SMB_ENCRYPT}" = "1" ] && echo "   smb encrypt = required" )

   # Kein anonymer / Gast-Zugriff.
   security = user
   map to guest = Never
   restrict anonymous = 2

   # Ressourcenschonend + kein NetBIOS.
   disable netbios = yes
   dns proxy = no
   load printers = no
   printing = bsd
   printcap name = /dev/null

[${SMB_SHARE_NAME}]
   comment = PiPortal Datentausch
   path = ${SMB_SHARE_PATH}
   browseable = yes
   read only = no
   guest ok = no
   valid users = ${SMB_USER}
   force user = ${SMB_USER}
   force group = ${SMB_USER}
   create mask = 0664
   directory mask = 0775
EOF

    # Konfiguration validieren, bevor der Dienst neu startet.
    if testparm -s >/dev/null 2>&1; then
        log_ok "smb.conf syntaktisch gültig."
    else
        die "smb.conf fehlerhaft – Abbruch, um den Dienst nicht zu beschädigen."
    fi

    # --- 3. SMB-Benutzer + Passwort ---
    if pdbedit -L 2>/dev/null | grep -q "^${SMB_USER}:"; then
        log_skip "SMB-Benutzer '${SMB_USER}' bereits angelegt."
    else
        local pw="${SMB_PASSWORD}"
        [ -z "$pw" ] && ask_secret "SMB-Passwort für Benutzer '${SMB_USER}' festlegen" pw
        if [ -n "$pw" ]; then
            printf '%s\n%s\n' "$pw" "$pw" | smbpasswd -a -s "${SMB_USER}" >/dev/null \
                && log_ok "SMB-Benutzer '${SMB_USER}' angelegt."
        else
            log_warn "Kein SMB-Passwort gesetzt – bitte später:  sudo smbpasswd -a ${SMB_USER}"
        fi
    fi

    systemctl restart smbd 2>/dev/null || systemctl restart smb 2>/dev/null || true
    log_ok "Samba neu gestartet."

    # --- 4. Wegweiser-Image bauen (read-only FAT) ---
    build_portal_image
}

# Baut ein kleines read-only FAT-Image mit Wegweiser-Inhalt (idempotent).
# FAT statt ISO9660, weil der RPi-Kernel 6.18 die cdrom=1-Emulation beim
# file-Binding ablehnt; ein FAT-Image + ro=1 ist der windows-kompatible Weg.
build_portal_image() {
    local staging; staging="$(mktemp -d)"
    cp "${PIPORTAL_ASSETS_DIR}/portal/LIESMICH.txt" "$staging/"
    cp "${PIPORTAL_ASSETS_DIR}/portal/PiPortal-Netzlaufwerk.url" "$staging/"
    [ "${ENABLE_SSH_HELPER}" = "1" ] && cp "${PIPORTAL_ASSETS_DIR}/windows/connect-piportal.cmd" "$staging/"

    ensure_dir "$(dirname "${PORTAL_IMAGE}")"
    local newimg; newimg="$(mktemp --suffix=.img)"
    # 16-MB-FAT16-Image: FAT16 braucht genug Cluster (4 MB scheitern als "too small"),
    # 16 MB ist die kleinste breit windows-kompatible Größe. Reichlich für den Wegweiser.
    truncate -s 16M "$newimg"
    if ! mkfs.vfat -F 16 -n "${PORTAL_LABEL}" "$newimg" >/dev/null 2>&1; then
        log_warn "Konnte FAT-Image nicht erstellen – Portal-Wegweiser übersprungen."
        rm -f "$newimg"; rm -rf "$staging"; return 0
    fi
    # Dateien ohne Mount hineinkopieren (mtools).
    ( cd "$staging" && MTOOLS_SKIP_CHECK=1 mcopy -i "$newimg" ./* :: ) 2>/dev/null \
        || log_warn "mcopy: nicht alle Wegweiser-Dateien konnten kopiert werden."

    if [ -f "${PORTAL_IMAGE}" ] && cmp -s "$newimg" "${PORTAL_IMAGE}"; then
        log_skip "Portal-Image unverändert: ${PORTAL_IMAGE}"
        rm -f "$newimg"
    else
        install -m 0644 "$newimg" "${PORTAL_IMAGE}"
        rm -f "$newimg"
        log_ok "Portal-Image erzeugt (read-only FAT): ${PORTAL_IMAGE}"
        # Falls Gadget schon läuft: Medium zur Laufzeit tauschen (removable).
        local lun="/sys/kernel/config/usb_gadget/piportal/functions/mass_storage.0/lun.0"
        if [ -w "${lun}/file" ]; then
            echo "" > "${lun}/file" 2>/dev/null || true
            echo "${PORTAL_IMAGE}" > "${lun}/file" 2>/dev/null \
                && log_ok "Wegweiser-Medium im laufenden Gadget aktualisiert."
        fi
    fi
    rm -rf "$staging"
}
