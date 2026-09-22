**[🇬🇧 English](DESIGN_NOTES.md)** · 🇩🇪 Deutsch

# PiPortal — Design-Notizen (was, wie und warum)

Dieses Dokument hält die technische Geschichte hinter PiPortal fest: wo das Gerät startete, was geplant war und — vor allem — welche Probleme erst an echter Hardware auftauchten und wie jedes gelöst wurde. Die drei zentralen Architektur-*Entscheidungen* stehen in [`ARCHITECTURE.de.md`](ARCHITECTURE.de.md); diese Datei ist die Erzählung und das Ursachen-Logbuch.

Durchgehend gilt: der Code ist die alleinige Wahrheitsquelle. Wo ein früher Plan und der ausgelieferte Code sich widersprechen, hat der Code gewonnen, und dieses Dokument erklärt, warum.

---

## 0. Herkunft

PiPortal begann als handgeschriebenes Theorie-Dokument, entworfen mit Hilfe einer Such-KI. Diese Originaldatei enthielt **Secrets im Klartext** (ein Geräte-Passwort, interne IP-Adressen) und ist deshalb bewusst **nicht** Teil dieses Repos — sie bleibt lokal und ist per `.gitignore` ausgeschlossen. Ihr fachlicher Kern wurde bereinigt, gegen das laufende Gerät und aktuelle Quellen geprüft und zu diesem sauberen, reproduzierbaren Projekt neu aufgebaut.

Das Ziel: ein Raspberry Pi Zero 2 W auf einem USB-Dongle, der in jeden PC gesteckt sofort eine Netzwerkkarte plus ein kleines Laufwerk anbietet, mit eigenem WLAN-Uplink, ohne am Host etwas zu ändern — eingerichtet von einem idempotenten Installer, ohne Secrets im Repo.

---

## 1. Ausgangslage (das Gerät, wie vorgefunden)

Eine Live-Recon per SSH ermittelte die Wahrheit, bevor irgendetwas geändert wurde. Das Gerät machte manches bereits gut — eine statische `usb0`-IP als updatesicheres Drop-in, korrektes Default-Routing (Internet übers WLAN, nicht über USB), WLAN-Roaming mit Prioritäten, ein schlanker Boot — trug aber auch echte Probleme:

- **Legacy-`g_multi`-Gadget.** Keine MS-OS-Descriptors (Windows band RNDIS nicht automatisch), ein erzwungener ACM-COM-Port (gelbes Ausrufezeichen im Geräte-Manager) und keine Laufzeit-LUN-Kontrolle.
- **Beschreibbarer Massenspeicher.** Die `g_multi`-LUN war read-write, PC und Pi konnten dasselbe 50-MB-FAT-Image gleichzeitig schreiben — ein Korruptionsrisiko ohne Kohärenzkanal zwischen beiden.
- **dnsmasq kaperte den Host.** Die USB-DHCP-Config schickte dem PC ein Default-Gateway und DNS, sodass der Host seinen gesamten Internetverkehr in die tote `usb0`-Strecke routen konnte.
- **Kein SMB-Portal.** Das eigentliche „Portal"-Konzept (Wegweiser → geschützter Share) existierte noch nicht; Samba war nicht installiert.
- **Secrets im Klartext.** Beide WLAN-SSIDs und der PSK standen in `wpa_supplicant.conf`, SSIDs waren zusätzlich ins Roaming-Skript hartcodiert — alles musste vor einem Repo zu Platzhaltern werden.
- **Kernel 6.18** war neu genug für den modernen configfs-Weg — der Enabler für alles Weitere.

---

## 2. Der Plan

Drei Architektur-Entscheidungen wurden gegen aktuelle Best Practice validiert, bevor am laufenden Gerät etwas angefasst wurde (volle Begründung + Quellen in [`ARCHITECTURE.de.md`](ARCHITECTURE.de.md)):

1. **Gadget-Technik → configfs / libcomposite** (`g_multi` ausmustern).
2. **Windows-Netzwerk → NCM-first mit automatischem RNDIS-Fallback** (`NET_MODE=auto`): NCM bindet treiberlos auf Windows 11, RNDIS deckt Windows 7–10 ab — siehe [`ARCHITECTURE.de.md`](ARCHITECTURE.de.md).
3. **Speicher → read-only-Wegweiser + gehärtetes SMB für alle echten Daten** (Korruptionsrisiko beseitigen).

