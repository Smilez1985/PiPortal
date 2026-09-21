#!/usr/bin/env bash
# =============================================================================
#  PiPortal – Modul 01: Hostname
#  Setzt den Hostnamen (Standard: PiPortal). Idempotent; pflegt /etc/hostname,
#  /etc/hosts und den laufenden Hostnamen. Voll aktiv nach dem nächsten Reboot.
# =============================================================================

module_01_hostname() {
    log_step "Phase 0.1 – Hostname"

    local new="${PIPORTAL_HOSTNAME:-PiPortal}"
    local cur; cur="$(hostname)"

    if [ "$cur" = "$new" ]; then
        log_skip "Hostname bereits '$new'."
        return 0
    fi

    log_info "Setze Hostname: '$cur' -> '$new'"

    # /etc/hostname
    printf '%s\n' "$new" > /etc/hostname

    # /etc/hosts: 127.0.1.1-Zeile auf den neuen Namen zeigen lassen.
    if grep -qE '^[[:space:]]*127\.0\.1\.1' /etc/hosts 2>/dev/null; then
        sed -i "s/^[[:space:]]*127\.0\.1\.1.*/127.0.1.1\t${new}/" /etc/hosts
    else
        printf '127.0.1.1\t%s\n' "$new" >> /etc/hosts
    fi

    # Laufenden Hostnamen setzen (systemd bevorzugt, sonst klassisch).
    if command -v hostnamectl >/dev/null 2>&1; then
        hostnamectl set-hostname "$new" 2>/dev/null || hostname "$new"
    else
        hostname "$new"
    fi

    log_ok "Hostname gesetzt: '$new' (Zugriff u. a. via \\\\${new}.local, voll aktiv nach Reboot)."
}
