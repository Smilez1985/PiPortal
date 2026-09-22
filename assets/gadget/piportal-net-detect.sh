#!/usr/bin/env bash
# =============================================================================
#  PiPortal – Auto-Erkennung NCM vs RNDIS
#
#  Nur bei NET_MODE=auto: das Gadget startet mit NCM (modern, treiberlos auf
#  Windows 11). Nimmt der verbundene Host NCM NICHT an (z. B. älteres Windows
#  ohne NCM-Inbox-Treiber), bleibt usb0 still – dann Fallback auf RNDIS.
#
#  Signal "Host hat das Face angenommen": Traffic auf usb0 (DHCP/ARP). Ein Host
#  ohne passenden Treiber sendet nichts. Ist gar kein Host verbunden (kein
#  Carrier), bleibt es bei NCM und wartet auf einen Host.
#
#  Wird von der systemd-Unit piportal-net-detect.service nach dem Gadget-Start
#  aufgerufen.
# =============================================================================
set -uo pipefail

CONF="/etc/piportal/piportal.conf"
NET_MODE="rndis"
NET_DETECT_WAIT="20"
# shellcheck disable=SC1090
[ -r "$CONF" ] && . "$CONF"

G="/sys/kernel/config/usb_gadget/piportal"
IFACE="usb0"
log() { printf '[piportal-net-detect] %s\n' "$*"; }
rx()  { cat "/sys/class/net/${IFACE}/statistics/rx_packets" 2>/dev/null || echo 0; }

[ "${NET_MODE}" = "auto" ] || { log "NET_MODE=${NET_MODE} (kein auto) – nichts zu tun."; exit 0; }
[ -d "${G}/functions/ncm.usb0" ] || { log "Kein NCM aktiv – kein Fallback nötig."; exit 0; }

# Auf usb0 warten (taucht kurz nach dem Gadget-Start via ifupdown auf).
j=0
while [ ! -d "/sys/class/net/${IFACE}" ] && [ "$j" -lt 15 ]; do sleep 1; j=$((j + 1)); done
[ -d "/sys/class/net/${IFACE}" ] || { log "${IFACE} nicht aufgetaucht – Abbruch."; exit 0; }

log "Warte bis zu ${NET_DETECT_WAIT}s, ob der Host NCM annimmt (usb0-Traffic)…"
i=0
while [ "$i" -lt "${NET_DETECT_WAIT}" ]; do
    if [ "$(rx)" -ge 4 ]; then
        log "Host kommuniziert über ${IFACE} – NCM angenommen, bleibe bei NCM."
        exit 0
    fi
    sleep 1
    i=$((i + 1))
done

# Kein Traffic. Ist überhaupt ein Host verbunden?
if [ "$(cat "/sys/class/net/${IFACE}/carrier" 2>/dev/null)" != "1" ]; then
    log "Kein Host verbunden (kein Carrier) – bleibe bei NCM, warte auf einen Host."
    exit 0
fi

log "Host verbunden, aber kein ${IFACE}-Traffic in ${NET_DETECT_WAIT}s – nimmt NCM nicht an. Fallback auf RNDIS."
echo rndis > /run/piportal-netmode
/usr/local/sbin/piportal-gadget.sh restart
log "Auf RNDIS umgestellt."