Daneben eine feste Liste von Korrekturen, unabhängig von den großen Entscheidungen: dnsmasq-Gateway/DNS-Optionen unterdrücken (K1), nie beschreibbaren Speicher ausliefern (K2), alle Secrets in eine gitignorierte Config auslagern (K3), die fragile Roaming-Schleife durch einen systemd-Dienst ersetzen (K4), verwaiste statische Zeilen in `interfaces` aufräumen (K5), Samba installieren und härten (K6) und das Node-/Claude-Code-Labor zu einem optionalen, abschaltbaren Modul machen (K7).

Der Installer wurde modular und idempotent gebaut — jeder Schritt ist „if not exist → anlegen" — mit einer Backup-Phase zuerst und einem Rollback-Pfad, sodass jede Iteration einfach per Drüber-Installieren getestet werden konnte. Das Einzige, was bei einem misslungenen Lauf auf dem Spiel stand, war die SD-Karte.

---

## 3. Was sich bei der Live-Inbetriebnahme änderte

Der Plan überstand den Kontakt mit der Realität weitgehend — aber mehrere Dinge scheiterten erst an echter Windows-Hardware, und diese Fixes sind der eigentliche Wert dieses Abschnitts. Jeder ist jetzt im ausgelieferten Code verankert.

**3.1 CD-ROM-Emulation vom Kernel 6.18 abgelehnt (Fehler 525).**
Der Plan lieferte den Wegweiser als emulierte CD-ROM (`cdrom=1`, ISO9660), weil Windows optische Medien strikt read-only behandelt. Auf dem Kernel 6.18 des Pi wird das Binden einer ISO-Datei im `cdrom=1`-Modus mit **Fehler 525** verweigert. Fix: stattdessen ein kleines **FAT16-Image mit `ro=1` + `removable=1`** — Windows behandelt es weiterhin als schreibgeschützten Stick und schreibt keinen Müll darauf. `ro`/`removable` müssen *vor* der Backing-`file` gesetzt werden, da der Kernel diese Attribute nur akzeptiert, solange keine Datei gebunden ist.

