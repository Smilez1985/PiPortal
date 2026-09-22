**[🇬🇧 English](ROADMAP.md)** · 🇩🇪 Deutsch

# PiPortal — Roadmap

Das Kernprojekt (1.0.0) ist abgeschlossen und an Hardware verifiziert. Die Punkte unten sind **geplante Richtungen und Ideen**, keine Zusagen und keine Termine. Sie beschreiben, wohin PiPortal wachsen soll; nichts davon ist bereits ausgeliefert.

---

## Portabler Admin- & KI-Werkzeugkasten

Die größere Vision hinter PiPortal ist eine abgeschottete, überallhin mitnehmbare Werkbank:

- **Kuratierter Admin-Werkzeugkasten** — ein definierter Satz an Administrations-/Entwicklungswerkzeugen in der isolierten Umgebung (Dateitransfer, Terminal und ähnliche Alltagshelfer), sodass der Stick ein einsatzfertiger Kasten ist statt eines nackten OS.
- **Cowork-/Claude-Integration** — eine KI-Coding-Umgebung (Cowork / Claude Code CLI) in den isolierten Raum ziehen, sodass der Stick zugleich eine portable KI-Workstation ist, die den Host nicht anrührt. Die Claude Code CLI ist heute schon optional installierbar (`ENABLE_CLAUDE_CODE=1`, per Default aus); geplant ist ein vollständigeres, vorkonfiguriertes Setup.

## Netzwerk

- **Optionales NCM-Profil** für reine Windows-11-Umgebungen (besserer Durchsatz als RNDIS). RNDIS bleibt der Default für maximale Reichweite über ältere Windows; NCM wäre ein opt-in Profil — siehe die Zukunftsnotiz in [`ARCHITECTURE.de.md`](ARCHITECTURE.de.md).

## Speicher

- **Automatischer Publish-Zyklus** für das Wegweiser-Image (`forced_eject` → `lun.0/file` tauschen), damit Inhaltsänderungen auf dem read-only-Datenträger sauber zum Host durchschlagen, ohne Reconnect.

## Robustheit (Zieh-Sicherheit)

- **Read-only-/Overlay-Root**, damit ein harter Stromabschnitt — den Stick einfach abziehen — das OS nicht
  beschädigen kann. Der Haken (der genau bei dieser Design-Frage auftauchte): ein naives Overlay macht
  *alles* flüchtig, also muss der **beschreibbare SMB-Share auf eine separate, vom Overlay ausgenommene
  Partition**, sonst wäre er nach jedem Reboot leer. Das ist ein größerer Umbau — daher Roadmap, nicht
  ausgeliefert. Bis dahin: `piportal --poweroff` fährt vor dem Abziehen sauber herunter.

## Qualität

- **shellcheck-CI** (GitHub Actions) über alle Shell-Skripte, als leichtgewichtige Absicherung gegen Regressionen.

---

*Idee oder Lust mitzumachen? Ein Issue aufmachen.*
