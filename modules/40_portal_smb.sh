#!/usr/bin/env bash
# =============================================================================
#  PiPortal – Modul 40: SMB-Portal
#  - Installiert & härtet Samba (SMB2+/SMB3, kein Gast, ein User, nur usb0).
#  - Baut das read-only FAT-Wegweiser-Image (ro=1, removable=1).
# =============================================================================

module_40_portal_smb() {
    log_step "Phase 4 – SMB-Portal + Wegweiser-Image"

    # --- SMB-/Login-Benutzer bestimmen (nie hart verdrahtet) ---
    # Echte, deklarierte Variable SMB_USER. Wenn die Config sie leer lässt, aus
    # mehreren Quellen redundant ableiten (Reihenfolge = Vorrang), nie root:
    #   1) SUDO_USER   – der Nicht-Root-Login, der 'sudo ./install.sh' aufrief
    #   2) logname     – der angemeldete Benutzer (OS)
    #   3) Eigentümer des Repo-Verzeichnisses (aus dem Dateipfad, PIPORTAL_ROOT)
    # So passt es auf DietPi ('dietpi') wie auf jedem anderen Linux/Benutzernamen.
    if [ -z "${SMB_USER:-}" ]; then
        SMB_USER="${SUDO_USER:-}"
        [ -z "${SMB_USER}" ] && SMB_USER="$(logname 2>/dev/null || true)"
        [ -z "${SMB_USER}" ] && SMB_USER="$(stat -c '%U' "${PIPORTAL_ROOT}" 2>/dev/null || true)"
        [ "${SMB_USER}" = "root" ] && SMB_USER=""
    fi
    if [ -z "${SMB_USER}" ] || [ "${SMB_USER}" = "root" ]; then
        die "SMB_USER ist leer bzw. root – bitte in der Config einen Nicht-Root-Benutzer setzen (SMB_USER=...)."
    fi
    log_info "SMB-/Login-Benutzer: ${SMB_USER}"

    # avahi-daemon: \\PiPortal.local auflösbar. gettext-base liefert envsubst,
    # mit dem die Wegweiser-Vorlagen aus echten ${PP_*}-Variablen gerendert werden.
    ensure_pkg samba samba-common-bin dosfstools mtools avahi-daemon gettext-base

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

    # Kurz-Anleitung auch in den Share legen – das ist, was der Nutzer sieht,
    # wenn er das Netzlaufwerk oeffnet. Beide Sprachen + zweisprachige .md,
    # bei jedem Lauf aktualisiert und aus den echten ${PP_*}-Variablen gerendert.
    local doc
    for doc in LIESMICH.txt readme.txt README.md; do
        if [ -f "${PIPORTAL_ASSETS_DIR}/portal/${doc}" ]; then
            render_asset "${PIPORTAL_ASSETS_DIR}/portal/${doc}" "${SMB_SHARE_PATH}/${doc}" \
                && chown "${SMB_USER}:${SMB_USER}" "${SMB_SHARE_PATH}/${doc}" 2>/dev/null || true
        fi
    done

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
            log_warn "Kein SMB-Passwort gesetzt. Vor der ersten Nutzung setzen mit:"
            log_info "   piportal --smb-passwd   (oder auf dem Laufwerk: SMB-Passwort.vbs)"
        fi
    fi

    systemctl restart smbd 2>/dev/null || systemctl restart smb 2>/dev/null || true
    log_ok "Samba neu gestartet."

    # mDNS aktivieren, damit \\PiPortal.local vom Host aufgelöst wird.
    systemctl enable --now avahi-daemon >/dev/null 2>&1 || true
    log_ok "mDNS (avahi) aktiv – \\\\${PIPORTAL_HOSTNAME:-PiPortal}.local nutzbar."

    # --- 4. Wegweiser-Image bauen (read-only FAT) ---
    build_portal_image
}

