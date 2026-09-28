#!/usr/bin/env bash
# Testet write_file_if_changed nach dem Umbau auf atomares Schreiben.
set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO" || exit 1
# shellcheck disable=SC1091
. lib/common.sh

T=/tmp/wfc_sandbox
rm -rf "$T"; mkdir -p "$T"
pass=0; fail=0
chk() { if [ "$2" = "$3" ]; then echo "   OK   $1"; pass=$((pass+1));
        else echo "   FAIL $1 -> erwartet [$3], war [$2]"; fail=$((fail+1)); fi; }

hr() { printf '\n--- %s ---\n' "$*"; }

hr "1. Neue Datei anlegen"
printf 'hallo\n' | write_file_if_changed "$T/a.txt" 0644 >/dev/null
chk "Inhalt" "$(cat "$T/a.txt")" "hallo"
chk "Rechte" "$(stat -c %a "$T/a.txt")" "644"

hr "2. Gleicher Inhalt -> unveraendert (keine Schreiboperation)"
before=$(stat -c %Y "$T/a.txt"); sleep 1
out=$(printf 'hallo\n' | write_file_if_changed "$T/a.txt" 0644)
after=$(stat -c %Y "$T/a.txt")
chk "mtime unveraendert" "$before" "$after"
case "$out" in *"Unver"*) echo "   OK   log_skip gemeldet"; pass=$((pass+1));;
                       *) echo "   FAIL kein skip"; fail=$((fail+1));; esac

hr "3. Neuer Inhalt -> ersetzt"
printf 'welt\n' | write_file_if_changed "$T/a.txt" 0644 >/dev/null
chk "Inhalt" "$(cat "$T/a.txt")" "welt"

hr "4. Keine Sidecar-Reste"
chk "Sidecar weg" "$(find "$T" -name '*.piportal-tmp.*' | wc -l)" "0"

hr "5. Leerer Inhalt darf nicht-leere Datei NICHT ersetzen"
( printf '' | write_file_if_changed "$T/a.txt" 0644 ) >/dev/null 2>&1
rc=$?
chk "Exit-Code 1 (die)" "$rc" "1"
chk "Datei erhalten" "$(cat "$T/a.txt")" "welt"
chk "Sidecar weg" "$(find "$T" -name '*.piportal-tmp.*' | wc -l)" "0"

hr "6. --allow-empty leert bewusst"
printf '' | write_file_if_changed "$T/a.txt" 0644 --allow-empty >/dev/null
chk "Datei leer" "$(wc -c < "$T/a.txt")" "0"

hr "7. TMPDIR kaputt -> funktioniert trotzdem (der eigentliche Bug)"
printf 'robust\n' > "$T/b.txt"
TMPDIR=/gibt/es/nicht bash -c '
  cd "$REPO"; . lib/common.sh
  printf "neu\n" | write_file_if_changed "'"$T"'/b.txt" 0644 >/dev/null
'
chk "Inhalt geschrieben" "$(cat "$T/b.txt")" "neu"

hr "8. Rechte 0600 werden gesetzt"
printf 'geheim\n' | write_file_if_changed "$T/c.txt" 0600 >/dev/null
chk "Rechte" "$(stat -c %a "$T/c.txt")" "600"

hr "9. Verzeichnis wird angelegt"
printf 'tief\n' | write_file_if_changed "$T/x/y/z.txt" 0644 >/dev/null
chk "Inhalt" "$(cat "$T/x/y/z.txt")" "tief"

hr "10. Kein Zielpfad -> die"
( printf 'x\n' | write_file_if_changed "" 0644 ) >/dev/null 2>&1
chk "Exit-Code 1" "$?" "1"

rm -rf "$T"
printf '\n=== %d bestanden, %d fehlgeschlagen ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
