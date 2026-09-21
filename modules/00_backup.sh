#!/usr/bin/env bash
# =============================================================================
#  PiPortal – Modul 00: Backup
#  Sichert alle Systemdateien, die spätere Module verändern könnten.
#  Wird von install.sh gesourct (nutzt Funktionen aus lib/common.sh).
# =============================================================================

module_00_backup() {
    log_step "Phase 0 – Backup der betroffenen Systemdateien"

    backup_now \
        /boot/firmware/config.txt \
        /boot/firmware/cmdline.txt \
        /boot/dietpi.txt \
        /etc/hostname \
        /etc/hosts \
        /etc/fstab \
        /etc/default/zramswap \
        /etc/sysctl.d/99-piportal-swap.conf \
        /etc/network/interfaces \
        /etc/network/interfaces.d \
        /etc/wpa_supplicant/wpa_supplicant.conf \
        /etc/dnsmasq.d \
        /etc/dnsmasq.conf \
        /etc/samba/smb.conf \
        /var/lib/dietpi/dietpi-autostart/custom.sh \
        /pi-usb-drive.img

    log_ok "Backup abgeschlossen. Rollback jederzeit mit:  sudo ./uninstall.sh"
}
