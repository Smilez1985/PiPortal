**[🇬🇧 English](ROADMAP.md)** · 🇩🇪 Deutsch

# PiPortal — Roadmap

Das Kernprojekt (1.0.0) ist abgeschlossen und an Hardware verifiziert. Die Punkte unten sind **geplante Richtungen und Ideen**, keine Zusagen und keine Termine — sie beschreiben, wohin PiPortal wachsen soll. Was bereits ausgeliefert ist, steht mit Datum im [`CHANGELOG.de.md`](../CHANGELOG.de.md).

---

## Portabler Admin- & KI-Werkzeugkasten

Die größere Vision hinter PiPortal ist eine abgeschottete, überallhin mitnehmbare Werkbank:

- **Kuratierter Admin-Werkzeugkasten** — ein definierter Satz portabler Admin-/Entwicklungswerkzeuge für die isolierte Umgebung (Dateitransfer, Disk-/Hardware-Info, Terminal-Helfer), sodass der Stick ein einsatzfertiger Kasten ist statt eines nackten OS. (Heute legt der Nutzer seine portablen Tools selbst auf den Share.)
- **Vollständigere Cowork-Integration** — eine vorkonfigurierte Cowork-/KI-Coding-Umgebung im isolierten Raum, sodass der Stick zugleich eine portable KI-Workstation ist. *(Die Claude Code CLI selbst installiert und startet bereits via `piportal start claude` — in 1.0.0 ausgeliefert; dieser Punkt ist das reichere, vorkonfigurierte Setup.)*

## Speicher

- **Automatischer Publish-Zyklus** für das Wegweiser-Image (`forced_eject` → `lun.0/file` tauschen), damit Inhaltsänderungen auf dem read-only-Datenträger sauber zum Host durchschlagen, ohne Reconnect.

## Qualität

- **shellcheck-CI** (GitHub Actions) über alle Shell-Skripte, als leichtgewichtige Absicherung gegen Regressionen.

---

*Idee oder Lust mitzumachen? Ein Issue aufmachen.*
