#!/usr/bin/env bash
# Testet Modul 48 (Versionsstempel) in einer Sandbox ohne echtes /etc.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

ROOT=/tmp/pp_fake
rm -rf "$ROOT"; mkdir -p "$ROOT/etc/piportal"

# common.sh laden, dann Zielpfade auf die Sandbox umbiegen
# shellcheck disable=SC1091
. lib/common.sh
PIPORTAL_ETC="$ROOT/etc/piportal"
PIPORTAL_INSTALLED_VERSION_FILE="${PIPORTAL_ETC}/version"
# shellcheck disable=SC1091
. modules/48_version.sh

hr() { printf '\n--- %s ---\n' "$*"; }

hr "1. Erstinstallation (Datei fehlt -> anlegen)"
rm -f "$PIPORTAL_INSTALLED_VERSION_FILE"
module_48_version
echo "   Inhalt: $(cat "$PIPORTAL_INSTALLED_VERSION_FILE" 2>/dev/null)"

hr "2. Wiederholter Lauf (gleiche Version -> unveraendert)"
module_48_version

hr "3. Upgrade (installiert 1.0.0 -> Repo 1.2.0, Migration laeuft)"
echo "1.0.0" > "$PIPORTAL_INSTALLED_VERSION_FILE"
module_48_version
echo "   Inhalt: $(cat "$PIPORTAL_INSTALLED_VERSION_FILE")"

hr "4. Downgrade nicht-interaktiv (installiert 9.9.9 -> darf NICHT zurueckstufen)"
echo "9.9.9" > "$PIPORTAL_INSTALLED_VERSION_FILE"
PIPORTAL_NONINTERACTIVE=1 module_48_version
echo "   Inhalt: $(cat "$PIPORTAL_INSTALLED_VERSION_FILE")  (erwartet: 9.9.9)"

hr "5. Versionsvergleich"
for pair in "1.0.0 1.2.0" "1.2.0 1.2.0" "1.10.0 1.9.0" "1.2.0 1.2.1"; do
    set -- $pair
    if ver_lt "$1" "$2"; then r="<"; elif [ "$1" = "$2" ]; then r="="; else r=">"; fi
    echo "   $1 $r $2"
done

hr "6. VERSION fehlt -> sauber uebersprungen"
mv VERSION VERSION.bak
PIPORTAL_VERSION_FILE="/tmp/pp/VERSION" module_48_version
mv VERSION.bak VERSION

rm -rf "$ROOT"
printf '\n=== Tests durchgelaufen ===\n'
