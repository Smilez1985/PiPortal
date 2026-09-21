**[🇬🇧 English](CHANGELOG.md)** · 🇩🇪 Deutsch

# Changelog

Alle nennenswerten Änderungen an PiPortal. Format nach [Keep a Changelog](https://keepachangelog.com/de/1.1.0/), Versionierung nach [SemVer](https://semver.org/lang/de/).

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