# Befüllt das persistente Signpost-Verzeichnis und baut daraus das read-only
# FAT-Wegweiser-Image. Das eigentliche Bauen + saubere Neu-Einlegen erledigt
# der Publish-Helfer (piportal-publish.sh), den auch 'piportal --publish' ruft –
# so gibt es genau EINEN Weg, das Image zu erzeugen (keine doppelte Logik).
# FAT statt ISO9660, weil der RPi-Kernel 6.18 die cdrom=1-Emulation beim
# file-Binding ablehnt; ein FAT-Image + ro=1 ist der windows-kompatible Weg.
build_portal_image() {
    # Persistentes Signpost-Staging: hier liegen die Wegweiser-Dateien dauerhaft,
    # daraus baut --publish jederzeit neu. Neben dem Image, per Konvention.
    local sp; sp="$(dirname "${PORTAL_IMAGE}")/signpost"
    ensure_dir "$sp" 0755

    # Wegweiser-Inhalt (bei jedem Lauf aus dem Repo aktualisieren) – alle Dateien
    # werden aus den echten ${PP_*}-Variablen gerendert (kein hart verdrahteter Name).
    render_asset "${PIPORTAL_ASSETS_DIR}/portal/LIESMICH.txt"              "$sp/LIESMICH.txt"
    render_asset "${PIPORTAL_ASSETS_DIR}/portal/readme.txt"                "$sp/readme.txt"
    render_asset "${PIPORTAL_ASSETS_DIR}/portal/README.md"                 "$sp/README.md"
    render_asset "${PIPORTAL_ASSETS_DIR}/portal/PiPortal-Netzlaufwerk.url" "$sp/PiPortal-Netzlaufwerk.url"
    # Optionale/veraltete Helfer erst entfernen (Upgrade-sauber), dann neu setzen.
    # Die frueheren zwei VBS (setzen/vergessen) sind durch die eine SMB-Passwort.vbs ersetzt.
    rm -f "$sp/connect-piportal.cmd" "$sp/Claude-Code.vbs" \
          "$sp/SMB-Passwort_setzen.vbs" "$sp/SMB-Passwort_vergessen.vbs"
    [ "${ENABLE_SSH_HELPER}" = "1" ] && \
        render_asset "${PIPORTAL_ASSETS_DIR}/windows/connect-piportal.cmd" "$sp/connect-piportal.cmd"
    render_asset "${PIPORTAL_ASSETS_DIR}/windows/Netzlaufwerk-verbinden.cmd" "$sp/Netzlaufwerk-verbinden.cmd"
    # Ein Werkzeug fuer beide Faelle (Setzen bei Erst-Einrichtung, Zuruecksetzen wenn gesetzt).
    render_asset "${PIPORTAL_ASSETS_DIR}/windows/SMB-Passwort.vbs"           "$sp/SMB-Passwort.vbs"
    [ "${ENABLE_CLAUDE_CODE}" = "1" ] && \
        render_asset "${PIPORTAL_ASSETS_DIR}/windows/Claude-Code.vbs" "$sp/Claude-Code.vbs"

    ensure_dir "$(dirname "${PORTAL_IMAGE}")"

    # Publish-Helfer installieren (wird auch von 'piportal --publish' genutzt).
    install_file "${PIPORTAL_ASSETS_DIR}/gadget/piportal-publish.sh" "${PIPORTAL_SBIN}/piportal-publish.sh" 0755

    # Image aus dem Signpost-Staging bauen + (falls Gadget läuft) sauber neu einlegen.
    if "${PIPORTAL_SBIN}/piportal-publish.sh"; then
        log_ok "Portal-Image erzeugt (read-only FAT): ${PORTAL_IMAGE}"
    else
        log_warn "Portal-Image-Build meldete einen Fehler (siehe Ausgabe oben)."
    fi
}

# Rendert eine Wegweiser-Vorlage in die Zieldatei: ersetzt AUSSCHLIESSLICH die
# echten Variablen ${PP_USER} / ${PP_IP} / ${PP_SHARE} (envsubst mit fester
# Shell-Format-Liste – alle anderen $-Sequenzen bleiben unangetastet). So sind
# Benutzer/IP/Freigabe deklariert, importiert und nirgends hart verdrahtet.
render_asset() {
    local src="$1" dst="$2"
    [ -f "$src" ] || { log_warn "Vorlage fehlt: $src"; return 1; }
    # envsubst rendert die echten Variablen; sed erzwingt CRLF, weil ALLE
    # Wegweiser-/Share-Dateien auf Windows gelesen werden (altes Notepad/cscript
    # erwarten CRLF). 'sed s/\r*$/\r/' normalisiert vorhandene CRs und setzt CRLF.
    PP_USER="${SMB_USER}" PP_IP="${USB_LAN_IP}" PP_SHARE="${SMB_SHARE_NAME}" \
        envsubst '${PP_USER} ${PP_IP} ${PP_SHARE}' < "$src" \
        | sed 's/\r*$/\r/' > "$dst"
    chmod 0644 "$dst"
}
