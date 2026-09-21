#!/usr/bin/env bash
# =============================================================================
#  PiPortal – Modul 50: Extras (optional)
#  - SSH-Helper aufs Share legen (Komfort).
#  - Optional: Node.js LTS + Claude Code CLI (isoliertes KI-Labor).
# =============================================================================

module_50_extras() {
    log_step "Phase 5 – Extras (optional)"

    # --- SSH-Helper zusätzlich in den Share legen (leicht auffindbar) ---
    if [ "${ENABLE_SSH_HELPER}" = "1" ] && [ -d "${SMB_SHARE_PATH}" ]; then
        install_file "${PIPORTAL_ASSETS_DIR}/windows/connect-piportal.cmd" \
                     "${SMB_SHARE_PATH}/connect-piportal.cmd" 0644
    fi

    # --- Claude Code CLI (nur wenn gewünscht) ---
    if [ "${ENABLE_CLAUDE_CODE}" = "1" ]; then
        install_claude_code
    else
        log_skip "Claude Code CLI deaktiviert (ENABLE_CLAUDE_CODE=0)."
    fi
}

install_claude_code() {
    log_info "Installiere Node.js LTS + Claude Code CLI …"

    if command -v node >/dev/null 2>&1; then
        log_skip "Node.js bereits vorhanden: $(node -v)"
    else
        # NodeSource LTS für Debian/arm64.
        ensure_pkg curl ca-certificates
        curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - >/dev/null 2>&1 \
            || { log_warn "NodeSource-Setup fehlgeschlagen – Node.js nicht installiert."; return 0; }
        ensure_pkg nodejs
    fi

    if command -v claude >/dev/null 2>&1; then
        log_skip "Claude Code CLI bereits vorhanden."
    else
        if command -v npm >/dev/null 2>&1; then
            npm install -g @anthropic-ai/claude-code >/dev/null 2>&1 \
                && log_ok "Claude Code CLI installiert." \
                || log_warn "Claude-Code-Installation fehlgeschlagen – bitte manuell prüfen."
        else
            log_warn "npm nicht verfügbar – Claude Code übersprungen."
        fi
    fi

    log_info "Hinweis: Der Zero 2 W hat 512 MB RAM. Claude Code läuft, ist aber langsam."
}
