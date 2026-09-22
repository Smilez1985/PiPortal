**[🇬🇧 English](ROADMAP.md)** · 🇩🇪 Deutsch

# PiPortal — Roadmap

*Stand: 2026-09-22 06:41 CEST*

Das Kernprojekt ist abgeschlossen und an Hardware verifiziert. Die Punkte unten sind **geplante Richtungen und Ideen**, keine Zusagen und keine Termine — sie beschreiben, wohin PiPortal wachsen soll. Was bereits ausgeliefert ist, steht mit Datum im [`CHANGELOG.de.md`](../CHANGELOG.de.md).

---

## Portabler Admin- & KI-Werkzeugkasten

Die größere Vision hinter PiPortal ist eine abgeschottete, überallhin mitnehmbare Werkbank:

- **Kuratierter Admin-Werkzeugkasten** *(notiert 2026-09-22)* — ein definierter Satz portabler Admin-/Entwicklungswerkzeuge für die isolierte Umgebung (Dateitransfer, Disk-/Hardware-Info, Terminal-Helfer), sodass der Stick ein einsatzfertiger Kasten ist statt eines nackten OS. (Heute legt der Nutzer seine portablen Tools selbst auf den Share.)
- **Vollständigere Cowork-Integration** *(notiert 2026-09-22)* — eine vorkonfigurierte Cowork-/KI-Coding-Umgebung im isolierten Raum, sodass der Stick zugleich eine portable KI-Workstation ist. *(Die Claude Code CLI selbst installiert und startet bereits via `piportal start claude`; dieser Punkt ist das reichere, vorkonfigurierte Setup.)*

## Netzwerk / WLAN

- **Config-getriebenes WLAN: additiv statt ersetzend, beliebig viele Netze** *(notiert 2026-09-22)* — heute nutzt der Standardpfad (WLAN-Felder in `config/piportal.conf` leer) bereits **alle** in DietPi hinterlegten Netze, übernimmt deren Reihenfolge (`priority=`) und ist über `dietpi-config` erweiterbar; der Heim-Vorzug für den aktiven Rückwechsel wird live aus der höchsten OS-`priority` abgeleitet (in [1.1.0] ausgeliefert). Offen ist nur noch die **optionale** config-getriebene Variante: sie schreibt heute genau zwei Profile (Heim + Hotspot) und **ersetzt** die vorhandene `wpa_supplicant.conf`. Geplant: sie additiv machen (vorhandene DietPi-Netze nie überschreiben) und beliebig viele Profile aus der Config unterstützen.

---

*Idee oder Lust mitzumachen? Ein Issue aufmachen.*
