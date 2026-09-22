**[🇬🇧 English](ARCHITECTURE.md)** · 🇩🇪 Deutsch

# PiPortal — Architektur-Entscheidungen

Dieses Dokument erklärt die drei zentralen Architektur-Entscheidungen hinter PiPortal, einem Raspberry Pi Zero 2 W, der sich einem Host-PC gegenüber als Composite-USB-Gadget (Netzwerk + Speicher) präsentiert. Jede Entscheidung steht mit kurzer Begründung und Links zu den belegenden Quellen.

**Der Code ist die alleinige Wahrheitsquelle (SSOT).** Wo der ursprüngliche Plan und die tatsächlich ausgelieferte Umsetzung während der Live-Inbetriebnahme an echter Hardware auseinanderliefen, beschreibt dieses Dokument, was der Code wirklich tut; die Begründung jeder Änderung steht in [`DESIGN_NOTES.de.md`](DESIGN_NOTES.de.md).

Das USB-seitige LAN nutzt den festen Adressbereich `10.10.0.x` (der Pi ist `10.10.0.1` auf `usb0`). Das ist bewusst so gewählt und öffentlich.

---

## Entscheidung 1 — Gadget-Technik: configfs / libcomposite (statt Legacy `g_multi`)

**Entscheidung: Gadget-Aufbau mit configfs/libcomposite statt des Legacy-Kernelmoduls `g_multi`.**

Begründung:
- Für **Ethernet + Massenspeicher gleichzeitig** ist configfs der vorgesehene, moderne Weg. `g_multi` ist Legacy und taucht in aktuellen Anleitungen (2024–2026) praktisch nicht mehr auf.
- Nur configfs erlaubt **MS-OS-Descriptors** (nötig für Entscheidung 2) und **Laufzeit-LUN-Wechsel** (in Entscheidung 3 genutzt, um das Wegweiser-Image im laufenden Betrieb zu tauschen).
- Der Kernel des Pi Zero 2 W (6.18) unterstützt `libcomposite` vollständig.

Umsetzung (siehe `assets/gadget/piportal-gadget.sh`, `modules/30_gadget.sh`):
- `dtoverlay=dwc2` in `config.txt` schaltet nur den USB-OTG-Controller ein — es **baut kein Gadget**.
- `dwc2` + `libcomposite` früh laden über `/etc/modules-load.d/piportal.conf`.
- Gadget-Aufbau als **systemd-oneshot** (`piportal-gadget.service`), der das Gadget-Skript mit `up` aufruft.
- Das Gerät ist ein sauberes **IAD-Composite** (`bDeviceClass=0xEF`, `SubClass=0x02`, `Protocol=0x01`), Vendor `0x1d6b`, Product `0xa4ac`.
- **Idempotenz:** jedes `up` führt zuerst ein explizites **Teardown** aus (UDC lösen via `echo "" > UDC`, nur die `os_desc`- und Config-**Symlinks** entfernen, dann Configs/Funktionen/Strings in umgekehrter Reihenfolge `rmdir`en). Keines der öffentlichen Referenzskripte ist von Haus aus re-run-sicher — das wird selbst ergänzt, damit `restart` und wiederholte Installationen gefahrlos sind.
- **UDC-Warteschleife mit Retry:** `dwc2` lädt beim Boot asynchron, also wartet das Skript bis zu ~10 s auf einen UDC und wiederholt dann das Binden — der erste Start nach einem Reboot ist timing-sicher.
- **Interface-Reihenfolge:** RNDIS wird zuerst angelegt und verlinkt, damit es die ersten Interfaces belegt (Windows erwartet RNDIS an Slot 0/1).

Warum das offizielle `rpi-usb-gadget` NICHT reicht: nur `g_ether` (Ethernet-only), **kein Massenspeicher**, NetworkManager-basiert (dieses Projekt nutzt ifupdown).

Quellen:
- ohyaan — ConfigFS Composite Gadget (Ethernet + Massenspeicher): https://ohyaan.github.io/tips/creating_a_usb_composite_multi-function_gadget_on_raspberry_pi_using_configfs/
- Ben Hardill — „Composite USB Gadgets" (kanonisches Zwei-Config-Muster): https://www.hardill.me.uk/wordpress/
- thagrol — „USB Mass Storage Gadget – Beginner's Guide": https://github.com/thagrol/usb-gadget
- PIBSAS/pizero2wEth (Pi Zero 2 W, RNDIS + ECM): https://github.com/PIBSAS/pizero2wEth

---

## Entscheidung 2 — NCM-first Single-Config mit automatischem RNDIS-Fallback (`NET_MODE=auto`)

**Entscheidung: das Windows-Netzwerk-Face ist eine einzige USB-Config in `c.1`. Per Default (`NET_MODE=auto`) kommt das Gadget als CDC-NCM hoch — das auf Windows 11 treiberlos bindet — und fällt automatisch auf RNDIS zurück, wenn der verbundene Host NCM nicht annimmt (älteres Windows). CDC-ECM bleibt als optionale zweite Config für Linux/macOS verfügbar.**

