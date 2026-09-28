**[🇬🇧 English](CHANGELOG.md)** · 🇩🇪 Deutsch

# Changelog

Alle nennenswerten Änderungen an PiPortal. Format nach [Keep a Changelog](https://keepachangelog.com/de/1.1.0/), Versionierung nach [SemVer](https://semver.org/lang/de/).

## [1.4.0] — 2026-09-29 01:40 CEST

### Behoben
- **`write_file_if_changed()` konnte die Zieldatei stillschweigend leeren.** Die Funktion schrieb
  über `mktemp`, ungeprüft. Zeigt `TMPDIR` auf ein nicht existierendes Verzeichnis – oder ist die
  RAM-Disk voll –, liefert `mktemp` einen leeren Pfad, `cat > ""` schlägt fehl, und `install`
  bekommt anschließend eine leere Quelle: die Zieldatei ist danach leer. Zu den so geschriebenen
  Dateien gehören `/etc/wpa_supplicant/wpa_supplicant.conf` und **`/boot/firmware/cmdline.txt`** –
  dort bedeutet eine leere Datei, dass der Pi nicht mehr bootet.

  Die Funktion schreibt jetzt eine Sidecar-Datei **neben das Ziel** und benennt sie per `mv` um –
  dasselbe Muster, das die SAE-Härtung für `cmdline.txt` bereits nutzte. Kein `/tmp` beteiligt,
  kein zusätzlicher Schreibzyklus, und `mv` innerhalb einer Partition ist atomar: Ein Stromausfall
  mittendrin lässt entweder die alte oder die neue Fassung zurück, nie eine abgeschnittene.

  Ein leerer Inhalt ersetzt eine nicht-leere Datei nicht mehr (fast immer ein Fehler in der
  aufrufenden Pipeline). Wer es beabsichtigt, übergibt `--allow-empty`. Besitzer und Gruppe einer
  vorhandenen Zieldatei bleiben erhalten.

- **Modul 30 prüft `cmdline.txt` jetzt vor dem Schreiben.** Beim Entfernen der Legacy-`g_multi`-
  Tokens wurde das Ergebnis ungeprüft geschrieben. Hätte die Umformung eine leere Zeile ergeben
  oder `root=` verloren, wäre das Gerät nicht mehr gebootet. Das Modul verifiziert die Zeile jetzt
  und legt vorher ein Backup an – dieselbe Absicherung, die Modul 20 für `wpa_supplicant.conf`
  schon hat.

### Geändert
- **`piportal --update` aktualisiert jetzt PiPortal selbst, nicht das Betriebssystem.**
  Der Befehl holt das Repo und lässt den idempotenten Installer darüber laufen. Die
  komplette Wartung — System-Pakete, WLAN-Härtung, PiPortal, optionale Software —
  liegt jetzt auf dem neuen **`piportal --update-all`** (`-U`). Beide fahren dieselbe
  modulare Routine in `tools/update/`; `--update` wählt daraus nur das Modul
  `piportal`. Wer eine neue PiPortal-Version will, soll nicht zwangsweise
  `apt upgrade` mitnehmen müssen.

### Hinzugefügt
- **Update-Kanäle über `UPDATE_CHANNEL`** in der `piportal.conf`:
  `release` (Default) zieht das höchste veröffentlichte Tag `vX.Y.Z` — Geräte im Feld
  bekommen nur bewusst freigegebene Stände. `main` folgt dem Entwicklungszweig. Die
  Tag-Auswahl sortiert nach Version, `v1.10.0` gewinnt also korrekt gegen `v1.2.0`.
  Der Rückweg von einem Tag auf `main` ist abgedeckt; ein verändertes
  Arbeitsverzeichnis bricht das Update ab, statt überschrieben zu werden.
- **`tests/`** – Shell-Testsuiten für `write_file_if_changed` (14 Fälle, inklusive der
  Regression mit kaputtem `TMPDIR`), das Versionsstempel-Modul und die Kanal-Logik
  (10 Fälle gegen ein echtes Git-Repo).

---

## [1.3.0] — 2026-09-29 00:45 CEST

### Hinzugefügt
- **`piportal --version` (Alias `-V`)** – zeigt die installierte Version. Einzige Wahrheitsquelle
  ist die Datei `VERSION` in der Repo-Wurzel; Modul 48 stempelt sie bei der Installation nach
  `/etc/piportal/version`, damit die CLI auch ohne Repo Auskunft geben kann. Fehlt die Datei
  (Installation älter als 1.3.0 oder von Hand kopiert), sagt der Befehl das und nennt die Abhilfe.
- **Modul 48 – Versionsstempel**, idempotent wie jede andere Phase:
  Datei fehlt → anlegen · gleiche Version → unverändert lassen · abweichende Version → aktualisieren.
  Beim Upgrade läuft `migrate_from()` – der vorgesehene Ort für Umbauten, die bestehende
  Installationen betreffen. Ein Versionssprung darf einen laufenden PiPortal **nie** brechen:
  Den Übergang regelt der Installer, nicht eine Release-Notiz „bitte neu installieren“.
  Ein Downgrade wird im Modus `--non-interactive` abgelehnt und sonst nachgefragt.

### Behoben
- **`write_file_if_changed()` konnte die Zieldatei stillschweigend leeren.** `mktemp` wurde ohne
  Prüfung des Ergebnisses aufgerufen. Zeigt `TMPDIR` auf ein nicht existierendes Verzeichnis,
  liefert es einen leeren Pfad, `cat > ""` schlägt fehl, und `install` bekam anschließend eine
  leere Quelle – die Zieldatei war danach leer. Der Aufruf weicht jetzt auf ein explizites
  Template aus und bricht ab, wenn beide Versuche scheitern.

---

## [1.2.0] — 2026-09-22 15:35 CEST

### Hinzugefügt
- **CLI-Kurzbefehl `piportal --tailscale-up` / `--tailscale-down`** (Aliase `tsup`/`tsdown`):
  löst den langen `tailscale up --login-server <URL>` als Einzeiler aus, zeigt gleich die
  Tailnet-IP + den Handy-SSH-Befehl. Die URL kommt aus `TAILSCALE_LOGIN_SERVER` in der
  **lokalen, gitignorierten** Config (im Repo nur leere Vorlage – keine fremden Logins). Die CLI
  liest die root-only Config dafür gezielt per `sudo` (Config bleibt `0640`).
- **`docs/CLI.de.md` / `docs/CLI.md`** – Spickzettel aller `piportal`-Befehle. Eine Kurzfassung
  (`PiPortal-Befehle.txt`) liegt zusätzlich auf dem Wegweiser-Laufwerk und im Share, zum schnellen
  Nachlesen, wenn man den PiPortal nach Monaten wieder benutzt.
- **Modul 55 – Tailscale-Client (Opt-in, `ENABLE_TAILSCALE=1`, Standard aus)**: installiert auf
  Wunsch **nur** den Tailscale-Client als Vorbereitung, **paketmanager-agnostisch** — DietPi über
  den Katalog (`dietpi-software 58`), Arch/Alpine nativ (`pacman`/`apk`), Debian/Ubuntu/Fedora/
  RHEL/openSUSE über das offizielle Tailscale-Install-Script (korrekter Vendor-Repo-Weg je
  `apt`/`dnf`/`yum`/`zypper`), sonst Script-Fallback. **Kein Onboarding**, **keine** Keys/URLs/Daten
  im Repo — das Anmelden (`tailscale up …`) macht der Nutzer selbst.
- **Bewusst manuell und nicht persistent**: `tailscaled` läuft (damit `tailscale up` greift), ein
  Boot-Hook (`piportal-tailscale-down.service`) lässt Tailscale nach **jedem Reboot getrennt**.
  So läuft es nur nach manuellem `tailscale up …` und ist nach dem Reboot wieder aus — verhindert
  u. a. den Subnetz-Self-Hijack, wenn der PiPortal im Heimnetz hängt.
- **`docs/TAILSCALE.de.md` / `docs/TAILSCALE.md`**: Onboarding-Anleitung mit dem klaren Hinweis,
  dass das Feature einen Tailscale-Konto **oder** einen selbst gehosteten Headscale-Server
  voraussetzt (ohne Server bleibt das Opt-in auf 0). Enthält Cloud-/Headscale-Weg, manuellen
  Reconnect, den Zugriff vom Handy über die **Tailnet-IP** (`100.64.x.x`, netzunabhängig), die
  `--accept-routes`-Warnung fürs on-LAN-Gerät (Split-Tunnel ≠ Exit-Node) und den DNS-Rebind-Stolperstein.

---

## [1.1.0] — 2026-09-22 06:41 CEST

Folgearbeiten nach der ersten Hardware-Fassung, alle live am Gerät verifiziert.

### Hinzugefügt
- **`piportal --publish`** + Publish-Helfer (`assets/gadget/piportal-publish.sh`): baut das
  Wegweiser-Image aus dem persistenten Signpost-Staging (`/srv/piportal/signpost`) neu und legt
  es am Host per `forced_eject` sauber neu ein — geänderte Inhalte erscheinen **ohne
  Aus-/Einstecken**. Modul 40 nutzt denselben Helfer (genau ein Weg, keine Doppel-Logik).
- **Zweisprachiger Wegweiser**: englische `readme.txt` neben der `LIESMICH.txt` und eine
  zweisprachige, einklappbare `README.md` (DE/EN über `<details>`) auf Wegweiser-Laufwerk und Share.
- **`docs/INSTALL.de.md` / `docs/INSTALL.md`** — ausführliche Installationsanleitung
  (Voraussetzungen, DietPi-Vorbereitung, WLAN-Modell, Abhängigkeiten, Verifikation). Der
  README-Installationsabschnitt wurde entsprechend korrigiert (WLAN-Modell klargestellt,
  USB-OTG-Kabel als Alternative zum GeeekPi-Aufsatz).

### Geändert
- **WLAN-Roaming leitet das Heimnetz aus dem OS ab**: der Roaming-Dienst bestimmt das bevorzugte
  Netz (für den aktiven Rückwechsel) jetzt **live aus der höchsten `priority` in der
  `wpa_supplicant.conf`** statt aus einem festen Config-Wert. Das OS bleibt einzige Wahrheitsquelle
  (Netze, Passwörter, Reihenfolge); in DietPi hinzugefügte/umsortierte Netze greifen ohne Zutun,
  kein Watcher, keine Überschreibung. `WIFI_HOME_SSID` in der Config bleibt optionaler Override.
- **SMB-Passwort — ein Werkzeug für beide Fälle**: `piportal --smb-passwd` erkennt den Zustand
  selbst (Passwort nicht gesetzt → Erst-Einrichtung ohne Datenverlust; bereits gesetzt →
  Zurücksetzen). Die zwei früheren VBS (`SMB-Passwort_setzen.vbs` / `SMB-Passwort_vergessen.vbs`)
  sind zu einer `SMB-Passwort.vbs` zusammengeführt; `--smb-reset` bleibt als Alias erhalten.
- **Benutzername nicht mehr hart verdrahtet**: die Wegweiser-/Windows-Dateien nutzen echte
  Variablen (`${PP_USER}` / `${PP_IP}` / `${PP_SHARE}`), die der Installer per `envsubst` aus der
  Config rendert. `SMB_USER` wird — falls in der Config leer — aus dem OS bzw. Dateipfad abgeleitet
  (`SUDO_USER` → `logname` → Repo-Eigentümer), nie root. `gettext-base` als Abhängigkeit ergänzt.

### Härtung
- **Sprachunabhängig**: `export LC_ALL=C.UTF-8` in allen parsenden Skripten (Installer, CLI,
  Roaming-/Publish-/Net-Detect-Helfer, Updater) → deterministisches Parsen auf englischem wie
  deutschem DietPi, kein Crash durch lokalisierte Werkzeug-Ausgaben.
- **CRLF für Windows-Dateien**: der Render-Schritt gibt alle Wegweiser-/Share-Dateien mit CRLF
  aus; `.gitattributes` um `*.vbs` und die Portal-Texte (`LIESMICH.txt`, `readme.txt`) ergänzt.
  Alle Shell-Skripte bleiben LF ohne BOM (verifiziert).
- **shellcheck-CI** (GitHub Actions) über alle Shell-Skripte als leichtgewichtiger
  Regressionsschutz.

---

## [1.0.0] — 2026-09-22

Erste vollständige, an Hardware verifizierte Fassung. Live an Windows 11 getestet: RNDIS-Adapter, das `PIPORTAL`-Read-only-Laufwerk, eine DHCP-Lease auf `10.10.0.x` und der gehärtete SMB-Share kommen alle hoch, während der Host sein eigenes Internet behält und SSH über `usb0` erreichbar bleibt.

### Hinzugefügt
- **PiPortal-CLI** (`/usr/local/bin/piportal`, Modul 45): `--status` (kompakter Überblick:
  IPs, Uptime/Load, CPU-Temp, RAM/Swap/zram, verbundener Host, Dienste – ohne htop),
  `--wifi-switch` (Menü / `next` / gezielte ID zum WLAN-Wechsel, z. B. Heimnetz→Hotspot,
  auch vom Host per USB-SSH steuerbar), `--update` (dietpi-update + apt upgrade + Reboot).
  Komfort-Aliase `cls`/`clean` (Bildschirm löschen), `pp`, `ppstatus`.
- **Modul 15 (Boot-Tuning)**: schreibt `AUTO_SETUP_BOOT_WAIT_FOR_NETWORK=0` fest und
  deaktiviert `systemd-networkd-wait-online` – schneller Boot, keine Hänger im WLAN-AP-/
  Hotspot-Modus. Auf frischen SD-Karten reproduzierbar.
- **UDC-Warteschleife im Gadget-Skript**: wartet beim Boot aktiv auf den USB-Controller
  (dwc2 lädt asynchron) und bindet mit Retry – macht den ersten configfs-Start nach dem
  Reboot timing-sicher.
- **g_multi-Migration in Modul 30**: archiviert das alte `/pi-usb-drive.img` nach
  `/srv/piportal/legacy/` und entfernt verwaiste `g_multi`-Einträge aus `/etc/modules`.
- **Modul 01 (Hostname)**: setzt den Hostnamen (Standard `PiPortal`) idempotent über
  `/etc/hostname`, `/etc/hosts` und `hostnamectl`. Config-Variable `PIPORTAL_HOSTNAME`.
- **README-Abschnitt „Migration von einem bestehenden g_multi-Setup"**.
- **Modul 05 (Swap & zram)**: richtet den SD-Swapfile nach SD-Kartengröße ein
  (≥64 GB→16 GB, ≥32 GB→8 GB, ≥16 GB→4 GB, sonst 2 GB) über DietPis
  `dietpi-set_swapfile`, mit Deckelung auf den freien Platz. Stellt zram
  (komprimierter RAM-Swap, ~75 % RAM) sicher und setzt `vm.swappiness`. Idempotent:
  baut den Swapfile nur bei relevanter Größenabweichung neu. Neue Config-Variablen
  `SWAP_MODE`, `SWAP_LOCATION`, `SWAP_RESERVE_MIB`, `SWAPPINESS`, `ENABLE_ZRAM`,
  `ZRAM_PERCENT`.
- **Konsolidierte Dokumentation**: [`docs/ARCHITECTURE.de.md`](docs/ARCHITECTURE.de.md) gegen den
  ausgelieferten Code geprüft (alleinige Wahrheitsquelle) und [`docs/DESIGN_NOTES.de.md`](docs/DESIGN_NOTES.de.md)
  ergänzt — das vollständige Was/Wie/Warum der Live-Inbetriebnahme samt Ursachen-Fixes. Beide zweisprachig (EN/DE).
- **OS-Installations-Sperre** (`assert_os`, erste Prüfung in `install.sh`, vor der Root-Prüfung): verweigert
  die Ausführung auf Pentest-Distributionen (Kali, Parrot, …) per `/etc/os-release`-Blacklist. Alle anderen
  Systeme sind erlaubt — keine Bindung an ein einziges OS.
- **Security- & Roadmap-Doku**: [`docs/SECURITY.de.md`](docs/SECURITY.de.md) („Security by Design"-Barrieren +
  Dual-Use-Disclaimer) und [`docs/ROADMAP.de.md`](docs/ROADMAP.de.md) (geplanter Admin-Werkzeugkasten /
  Cowork-Integration, NCM-Profil, Publish-Zyklus). Beide zweisprachig (EN/DE).
- **Update-Routine** (`tools/update/`, installiert von Modul 47): modulare, ausfallsichere Wartung
  (`system` → `harden_wlan` → `piportal`-Self-Update → `claude`, jeweils strikt „if exist"). Kein
  Auto-Update beim Boot — eine Login-Abfrage fragt, wenn ein Lauf **fällig** ist (Standard alle 14 Tage),
  und bei „jetzt" auch, ob danach automatisch neu gestartet werden soll.
- **WLAN-SAE-Härtung** (`harden_wlan` + Live-Schutz): schützt vor der `brcmfmac`-WPA3/SAE-Regression
  (`feature_disable=0x2282000` in `cmdline.txt` + modprobe.d), damit der Reboot eines OS-Updates das WLAN
  an einem WPA2/WPA3-Transition-AP nicht abwürgt.
- **Netzlaufwerk-Zugangsdaten-Werkzeuge**: `piportal --smb-passwd` (Erst-Einrichtung / Passwortwechsel, keine
  Daten weg) und `piportal --smb-reset` (voller Reset inkl. Löschen), dazu die Windows-Helfer
  `SMB-Passwort_setzen.vbs` und `SMB-Passwort_vergessen.vbs` auf dem Wegweiser-Laufwerk. Berechtigung ist der
  SSH-Login. `LIESMICH.txt` liegt jetzt auch auf dem Share (H:) und nennt die Windows-Login-Form
  (`10.10.0.1\dietpi`).
- **mDNS via avahi**, damit `\\PiPortal.local` vom Host auflöst (NetBIOS bleibt aus). Hostname wird von
  Modul 01 auf `PiPortal` gesetzt.
- **NCM als Default mit automatischem RNDIS-Fallback** (`NET_MODE=auto`): das Windows-Netzwerk-Face kommt
  als CDC-NCM hoch — das auf **Windows 11 treiberlos bindet** (live verifiziert: stille Karte + DHCP-Lease,
  kein Admin) — und fällt automatisch auf RNDIS zurück, wenn der verbundene Host NCM nicht annimmt
  (Windows 7–10). Detektor `piportal-net-detect` + `WINNCM`-os_desc; durchgängig Single-Config. RNDIS ist
  jetzt Opt-in/Fallback, nicht mehr der Default.
- **`piportal --poweroff`**: sauberes Herunterfahren (`sync` + `poweroff`), damit der Stick gefahrlos
  abgezogen werden kann, ohne SD-Karten-Korruption zu riskieren.
- **`piportal start claude`**: startet die Claude Code CLI und installiert sie beim ersten Mal (neueste, kein Pin).
- **Gadget-Default korrigiert** auf `portal.img` (war ein veraltetes `.iso`), damit der read-only-Wegweiser einen Reboot übersteht.

### Behoben
- **Windows-Host bekam keine DHCP-Adresse (landete auf APIPA 169.254.x.x):** Die
  dnsmasq-Optionen 119/121/249 wurden mit einem leeren Wert konfiguriert, um sie zu
  unterdrücken – dnsmasq sendet solche Optionen (die es NICHT von sich aus sendet) aber
  als **0-Byte-Option**, woraufhin Windows das gesamte DHCP-OFFER verwirft (DISCOVER/OFFER,
  aber nie REQUEST/ACK). Die drei Zeilen wurden entfernt (nur 3/6/15 werden unterdrückt);
  zusätzlich `dhcp-authoritative` gesetzt. Windows bekommt jetzt sauber eine 10.10.0.x-IP.
- **RNDIS-Netzwerkadapter band unter Windows nicht (Treiber-Cache):** Nach vielen
  Test-Reconnects hatte Windows die USB-Kennung `1d6b:0104` negativ gecacht und wertete
  die MS-OS-Descriptoren nicht neu aus. Product-ID auf `0xa4ac` geändert → Windows sieht
  ein frisches Gerät, lädt „Remote NDIS Compatible Device" automatisch. os_desc/compat-IDs
  waren die ganze Zeit korrekt.
- **Windows band keine Gadget-Treiber (kein RNDIS-Adapter, kein Laufwerk):** Ursache war
  ein Multi-Config-Gadget (RNDIS + ECM). Windows unterstützt mehrere USB-Konfigurationen
  schlecht und lädt dann keine Funktionstreiber. Default jetzt **Single-Config (nur RNDIS
  + Mass Storage)**, `ENABLE_ECM=0`. ECM nur für Linux/macOS-Hosts.
- **FAT-Wegweiser-Image zu klein:** 4 MB scheitern als FAT16 („too small") → 16 MB.
- **Gadget-Teardown entfernte den os_desc-Config-Link nicht** (kaputte `[ -L glob ]`-Logik).
  Beim `restart` schlug der Neuaufbau mit `ln: … Argument ungültig` fehl. Teardown räumt
  os_desc-Symlinks jetzt korrekt ab → Gadget ist re-run-/restart-sicher.
- **Portal-LUN ließ sich nicht binden (Kernel 6.18, Fehler 525):** Der RPi-Kernel 6.18
  lehnt das Binden eines ISO-Files im `cdrom=1`-Modus ab (empirisch verifiziert). Umstieg
  von CD-ROM/ISO9660 auf **read-only FAT-Image + `ro=1`** – der windows-kompatible
  Wegweiser-Stick. `ro`/`removable` werden jetzt korrekt VOR `file` gesetzt. Modul 40 baut
  das Image nun mit `mkfs.vfat` + `mtools` statt `xorriso`. Config: `PORTAL_IMAGE` → `.img`.
- **Frisch-Installation (leere SD, kein g_multi):** Modul 30 versuchte fälschlich einen
  Live-Start des Gadgets, obwohl das `dwc2`-Overlay erst nach dem Reboot greift (noch kein
  UDC vorhanden). Jetzt wird der Live-Start übersprungen und korrekt auf den Reboot
  verwiesen. `install.sh` gibt den Reboot-Hinweis nun auch im Frisch-Fall aus (nicht mehr
  nur bei aktivem g_multi).
- **Vollständige Selbstversorgung mit Abhängigkeiten:** `wpasupplicant`/`iw` werden in
  Modul 20 per `ensure_pkg` sichergestellt (wurden vorher nur vorausgesetzt).
- **Konto-Anlage:** Modul 40 legt den Unix-Benutzer an, falls `SMB_USER` nicht existiert
  (`smbpasswd -a` setzt ihn voraus) – vorher harter Fehler bei abweichendem Benutzernamen.

## [0.1.0] — 2026-08-03

Erste strukturierte Fassung. Überführt den manuell (via Google-Search-KI) erarbeiteten Erstaufbau in ein reproduzierbares, idempotentes Repo.

### Hinzugefügt
- **One-Click-Installer** (`install.sh`) mit interaktivem Menü, `--only`/`--all`/`--non-interactive`-Flags.
- **Modulare Phasen** (`modules/00_backup` … `50_extras`), jede idempotent (`if not exist`).
- **lib/common.sh** — gemeinsame Helfer: farbiges Logging, Idempotenz-Funktionen, Backup-Routine, Config-Loader.
- **configfs/libcomposite-Gadget** (`assets/gadget/piportal-gadget.sh`) als Ersatz für Legacy-`g_multi`: RNDIS (mit MS-OS-Descriptors) + CDC-ECM + Mass Storage (CD-ROM, read-only). Deterministische MAC-Adressen aus `machine-id`. Sauberer Teardown → re-run-sicher.
- **systemd-Units** für Gadget und WLAN-Roaming (ersetzen das fragile `custom.sh` im DietPi-Autostart).
- **dnsmasq-Korrektur**: unterdrückt Gateway (Option 3) und DNS (Option 6), `bind-dynamic`, `port=0` — der Windows-Host behält sein Internet.
- **SMB-Portal** (`modules/40_portal_smb.sh`): Samba gehärtet (SMB2+/SMB3, kein Gast, ein User, nur `usb0`) + CD-ROM-Wegweiser-Image mit `LIESMICH.txt` und `.url`-Verknüpfung.
- **Windows-Helper** `connect-piportal.cmd` (nutzt Windows-eigenes `ssh.exe`, kein PuTTY nötig).
- **uninstall.sh** — Rollback aus dem jüngsten automatischen Backup.
- **Dokumentation**: Ist-Zustand-Recon, korrigierter Fahrplan, Best-Practice-Analyse (E1–E3) mit Quellen, Gerätefotos.

### Geändert (gegenüber dem manuellen Erstaufbau)
- Gadget von Legacy-`g_multi` auf **configfs/libcomposite** umgestellt.
- WLAN-Roaming von Endlosschleife im Autostart auf **systemd-Service** mit Restart-Policy.
- Wegweiser-Speicher von beschreibbarem 50-MB-FAT auf **read-only CD-ROM (ISO9660)** — beseitigt das Datenkorruptions-Risiko.
- Alle Secrets (SSIDs, PSKs) aus Skripten in die gitignorierte `config/piportal.conf` ausgelagert.

### Sicherheit
- Secret-Scan-Gate vor jedem Repo-Commit vorgesehen; `.gitignore` schützt lokale Konfiguration und Backups.
