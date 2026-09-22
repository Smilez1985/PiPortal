# =============================================================================
#  PiPortal – Wartungs-Abfrage beim Login (nach /etc/profile.d/ installiert)
#
#  Gedacht fuer ein Geraet, das nur alle paar Monate laeuft: KEIN Auto-Update
#  beim Boot. Stattdessen wird beim interaktiven Login gefragt, ob ein faelliger
#  Wartungslauf jetzt laufen soll. Nach einem Lauf gilt eine Pause
#  (Standard 14 Tage), bevor wieder gefragt wird.
#
#  WICHTIG: Diese Datei wird von der Login-Shell GESOURCT – niemals 'exit'
#  verwenden, das wuerde die Sitzung beenden. Nur if-Bloecke.
#  Deaktivieren: Datei entfernen  (sudo rm /etc/profile.d/piportal-update.sh)
# =============================================================================
if [ -n "${PS1:-}" ] && [ -t 0 ] && [ -t 1 ]; then
  _pp_orch="/usr/local/lib/piportal/update/update_orchestrator.sh"
  _pp_state="/var/lib/piportal/update-last-run"
  _pp_interval=14
  if [ -x "$_pp_orch" ]; then
    _pp_due=1
    if [ -f "$_pp_state" ]; then
      _pp_last="$(cat "$_pp_state" 2>/dev/null || echo 0)"
      _pp_now="$(date +%s)"
      [ $(( (_pp_now - _pp_last) / 86400 )) -ge "$_pp_interval" ] || _pp_due=0
    fi
    if [ "$_pp_due" = "1" ]; then
      printf '\nPiPortal: Ein Wartungslauf (System-/App-Updates) ist faellig.\n'
      printf 'Jetzt ausfuehren? [j = jetzt / N = beim naechsten Login] '
      read -r _pp_ans
      case "$_pp_ans" in
        [jJyY]|[jJ][aA])
          printf 'Falls danach ein Neustart noetig ist - automatisch durchfuehren? [j/N] '
          read -r _pp_rb
          case "$_pp_rb" in [jJyY]|[jJ][aA]) _pp_mode=auto ;; *) _pp_mode=manual ;; esac
          sudo UPDATE_REBOOT_MODE="$_pp_mode" "$_pp_orch" ;;
        *) printf 'Ok - Frage kommt beim naechsten Login wieder.\n' ;;
      esac
      unset _pp_ans _pp_rb _pp_mode
    fi
    unset _pp_due _pp_last _pp_now
  fi
  unset _pp_orch _pp_state _pp_interval
fi