Begründung (Ziel: „läuft an möglichst vielen *fremden* Windows-PCs mit möglichst wenig Aufwand am Host"):
- **NCM bindet treiberlos auf Windows 11 — live verifiziert.** Mit einem MS-OS-Descriptor auf Gadget-Ebene plus der `WINNCM`-compatible-id der Funktion lädt Windows 11 seinen Inbox-NCM-Treiber automatisch, ohne Dialog und ohne Adminrechte. In unserem Hardwaretest brachte der Win11-Host den Adapter **still** hoch und zog eine DHCP-Lease auf `10.10.0.x`. NCM ist auch die Richtung, in die die Branche geht (Linux hat seinen RNDIS-Host-Treiber 2023 als unsicher deaktiviert; Microsoft empfiehlt NCM).
- **RNDIS ist der automatische Fallback für ältere Windows.** Windows 7/8/10 haben keinen Inbox-NCM-Treiber, dort bleibt die NCM-Karte still. `NET_MODE=auto` erkennt das (kein `usb0`-Traffic vom verbundenen Host binnen `NET_DETECT_WAIT` Sekunden) und baut das Gadget als **RNDIS** neu, dessen Inbox-Treiber „Remote NDIS Compatible Device" auf Windows 7–10 treiberlos bindet. Ergebnis: treiberlos auf modernem *und* altem Windows.
- **Single-Config, nie Multi-Config.** Ein früherer Zwei-Config-Plan (RNDIS + ECM) ließ Windows **gar keine** Funktionstreiber binden — es handhabt Multi-Config-Geräte schlecht. Also liegt immer genau eine Windows-Netzwerkfunktion in `c.1` (NCM oder RNDIS); ECM ist eine opt-in *separate* Config nur für Linux/macOS.
- Die Raspberry-Pi-**Treiber-`.exe`** braucht Adminrechte + Installation auf dem Ziel-PC → widerspricht „spurlos an fremden PCs", wird also nie genutzt.

`NET_MODE`: `auto` (Default — NCM, RNDIS-Fallback) · `ncm` (nur NCM) · `rndis` (nur RNDIS, opt-in). Der Laufzeit-Fallback schreibt `/run/piportal-netmode` (tmpfs, beim Reboot geleert), sodass jeder Boot zuerst wieder NCM probiert. Detektor: `assets/gadget/piportal-net-detect.sh` (Unit `piportal-net-detect.service`).

Anmerkung zur Product-ID: der Identifier ist `0x1d6b:0xa4ac`. Ein früherer Wert (`…:0104`) war von einem Test-PC nach vielen Reconnects **negativ gecacht** worden, sodass Windows die MS-OS-Descriptors nicht mehr neu auswertete; eine frische Product-ID lässt den Host das Gerät als neu behandeln — siehe [`DESIGN_NOTES.de.md`](DESIGN_NOTES.de.md).

Quellen:
- MS-OS-Descriptor / RNDIS-Ordering: https://learn.microsoft.com/en-us/answers/questions/474108/does-rndis-need-to-be-listed-as-the-first-function
- NCM-Auto-Bind-Problematik (Praxis): https://forum.beagleboard.org/t/pocketbeagle-2-usb-network-access-from-windows-usb-ncm-driver/42001
- Linux deaktiviert den RNDIS-Host-Treiber: https://itsfoss.gitlab.io/post/linux-is-all-set-to-disable-microsofts-rndis-drivers/
- postmarketOS-Umstieg auf NCM: https://postmarketos.org/edge/2023/10/29/rndis-ncm/

---

## Entscheidung 3 — Read-only-FAT16-Wegweiser-Image + gehärtetes SMB (statt beschreibbarem Speicher)

**Entscheidung: Die Massenspeicher-LUN ist ein reiner Wegweiser, read-only ausgeliefert; der gesamte echte Datentausch läuft ausschließlich über gehärtetes SMB.**

Begründung:
- **Ein read-only-Medium beseitigt das Korruptionsrisiko.** Der Ur-Aufbau zeigte ein beschreibbares 50-MB-FAT-Image, auf das PC und Pi gleichzeitig schreiben konnten — ohne Kohärenzkanal zwischen Host-Cache und Loop-Mount des Pi droht Datenkorruption. Die LUN read-only (`ro=1`) auszuliefern heißt: Windows liest nur; Nutzdaten laufen nie über den Massenspeicher.
- **Read-only-FAT16, nicht CD-ROM/ISO9660.** Der Plan war eine CD-ROM-Emulation (`cdrom=1`, ISO9660). Auf dem **Kernel 6.18** des Pi scheitert das: das Binden einer ISO-Datei im `cdrom=1`-Modus wird mit **Fehler 525** abgelehnt (empirisch bestätigt). Der funktionierende, Windows-kompatible Weg ist ein kleines **FAT16-Image mit `ro=1` + `removable=1`** — Windows behandelt es als schreibgeschützten USB-Stick und schreibt kein `System Volume Information` / `$RECYCLE.BIN` / keinen Indexer-Müll darauf.
- **`ro` und `removable` werden vor `file` gesetzt.** Der Kernel akzeptiert diese LUN-Attribute nur, solange keine Backing-Datei gebunden ist — das Skript schreibt daher erst `ro=1` und `removable=1`, dann den Image-Pfad.
- **16-MB-Image.** FAT16 braucht genügend Cluster; ein 4-MB-Image scheitert beim Formatieren als „too small". 16 MB ist die kleinste breit windows-kompatible Größe und reichlich für den Wegweiser. Ohne Mount gebaut via `mkfs.vfat -F 16` + `mtools` (`mcopy`).
- Inhalt: `LIESMICH.txt` (wie man den Share erreicht), eine `.url`-Verknüpfung auf `\\10.10.0.1\PiPortal` und der SSH-Helfer `connect-piportal.cmd`.

Laufzeit-Image-Tausch: weil die LUN `removable=1` ist, lässt sich ein neu gebautes Image ins laufende Gadget heiß tauschen, indem man erst einen leeren String und dann den neuen Pfad in `lun.0/file` schreibt — `modules/40_portal_smb.sh` macht genau das beim Neubau des Images.

Autorun-Faktenlage: AutoRun auf Wechseldatenträgern ist seit 2011 (KB971029) **tot** — `autorun.inf` startet nichts. Das Design geht davon aus, dass der Nutzer das Laufwerk öffnet und die `.url` manuell klickt; der Datenträger bekommt lediglich ein sauberes Label (`PIPORTAL`).

Zugangswege zum SMB-Share (Rangfolge im Wegweiser):
1. Fester UNC-Pfad `\\10.10.0.1\PiPortal` (immer zuverlässig).
2. Hostname `\\PiPortal.local\PiPortal` (mDNS, meist ok, nicht garantiert).

SMB-Härtung (`smb.conf`, siehe `modules/40_portal_smb.sh`):
- `server min protocol = SMB2`, `client min protocol = SMB2`, `server max protocol = SMB3_11` (kein SMB1); `server signing = mandatory`; `smb encrypt = required` nur bei `SMB_ENCRYPT=1` (CPU-Last auf dem Zero 2 W).
- `security = user`, `map to guest = Never`, `restrict anonymous = 2`, `guest ok = no`, `valid users = <smb-user>`.
- `interfaces = lo usb0 10.10.0.1` + `bind interfaces only = yes`, `smb ports = 445`, `disable netbios = yes` (kein NetBIOS/139).
- Die Konfiguration wird mit `testparm` validiert, bevor der Dienst neu startet.

Quellen:
- Kernel Mass Storage Gadget (ro/cdrom/removable): https://docs.kernel.org/usb/mass-storage.html
- gadget_cdrom (Swap-Logik): https://github.com/tjmnmk/gadget_cdrom
- Autorun tot: https://learn.microsoft.com/en-us/answers/questions/4189978/is-autorun-inf-on-a-removable-drive-disabled-on-wi
- SMB-Härtung Win11 / Server 2025: https://techcommunity.microsoft.com/blog/filecab/smb-security-hardening-in-windows-server-2025--windows-11/4226591

---

## Zusammenfassung — die ausgelieferte Architektur

Ein **configfs-Composite-Gadget**, aufgebaut per idempotentem systemd-oneshot, mit einer **einzigen USB-Config**:

1. **NCM per Default** (`NET_MODE=auto`, MS-OS-/`WINNCM`-Descriptors, Product `0x1d6b:0xa4ac`) → das Windows-Gesicht; bindet **treiberlos auf Windows 11** (verifiziert). Automatischer **RNDIS**-Fallback deckt Windows 7–10 ab.
2. **Massenspeicher** als **read-only-FAT16-Image** (`ro=1 removable=1`, 16 MB) → sichtbarer Wegweiser mit einer `.url` auf den SMB-Share.
3. **CDC-ECM** → optionale *separate* Config für Linux/macOS, **per Default aus** (Multi-Config zerlegt die Windows-Treiberbindung).

Der eigentliche Datentausch läuft ausschließlich über **gehärtetes SMB** auf `usb0` (`10.10.0.1`). dnsmasq vergibt dem Windows-Host eine Lease, unterdrückt dabei Gateway/DNS (Optionen 3/6/15 leer) und listet die Optionen 119/121/249 bewusst **nicht** auf — dnsmasq würde sie sonst als 0-Byte-Optionen senden und Windows das gesamte DHCP-OFFER verwerfen (Landung auf APIPA). Der Host behält sein eigenes Internet; SSH über `usb0` bleibt stehen. Wie jede dieser Lösungen bei der Live-Inbetriebnahme entstand, steht in [`DESIGN_NOTES.de.md`](DESIGN_NOTES.de.md).
