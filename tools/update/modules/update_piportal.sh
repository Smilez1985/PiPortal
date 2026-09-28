#!/usr/bin/env bash
# =============================================================================
#  PiPortal Update-Modul: PiPortal selbst
#
#  Holt neue Repo-Staende (falls das Repo ein git-Klon ist) und spielt sie ueber
#  den idempotenten Installer ein. Ohne git-Klon: sauberer Skip (nichts zu tun).
#  Erkennt Boot-relevante Aenderungen (cmdline/config.txt) und vermerkt Reboot.
#
#  Kanal (UPDATE_CHANNEL aus /etc/piportal/piportal.conf oder Env):
#    release  (Default) hoechstes veroeffentlichtes Tag vX.Y.Z – nur freigegebene
#             Staende. Das Repo steht danach auf einem Tag (detached HEAD), was
#             fuer ein Geraet im Feld genau richtig ist.
#    main     Spitze des Entwicklungszweigs (ff-only) – fuer Geraete, auf denen
#             entwickelt wird.
# =============================================================================
set -uo pipefail
LOG_TAG="PIPORTAL"
# shellcheck source=lib_common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib_common.sh"

# Kanal bestimmen: Env hat Vorrang vor der Config, Default ist "release".
PIPORTAL_CONF="${PIPORTAL_CONF:-/etc/piportal/piportal.conf}"
_ENV_CHANNEL="${UPDATE_CHANNEL:-}"
if [ -r "$PIPORTAL_CONF" ]; then
    # shellcheck disable=SC1090
    . "$PIPORTAL_CONF" 2>/dev/null || true
fi
[ -n "$_ENV_CHANNEL" ] && UPDATE_CHANNEL="$_ENV_CHANNEL"
case "${UPDATE_CHANNEL:-release}" in
    release|main) ;;
    *) log_err "Unbekannter UPDATE_CHANNEL '${UPDATE_CHANNEL}' – nutze 'release'"
       UPDATE_CHANNEL="release" ;;
esac

# Repo finden: Env-Vorgabe oder uebliche Orte mit install.sh.
find_repo() {
    local c
    for c in "${PIPORTAL_REPO:-}" /home/*/PiPortal /root/PiPortal /opt/PiPortal; do
        [ -n "$c" ] && [ -f "$c/install.sh" ] && { echo "$c"; return 0; }
    done
    return 1
}
repo="$(find_repo)" || { log_skip "Kein PiPortal-Repo mit install.sh gefunden -- uebersprungen"; exit 0; }
log "PiPortal-Repo: $repo (Kanal: ${UPDATE_CHANNEL})"

boot_sig() { sudo sha256sum /boot/firmware/cmdline.txt /boot/firmware/config.txt 2>/dev/null | awk '{print $1}' | tr '\n' ' '; }
sig_before="$(boot_sig)"

if [ ! -d "$repo/.git" ]; then
    log_skip "Repo ist kein git-Klon (${repo}) -- kein Self-Update moeglich, uebersprungen"
    exit 0
fi

owner="$(stat -c '%U' "$repo" 2>/dev/null || echo root)"
git_as() { sudo -u "$owner" git -C "$repo" "$@"; }

before_ref="$(git_as describe --tags --always --dirty 2>/dev/null || echo '?')"

# Lokale Aenderungen wuerden bei jedem Wechsel verloren gehen oder blockieren.
if [ -n "$(git_as status --porcelain 2>/dev/null)" ]; then
    log_err "Arbeitsverzeichnis hat lokale Aenderungen -- kein Self-Update (bitte committen oder verwerfen)"
    exit 1
fi

# ---------------------------------------------------------------- release ----
if [ "$UPDATE_CHANNEL" = "release" ]; then
    if ! run "git fetch --tags" git_as fetch --tags --prune origin; then
        log_err "git fetch fehlgeschlagen -- kein Neu-Install"
        exit 1
    fi

    # Hoechstes Tag nach Versionssortierung. refs/tags statt `git tag`, damit
    # nur echte Tags zaehlen; -V sortiert 1.10.0 korrekt nach 1.9.0.
    latest_tag="$(git_as for-each-ref --format='%(refname:short)' refs/tags \
                    | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n1)"

    if [ -z "$latest_tag" ]; then
        log_skip "Kein veroeffentlichtes Release gefunden (keine vX.Y.Z-Tags) -- uebersprungen"
        log "Hinweis: UPDATE_CHANNEL=main setzen, um vom Entwicklungszweig zu ziehen."
        exit 0
    fi

    current="$(git_as rev-parse HEAD)"
    target="$(git_as rev-parse "${latest_tag}^{commit}")"
    if [ "$current" = "$target" ]; then
        log_skip "Bereits auf dem neuesten Release (${latest_tag}) -- kein Neu-Install noetig"
        exit 0
    fi

    if ! run "checkout ${latest_tag}" git_as checkout --quiet --detach "$latest_tag"; then
        log_err "checkout ${latest_tag} fehlgeschlagen -- kein Neu-Install"
        exit 1
    fi
    log_ok "Release eingespielt: ${before_ref} -> ${latest_tag}"

# ------------------------------------------------------------------- main ----
else
    # Auf einem Tag (detached HEAD) laesst sich nicht pullen -- erst zurueck auf main.
    if ! git_as symbolic-ref -q HEAD >/dev/null 2>&1; then
        log "HEAD ist abgeloest (Release-Kanal) -- wechsle auf main"
        if ! run "checkout main" git_as checkout --quiet main; then
            log_err "checkout main fehlgeschlagen -- kein Neu-Install"
            exit 1
        fi
    fi

    if ! run "git pull (ff-only)" git_as pull --ff-only; then
        log_err "git pull fehlgeschlagen -- kein Neu-Install"
        exit 1
    fi
    after_ref="$(git_as describe --tags --always 2>/dev/null || echo '?')"
    if [ "$before_ref" = "$after_ref" ]; then
        log_skip "Repo bereits aktuell (${after_ref}) -- kein Neu-Install noetig"
        exit 0
    fi
    log_ok "Repo aktualisiert: ${before_ref} -> ${after_ref}"
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
