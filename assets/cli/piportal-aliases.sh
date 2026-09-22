# shellcheck shell=bash
# =============================================================================
#  PiPortal – Shell-Komfort-Aliase  (nach /etc/profile.d/)
#  Wird bei jeder interaktiven Login-Shell geladen.
# =============================================================================

# Bildschirm löschen – vertraute Kürzel (u. a. Windows-Muskelgedächtnis 'cls').
alias cls='clear'
alias clean='clear'

# Windows-Muskelgedächtnis: 'cd..' / 'cd...' ohne Leerzeichen.
alias cd..='cd ..'
alias cd...='cd ../..'
alias ..='cd ..'

# Schnellzugriff auf die PiPortal-CLI.
alias pp='piportal'
alias ppstatus='piportal --status'

# Tailscale schnell verbinden/trennen (nutzt TAILSCALE_LOGIN_SERVER aus der Config).
alias tsup='piportal --tailscale-up'
alias tsdown='piportal --tailscale-down'
