#!/usr/bin/env bash
# =============================================================================
#  PiPortal Update-Modul: Claude Code CLI (optionaler Werkzeugkasten-Teil)
#  Strikt "if exist": ist Claude NICHT installiert (Opt-in im Installer), skippt
#  das Modul kommentarlos. Ist es da, wird es auf die NEUESTE Version gebracht
#  (kein Pin). npm -g braucht root.
# =============================================================================
set -uo pipefail
LOG_TAG="CLAUDE"
# shellcheck source=lib_common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib_common.sh"

if ! command -v claude >/dev/null 2>&1; then
    log_skip "Claude Code CLI nicht installiert (Opt-in im Installer) -- uebersprungen"
    exit 0
fi

if ! command -v npm >/dev/null 2>&1; then
    log_warn "claude vorhanden, aber npm fehlt -- kann nicht aktualisieren"
    exit 1
fi

ver_before="$(claude --version 2>/dev/null | head -n1 || echo '?')"
log "Aktualisiere Claude Code CLI (aktuell: ${ver_before})"
if run "npm i -g @anthropic-ai/claude-code@latest" sudo npm install -g @anthropic-ai/claude-code@latest; then
    ver_after="$(claude --version 2>/dev/null | head -n1 || echo '?')"
    if [ "$ver_before" = "$ver_after" ]; then
        log_ok "Claude Code CLI bereits aktuell (${ver_after})"
    else
        log_ok "Claude Code CLI aktualisiert: ${ver_before} -> ${ver_after}"
    fi
else
    log_err "Claude-Code-Update fehlgeschlagen"
    exit 1
fi
exit 0
