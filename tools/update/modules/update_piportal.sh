#!/usr/bin/env bash
# =============================================================================
#  PiPortal Update-Modul: PiPortal selbst
#  Holt neue Repo-Staende (falls das Repo ein git-Klon ist) und spielt sie ueber
#  den idempotenten Installer ein. Ohne git-Klon: sauberer Skip (nichts zu tun).
#  Erkennt Boot-relevante Aenderungen (cmdline/config.txt) und vermerkt Reboot.
# =============================================================================
set -uo pipefail
LOG_TAG="PIPORTAL"
# shellcheck source=lib_common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib_common.sh"

# Repo finden: Env-Vorgabe oder uebliche Orte mit install.sh.
find_repo() {
    local c
    for c in "${PIPORTAL_REPO:-}" /home/*/PiPortal /root/PiPortal /opt/PiPortal; do
        [ -n "$c" ] && [ -f "$c/install.sh" ] && { echo "$c"; return 0; }
    done
    return 1
}
repo="$(find_repo)" || { log_skip "Kein PiPortal-Repo mit install.sh gefunden -- uebersprungen"; exit 0; }
log "PiPortal-Repo: $repo"

boot_sig() { sudo sha256sum /boot/firmware/cmdline.txt /boot/firmware/config.txt 2>/dev/null | awk '{print $1}' | tr '\n' ' '; }
sig_before="$(boot_sig)"

# --- git-Klon? Dann aktualisieren (als Besitzer, sauber ff-only) ---
if [ -d "$repo/.git" ]; then
    owner="$(stat -c '%U' "$repo" 2>/dev/null || echo root)"
    before_commit="$(sudo -u "$owner" git -C "$repo" rev-parse --short HEAD 2>/dev/null || echo '?')"
    if run "git pull (ff-only)" sudo -u "$owner" git -C "$repo" pull --ff-only; then
        after_commit="$(sudo -u "$owner" git -C "$repo" rev-parse --short HEAD 2>/dev/null || echo '?')"
        if [ "$before_commit" = "$after_commit" ]; then
            log_skip "Repo bereits aktuell (${after_commit}) -- kein Neu-Install noetig"
            exit 0
        fi
        log_ok "Repo aktualisiert: ${before_commit} -> ${after_commit}"
    else
        log_err "git pull fehlgeschlagen -- kein Neu-Install"
        exit 1
    fi
else
    log_skip "Repo ist kein git-Klon (${repo}) -- kein Self-Update moeglich, uebersprungen"
    exit 0
fi

# --- Idempotenten Installer drueber (bringt eigenes Backup/Rollback mit) ---
if [ "$DRY_RUN" = "1" ]; then
    log "TROCKEN wuerde ausfuehren: sudo bash $repo/install.sh --all --non-interactive"
else
    if sudo bash "$repo/install.sh" --all --non-interactive; then
        log_ok "Installer idempotent durchgelaufen"
    else
        log_err "Installer meldete Fehler (rc=$?) -- siehe Installer-Log"
        exit 1
    fi
fi

# --- Boot-relevante Aenderung? ---
sig_after="$(boot_sig)"
[ "$sig_before" != "$sig_after" ] && mark_reboot_needed "PiPortal-Update aenderte cmdline/config.txt"
exit 0
