#!/usr/bin/env bash
# Testet die Kanal-Auswahl (release/main) des Selbstupdate-Moduls gegen ein
# echtes Git-Repo, ohne install.sh tatsaechlich auszufuehren (DRY_RUN=1).
set -uo pipefail

SB="$(mktemp -d /tmp/chan_sandbox.XXXXXX)"
mkdir -p "$SB"
pass=0; fail=0
chk() { if [ "$2" = "$3" ]; then echo "   OK   $1"; pass=$((pass+1));
        else echo "   FAIL $1 -> erwartet [$3], war [$2]"; fail=$((fail+1)); fi; }
hr() { printf '\n--- %s ---\n' "$*"; }

export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

# --- Upstream-Repo mit Tags bauen ---
UP="$SB/upstream"
git init -q -b main "$UP"
cd "$UP" || exit 1
echo "v1" > datei.txt; touch install.sh
git add -A; git commit -qm "1.0.0"; git tag -a v1.0.0 -m r
echo "v2" > datei.txt; git commit -qam "1.2.0"; git tag -a v1.2.0 -m r
echo "v3" > datei.txt; git commit -qam "1.10.0"; git tag -a v1.10.0 -m r
echo "wip" > datei.txt; git commit -qam "unveroeffentlicht auf main"
git log --oneline | head -1 > /dev/null

# --- Klon als "Geraet" ---
DEV="$SB/PiPortal"
git clone -q "$UP" "$DEV"
cd "$DEV" || exit 1; git checkout -q v1.0.0 --detach 2>/dev/null

# Logik aus update_piportal.sh isoliert nachstellen
latest_tag() {
    git -C "$DEV" for-each-ref --format='%(refname:short)' refs/tags \
      | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n1
}

hr "1. Hoechstes Tag korrekt (1.10.0 > 1.2.0, nicht alphabetisch)"
chk "latest_tag" "$(latest_tag)" "v1.10.0"

hr "2. Release-Kanal: von v1.0.0 auf v1.10.0"
git -C "$DEV" fetch -q --tags origin
t="$(latest_tag)"
git -C "$DEV" checkout -q --detach "$t"
chk "Inhalt" "$(cat "$DEV/datei.txt")" "v3"
chk "nicht main-Spitze" "$(cat "$DEV/datei.txt")" "v3"

hr "3. Bereits auf neuestem Release -> kein Wechsel noetig"
cur="$(git -C "$DEV" rev-parse HEAD)"
tgt="$(git -C "$DEV" rev-parse "${t}^{commit}")"
chk "HEAD == Tag" "$cur" "$tgt"

hr "4. Kanal main: von detached HEAD zurueck auf main + pull"
git -C "$DEV" checkout -q main
git -C "$DEV" pull -q --ff-only
chk "Inhalt = main-Spitze" "$(cat "$DEV/datei.txt")" "wip"
chk "auf Branch main" "$(git -C "$DEV" symbolic-ref --short HEAD)" "main"

hr "5. Repo ohne Tags -> Release-Kanal meldet nichts zu tun"
NT="$SB/notags"
git init -q -b main "$NT"; cd "$NT" || exit 1; touch install.sh; git add -A; git commit -qm x
n="$(git -C "$NT" for-each-ref --format='%(refname:short)' refs/tags | grep -cE '^v[0-9]+\.[0-9]+\.[0-9]+$' || true)"
chk "keine Tags gefunden" "$n" "0"

hr "6. Nicht-Versions-Tags werden ignoriert"
cd "$UP" || exit 1; git tag -a beta-test -m x 2>/dev/null
git -C "$DEV" fetch -q --tags origin
chk "latest bleibt v1.10.0" "$(latest_tag)" "v1.10.0"

hr "7. Dirty-Check erkennt lokale Aenderungen"
echo "lokal" >> "$DEV/datei.txt"
chk "porcelain nicht leer" "$([ -n "$(git -C "$DEV" status --porcelain)" ] && echo dirty || echo clean)" "dirty"
git -C "$DEV" checkout -q -- datei.txt
chk "nach Verwerfen sauber" "$([ -n "$(git -C "$DEV" status --porcelain)" ] && echo dirty || echo clean)" "clean"

cd / || exit 1; rm -rf "$SB" 2>/dev/null
printf '\n=== %d bestanden, %d fehlgeschlagen ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
