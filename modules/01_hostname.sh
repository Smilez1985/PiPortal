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

    # /etc/hostname idempotent setzen.
    if [ "$(cat /etc/hostname 2>/dev/null)" != "$new" ]; then
        printf '%s\n' "$new" > /etc/hostname
        log_ok "/etc/hostname -> $new"
    else
        log_skip "/etc/hostname bereits '$new'."
    fi

    # /etc/hosts IMMER sicherstellen – auch wenn der laufende Hostname schon
    # stimmt (sonst fehlt die 127.0.1.1-Zuordnung und 'sudo' warnt/klemmt).
    if grep -qE "^[[:space:]]*127\.0\.1\.1[[:space:]].*${new}" /etc/hosts 2>/dev/null; then
        log_skip "/etc/hosts kennt '$new' bereits."
    elif grep -qE '^[[:space:]]*127\.0\.1\.1' /etc/hosts 2>/dev/null; then
        sed -i "s/^[[:space:]]*127\.0\.1\.1.*/127.0.1.1\t${new}/" /etc/hosts
        log_ok "/etc/hosts: 127.0.1.1 -> $new"
    else
        printf '127.0.1.1\t%s\n' "$new" >> /etc/hosts
        log_ok "/etc/hosts: '127.0.1.1 $new' ergänzt"
    fi

    # Laufenden Hostnamen nur setzen, wenn er abweicht.
    if [ "$cur" != "$new" ]; then
        if command -v hostnamectl >/dev/null 2>&1; then
            hostnamectl set-hostname "$new" 2>/dev/null || hostname "$new"
        else
            hostname "$new"
        fi
        log_ok "Hostname: '$cur' -> '$new' (voll aktiv nach Reboot, u. a. \\\\${new}.local)."
    else
        log_skip "Laufender Hostname bereits '$new'."
    fi
}
