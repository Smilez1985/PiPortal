#!/usr/bin/env bash
# =============================================================================
#  PiPortal – Modul 10: USB-Netzwerk & DHCP
#  - Statische IP für usb0 als updatesicheres Drop-in.
#  - dnsmasq als DHCP-Server für den Windows-Host, OHNE dessen Internet-
#    Gateway/DNS zu kapern (dhcp-option 3 und 6 leer, bind-dynamic, port=0).
# =============================================================================

module_10_network_usb() {
    log_step "Phase 1 – USB-Netzwerk & DHCP"

    ensure_pkg dnsmasq

    # --- usb0 statische IP (Drop-in, /etc/network/interfaces bleibt unberührt) ---
    write_file_if_changed /etc/network/interfaces.d/usb-gadget.conf 0644 <<EOF
# Von PiPortal verwaltet – nicht manuell editieren.
allow-hotplug usb0
iface usb0 inet static
    address ${USB_LAN_IP}
    netmask $(prefix_to_netmask "${USB_LAN_PREFIX}")
EOF

    # --- dnsmasq nur für usb0, ohne Gateway/DNS-Hijack ---
    write_file_if_changed /etc/dnsmasq.d/piportal-usb.conf 0644 <<EOF
# Von PiPortal verwaltet – DHCP nur auf usb0.
# Erscheint erst nach dem Gadget-Start => bind-dynamic (kein Startfehler).
interface=usb0
bind-dynamic
except-interface=wlan0
except-interface=lo

# dnsmasq ausschliesslich als DHCP-Server nutzen (kein DNS): Port 53 aus.
port=0

# Einziger DHCP-Server in diesem Subnetz => autoritativ (schnellere, sichere ACKs).
dhcp-authoritative

# DHCP-Bereich fuer den Windows-Host.
dhcp-range=set:usbnet,${DHCP_RANGE_START},${DHCP_RANGE_END},$(prefix_to_netmask "${USB_LAN_PREFIX}"),${DHCP_LEASE}

# ENTSCHEIDEND: dem Host KEIN Default-Gateway und KEINEN DNS aufdraengen,
# damit seine eigene Internetverbindung erhalten bleibt. Ein leerer Wert
# unterdrueckt nur Optionen, die dnsmasq von sich aus sendet (3/6/15).
dhcp-option=tag:usbnet,3          # Router / Default-Gateway: nicht senden
dhcp-option=tag:usbnet,6          # DNS-Server: nicht senden
dhcp-option=tag:usbnet,15         # Domainname: nicht senden
# WICHTIG: Optionen 119/121/249 NICHT auflisten! dnsmasq wuerde sie sonst als
# 0-Byte-Option senden -> Windows verwirft das gesamte DHCP-OFFER (kein REQUEST,
# Host landet auf APIPA 169.254.x.x). dnsmasq sendet sie ohnehin nie selbst.
EOF

    # Alte dnsmasq-Config aus dem manuellen Erstaufbau entfernen (ersetzt durch
    # piportal-usb.conf; sonst doppelte usb0-Range + Gateway-Hijack der Altdatei).
    if [ -f /etc/dnsmasq.d/usb-gadget.conf ]; then
        rm -f /etc/dnsmasq.d/usb-gadget.conf
        log_ok "Alte /etc/dnsmasq.d/usb-gadget.conf entfernt (ersetzt durch piportal-usb.conf)."
    fi

    systemctl restart dnsmasq && log_ok "dnsmasq neu gestartet (usb0-DHCP ohne Gateway-Hijack)."

    # usb0 anwerfen, falls das Gadget bereits läuft (sonst greift es beim Boot).
    if ip link show usb0 >/dev/null 2>&1; then
        ifup usb0 >/dev/null 2>&1 || true
        log_ok "usb0 konfiguriert: ${USB_LAN_IP}/${USB_LAN_PREFIX}"
    else
        log_info "usb0 noch nicht vorhanden – greift nach Gadget-Start (Modul 30) / Reboot."
    fi
}

# Wandelt ein CIDR-Prefix (z. B. 24) in eine Netzmaske (255.255.255.0).
prefix_to_netmask() {
    local prefix="$1" mask="" i octet
    for i in 0 1 2 3; do
        if [ "$prefix" -ge 8 ]; then octet=255; prefix=$((prefix-8))
        elif [ "$prefix" -gt 0 ]; then octet=$((256 - 2**(8-prefix))); prefix=0
        else octet=0; fi
        mask="${mask}${mask:+.}${octet}"
    done
    printf '%s' "$mask"
}