**3.2 FAT16 „too small" bei 4 MB.**
Das erste Wegweiser-Image war 4 MB und scheiterte beim Formatieren als FAT16 („too small" — zu wenige Cluster). Auf **16 MB** erhöht, die kleinste breit windows-kompatible FAT16-Größe, ohne Mount gebaut via `mkfs.vfat -F 16` + `mtools`.

**3.3 Windows lud aus einem Multi-Config-Gadget gar keine Treiber.**
Der Plan nutzte zwei USB-Configs (Config 1 = RNDIS für Windows, Config 2 = CDC-ECM für Linux/macOS). An echter Hardware band Windows **nichts** — keine Netzwerkkarte, kein Laufwerk — weil es Multi-Config-Geräte schlecht handhabt und dann keine Funktionstreiber lädt. Fix: eine **einzige Config** ausliefern (RNDIS + Massenspeicher); `ENABLE_ECM=0` per Default. ECM/NCM bleiben für reinen Linux/macOS-Einsatz verfügbar.

**3.4 RNDIS band nicht — ein vergifteter Treiber-Cache.**
Selbst mit korrekten MS-OS-/compat-Descriptors weigerte sich die RNDIS-Karte zu erscheinen. Ursache: nach vielen Test-Reconnects hatte der Test-PC den USB-Identifier `1d6b:0104` **negativ gecacht** und wertete die Descriptors nicht mehr neu aus. Fix: die Product-ID auf **`0xa4ac`** ändern → Windows sieht ein neues Gerät und lädt „Remote NDIS Compatible Device" automatisch. Die Descriptors waren die ganze Zeit korrekt; nur der Host-Cache war veraltet.

**3.5 Windows landete auf APIPA — die 0-Byte-DHCP-Options-Falle.**
Der Host fiel immer wieder auf eine `169.254.x.x`-Selbstadresse zurück. Ursache: um die DHCP-Optionen 119/121/249 zu *unterdrücken*, listete die Config sie mit leeren Werten — aber dnsmasq sendet solche Optionen (die es von sich aus nie schickt) als **0-Byte-Option**, und Windows verwirft das gesamte DHCP-OFFER, sobald es eine sieht (DISCOVER/OFFER, aber nie REQUEST/ACK). Fix: diese drei Zeilen **komplett entfernen** (nur 3/6/15 werden legitim unterdrückt) und `dhcp-authoritative` setzen. Windows least dann sauber eine `10.10.0.x`-Adresse.

**3.6 Gadget-Neustart scheiterte — ein kaputtes Teardown.**
Ein zweites `up`/`restart` scheiterte mit `ln: … Invalid argument`, weil das Teardown den `os_desc`-Config-Symlink nicht entfernte (ein fehlerhafter `[ -L glob ]`-Test). Fix: das Teardown iteriert jetzt und entfernt die `os_desc`- und Config-Symlinks korrekt, sodass das Gadget wirklich re-run-/restart-sicher ist — worauf die Idempotenz-Garantie beruht.

**3.7 Frische Installation startete das Gadget zu früh.**
Auf einer leeren SD-Karte versuchte Modul 30 einen Live-Gadget-Start, obwohl das gerade erst gesetzte `dtoverlay=dwc2` erst nach einem Reboot greift (noch kein UDC vorhanden). Fix: der Live-Start ist jetzt auf UDC-Präsenz abgesichert, und `install.sh` gibt den Reboot-Hinweis auch im Frisch-Installations-Fall aus. Das Gadget-Skript wartet zusätzlich bis zu ~10 s auf den UDC und wiederholt das Binden, sodass der erste Start nach dem Reboot timing-sicher ist.

**3.8 Ein OS-Update-Migrationsrisiko, geprüft und entwarnt.**
DietPi migriert `dhclient` → `udhcpc`, was auf `ifupdown2` das Netzwerk brechen kann (Upstream-Issue #8040). Vor `dietpi-update` wurde das geprüft: das Gerät nutzt klassisches `ifupdown`, die Migration ist hier also ungefährlich. Notiert, damit künftige Updates das weiter verifizieren.

---

## 4. Ergebnis

Das fertige Gerät wurde live an einem Windows-11-PC verifiziert: das Einstecken bringt die **Netzwerkkarte** (NCM auf Windows 11) hoch, das **PIPORTAL**-Read-only-Laufwerk mit seinem `.url`-Wegweiser, eine saubere **DHCP-Lease** auf `10.10.0.x` und einen erreichbaren **gehärteten SMB-Share** — während der Host sein eigenes Internet behält und SSH über `usb0` steht. Ein erneuter Installer-Lauf über eine bestehende Installation ändert nichts, was nicht geändert werden muss, und eine frische SD-Karte reproduziert den ganzen Aufbau mit einem Reboot.

---

## 5. Kompromisse und bekannte Grenzen (keine Roadmap)

- **NCM per Default, RNDIS als automatischer Fallback (ausgeliefert, `NET_MODE=auto`).** NCM bindet treiberlos auf Windows 11 — live verifiziert — und der Detektor fällt für Windows 7–10 (kein Inbox-NCM-Treiber) auf RNDIS zurück. RNDIS ist jetzt Fallback/Opt-in, nicht mehr der Default; das folgt der Branchenrichtung (Linux hat seinen RNDIS-Host-Treiber 2023 als unsicher deaktiviert).
- **Single-Config** tauscht das saubere Linux/macOS-ECM-Gesicht gegen bombenfeste Windows-Bindung. ECM ist einen Config-Schalter entfernt, wenn ein Host es braucht.
- **Read-only-Wegweiser** heißt: der Stick selbst trägt per Design nie Nutzdaten — alles Echte läuft über SMB. Das ist der ganze Sinn der Korruptions-Beseitigung, keine zu umgehende Einschränkung.
- **512 MB RAM** werden durch zram plus ein nach Kartengröße gestaffeltes SD-Swapfile abgefedert, nicht aufgehoben; fordernde Werkzeuge laufen, aber das ist ein Zero 2 W, keine Workstation.
