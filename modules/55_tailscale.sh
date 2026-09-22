#!/usr/bin/env bash
# =============================================================================
#  PiPortal – Modul 55: Tailscale-Client (optional, Opt-in)
#
#  Installiert AUSSCHLIESSLICH den Tailscale-Client als Vorbereitung. Es findet
#  KEIN Onboarding statt, und es liegen KEINE Keys/URLs/Daten im Repo. Das
#  Verbinden mit einem Tailnet macht der Nutzer selbst (siehe
#  docs/TAILSCALE.de.md):
#
#     Tailscale-Cloud:   sudo tailscale up
#     Eigenes Headscale: sudo tailscale up --login-server <URL> --authkey <KEY>
#
#  Voraussetzung fuer das Feature ist ein Tailscale-Konto ODER ein selbst
#  gehosteter Headscale-Server. Wer keinen hat, laesst ENABLE_TAILSCALE=0.
#
#  Paketmanager-agnostisch: DietPi-Katalog auf DietPi; nativ dort, wo die Distro
#  Tailscale selbst paketiert (pacman/apk); sonst das offizielle Tailscale-
#  Install-Script, das den korrekten Vendor-Repo-Weg je Distro/Paketmanager geht
#  (apt/dnf/yum/zypper) – robuster als handgepflegte Repo-Dateien.
# =============================================================================

module_55_tailscale() {
    log_step "Phase 5b – Tailscale-Client (optional, Opt-in)"

    if [ "${ENABLE_TAILSCALE:-0}" != "1" ]; then
        log_skip "Tailscale deaktiviert (ENABLE_TAILSCALE=0). Feature braucht einen Tailscale-/Headscale-Server."
        return 0
    fi

    if command -v tailscale >/dev/null 2>&1; then
        log_skip "Tailscale bereits installiert: $(tailscale version 2>/dev/null | head -1)"
    else
        if ! install_tailscale_client; then
            log_warn "Tailscale-Installation fehlgeschlagen – uebersprungen (Client kann spaeter manuell nachinstalliert werden)."
            return 0
        fi
    fi

    # Daemon aktivieren (systemd), damit 'tailscale up' greift.
    # KEIN 'tailscale up' – das Onboarding macht der Nutzer selbst.
    if command -v systemctl >/dev/null 2>&1; then
        systemctl enable --now tailscaled >/dev/null 2>&1 \
            && log_ok "tailscaled aktiviert (Daemon laeuft; verbindet aber NICHT von selbst)." \
            || log_warn "Konnte tailscaled nicht aktivieren – bitte pruefen."

        # Boot-Hook: Tailscale nach JEDEM Boot getrennt lassen – bewusst NICHT
        # persistent. So laeuft es nur nach manuellem 'tailscale up' und ist nach
        # dem Reboot wieder aus. Verhindert u. a. den Subnetz-Self-Hijack im Heimnetz.
        install_file "${PIPORTAL_ASSETS_DIR}/systemd/piportal-tailscale-down.service" \
                     /etc/systemd/system/piportal-tailscale-down.service 0644
        systemctl daemon-reload >/dev/null 2>&1 || true
        systemctl enable piportal-tailscale-down.service >/dev/null 2>&1 \
            && log_ok "Boot-Hook aktiv: nach dem Reboot getrennt, Reaktivierung nur manuell." \
            || log_warn "Konnte den Tailscale-Boot-Hook nicht aktivieren."
    fi

    tailscale_onboarding_hint
}

# Installiert den Tailscale-Client passend zum erkannten System.
# Rueckgabe: 0 = installiert, 1 = fehlgeschlagen.
install_tailscale_client() {
    # 1) DietPi: ueber den Katalog, damit es in der DietPi-Paketverwaltung bleibt.
    if [ -x /boot/dietpi/dietpi-software ]; then
        log_info "DietPi erkannt – installiere Tailscale ueber den Katalog (dietpi-software 58)."
        # dietpi-software braucht ein TTY; 'script' stellt eins bereit (sonst
        # 'Unknown terminal: unknown' bzw. wortloser Abbruch ueber SSH).
        env TERM=xterm script -qec "/boot/dietpi/dietpi-software install 58" /dev/null >/dev/null 2>&1 || true
        if command -v tailscale >/dev/null 2>&1; then
            log_ok "Tailscale via DietPi-Katalog installiert."
            return 0
        fi
        log_warn "DietPi-Katalog-Weg lieferte keinen Client – versuche Paketmanager/offizielles Script."
    fi

    # 2) Paketmanager erkennen (Reihenfolge = Prioritaet der gaengigen Distros).
    local pm="" c
    for c in apt-get dnf yum zypper pacman apk; do
        command -v "$c" >/dev/null 2>&1 && { pm="$c"; break; }
    done
    log_info "Paketmanager: ${pm:-<keiner erkannt>}"

    case "$pm" in
        pacman)
            # Arch/Manjaro: Tailscale liegt im offiziellen Repo.
            pacman -Sy --noconfirm --needed tailscale && return 0
            ;;
        apk)
            # Alpine: Tailscale liegt im community-Repo.
            apk add --no-progress tailscale && return 0
            ;;
        apt-get|dnf|yum|zypper)
            # Diese brauchen das Tailscale-Vendor-Repo (GPG + Quelle, distro-/
            # codename-spezifisch). Das offizielle Script geht genau diesen Weg
            # korrekt fuer die jeweilige Distro und deren Paketmanager.
            log_info "Repo-basierte Distro (${pm}) – nutze das offizielle Tailscale-Install-Script."
            _tailscale_install_sh && return 0
            ;;
        *)
            # 3) Fallback: offizielles Script (erkennt selbst apt/dnf/yum/pacman/zypper/apk).
            log_info "Kein bekannter Paketmanager – Fallback auf das offizielle Tailscale-Install-Script."
            _tailscale_install_sh && return 0
            ;;
    esac
    return 1
}

# Laedt und startet das offizielle Tailscale-Install-Script (curl oder wget).
_tailscale_install_sh() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL https://tailscale.com/install.sh | sh
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- https://tailscale.com/install.sh | sh
    else
        log_warn "Weder curl noch wget vorhanden – kann das Install-Script nicht laden."
        return 1
    fi
}

tailscale_onboarding_hint() {
    log_info "Tailscale-Client bereit – OPT-IN, MANUELL und NICHT persistent (nach Reboot wieder aus)."
    log_info "Das ONBOARDING machst du selbst (keine Keys im Repo):"
    log_info "   Erstes Mal (eigenes Headscale): sudo tailscale up --login-server <DEINE-URL> --authkey <DEIN-KEY>"
    log_info "   Erstes Mal (Tailscale-Cloud):   sudo tailscale up"
    log_info "   Spaeter neu verbinden (ohne Key, Login bleibt): sudo tailscale up --login-server <DEINE-URL>"
    log_info "   Trennen: sudo tailscale down   |   Status: tailscale status / tailscale ip -4"
    log_info "   Vom Handy erreichst du den PiPortal ueberall unter seiner Tailnet-IP (100.64.x.x)."
    log_info "   Haelt nur bis zum naechsten Reboot. Anleitung: docs/TAILSCALE.de.md (EN: docs/TAILSCALE.md)"
}
