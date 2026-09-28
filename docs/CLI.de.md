**[🇬🇧 English](CLI.md)** · 🇩🇪 Deutsch

# PiPortal — CLI-Befehle (Spickzettel)

Nach der Installation steht auf dem PiPortal der Befehl **`piportal`** bereit —
auch vom PC aus über die USB-Verbindung nutzbar (`ssh <benutzer>@10.10.0.1`),
selbst wenn gerade kein WLAN da ist. Eine Kurzfassung dieses Spickzettels liegt
auch auf dem Wegweiser-Laufwerk (`PiPortal-Befehle.txt`), damit man sie beim
Wiederfinden nach Monaten sofort zur Hand hat.

`piportal` ohne Argument bzw. `piportal --help` zeigt die Hilfe.

---

## Befehle

| Befehl | Kurz | Was er tut |
|---|---|---|
| `piportal --status` | `ppstatus`, `-s` | Kompakter Überblick: IPs, Uptime/Load, CPU-Temp, RAM/Swap/zram, verbundener Host, Dienste. |
| `piportal --wifi-switch` | `-w` | WLAN-Profil wechseln (Menü). |
| `piportal --wifi-switch next` | | Zum nächsten konfigurierten WLAN rotieren. |
| `piportal --wifi-switch <id>` | | Gezielt zu WLAN-ID wechseln. |
| `piportal --update` | `-u` | **Nur PiPortal selbst** aktualisieren: Repo holen, dann den idempotenten Installer drüber. Kanal über `UPDATE_CHANNEL` — `release` (Default, höchstes `vX.Y.Z`-Tag) oder `main`. |
| `piportal --update-all` | `-U` | **Komplette Wartung**: System-Pakete, WLAN-Härtung, PiPortal, optionale Software. Fährt die gesamte modulare Update-Routine. |
| `piportal --poweroff` | `off` | Sauber herunterfahren (danach gefahrlos abziehen). |
| `piportal --smb-passwd` | | Netzlaufwerk-Passwort **einrichten** (noch keins gesetzt) **bzw. zurücksetzen** (schon gesetzt → löscht Share-Inhalt). Erkennt den Zustand selbst. `--smb-reset` ist ein Alias. |
| `piportal --publish` | | Wegweiser-Laufwerk neu bauen + am Host neu einlegen (ohne Abziehen). Nach Änderungen unter `/srv/piportal/signpost/`. |
| `piportal --tailscale-up` | `tsup` | Tailscale **verbinden** (Login-Server aus der Config). Hält nur bis zum nächsten Reboot. |
| `piportal --tailscale-down` | `tsdown` | Tailscale **trennen**. |
| `piportal start claude` | | Claude Code CLI starten (installiert sie automatisch, falls nötig). |
| `piportal --version` | `-V` | Installierte Version anzeigen (aus `/etc/piportal/version`). |
| `piportal --help` | `-h` | Diese Hilfe. |

**Weitere Komfort-Aliase** (ab der nächsten Anmeldung): `cls`/`clean` (Bildschirm
löschen), `pp` (= `piportal`), `cd..`/`cd...`/`..`.

---

## Tailscale-Kurzbefehl einrichten (deine eigenen Daten, nicht im Repo)

`piportal --tailscale-up` (bzw. `tsup`) ruft den langen
`tailscale up --login-server <URL>` als Einzeiler auf. Die URL steht **nicht** im
Repo, sondern in deiner **lokalen** Config `config/piportal.conf` (nach der
Installation `/etc/piportal/piportal.conf`, gitignoriert):

```bash
# eigenes Headscale:
TAILSCALE_LOGIN_SERVER="https://dein-headscale.example.org"
# oder leer lassen -> Tailscale-Cloud ('tailscale up')
TAILSCALE_LOGIN_SERVER=""
```

So funktioniert der Befehl bei **jedem** Nutzer mit **seinen eigenen** Zugangs-
daten — das Repo enthält nur die leere Vorlage, keine fremden Logins. Setzen des
Passworts/Onboarding bleibt manuell (siehe [`TAILSCALE.de.md`](TAILSCALE.de.md)).

Der PiPortal ist danach vom Handy überall unter seiner **Tailnet-IP**
(`100.64.x.x`) erreichbar: `ssh <benutzer>@100.64.x.x`.

---

## Voraussetzung / Zugang

- Auf dem PiPortal selbst: einfach `piportal …` tippen.
- Vom PC über USB: `ssh <benutzer>@10.10.0.1`, dann `piportal …`.
- Befehle, die etwas ändern (WLAN, Update, SMB, Poweroff, Tailscale), fragen bei
  Bedarf nach dem `sudo`-Passwort.
