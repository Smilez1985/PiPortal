🇬🇧 English · 🇩🇪 Deutsch

# PiPortal Update-Routine

Eine modulare, ausfallsichere Wartungsroutine für PiPortal — abgeleitet aus einer
bewährten PiHole-Updateroutine und auf PiPortal zugeschnitten.

## Prinzipien

- **Ein Modulfehler bricht nichts ab.** Der Orchestrator protokolliert, zählt und
  läuft weiter. Der Exit-Code ist die Anzahl der gescheiterten Module (0 = sauber).
- **Kein Backup, kein Eingriff.** Bevor eine Datei angefasst wird, muss ein
  verifiziertes Backup vorliegen.
- **Strikt „if exist".** Jedes Software-Modul prüft, ob seine Software installiert
  ist, und **skippt sonst kommentarlos** (z. B. `claude` nur, wenn vorhanden).
- **Reines ASCII-Log**, `apt-cache policy`-Gates (hold-sicher), `DRY_RUN`.

## Module

| Modul | Datei | Tut |
|---|---|---|
| `system` | `modules/update_system.sh` | `apt update` → `dietpi-update` → `apt upgrade` → `autoremove` |
| `harden_wlan` | `modules/harden_wlan.sh` | SAE/brcmfmac-Härtung (`feature_disable=0x2282000`) vor jedem Reboot |
| `piportal` | `modules/update_piportal.sh` | `git pull` (falls Klon) + idempotenter Installer drüber |
| `claude` | `modules/update_claude.sh` | Claude Code CLI auf neueste Version — nur wenn installiert |

## Benutzung

```bash
# Trockenlauf – ändert nichts, zeigt nur, was es täte
DRY_RUN=1 ./update_orchestrator.sh

# Scharf (root nötig)
sudo ./update_orchestrator.sh

# Nur bestimmte Module
sudo MODULES="system harden_wlan" ./update_orchestrator.sh
```

## Reboot-Politik

Gesteuert über `UPDATE_REBOOT_MODE` (aus `/etc/piportal/piportal.conf` oder Env):

- `ask` (Default) — im Terminal nachfragen; **ohne** Terminal (Boot/Cron) nur warnen, nie automatisch neu starten.
- `auto` — am Ende automatisch `sync && reboot`.
- `manual` — nie automatisch, nur eine Warnung hinterlegen.

Ist ein Reboot nötig, hinterlässt die Routine eine MOTD-Warnung (`/run/motd.d/`)
und ein Flag (`/run/piportal-reboot-required`).

## Rhythmus: Abfrage beim Login, nicht beim Boot

Für ein Gerät, das nur alle paar Monate läuft, wäre ein Auto-Update bei jedem
Boot zu viel. Stattdessen fragt ein Login-Hook (`/etc/profile.d/piportal-update.sh`)
beim **interaktiven Login**, ob ein **fälliger** Wartungslauf jetzt laufen soll
(*jetzt* / *beim nächsten Mal*). Nach einem Lauf gilt eine **Pause** von
standardmäßig **14 Tagen** (`UPDATE_INTERVAL_DAYS`), bevor wieder gefragt wird —
der Zeitstempel steht in `/var/lib/piportal/update-last-run`.

Ein Reboot passiert nur, wenn nötig, und dann gemäß `UPDATE_REBOOT_MODE`
(`ask`/`auto`/`manual`). Deaktivieren der Abfrage: den Login-Hook entfernen.
