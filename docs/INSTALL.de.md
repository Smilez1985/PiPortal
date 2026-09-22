**[🇬🇧 English](INSTALL.md)** · 🇩🇪 Deutsch

# PiPortal — Installationsanleitung

Diese Anleitung führt von der leeren microSD-Karte bis zum fertig eingesteckten PiPortal. Sie besteht aus zwei klar getrennten Teilen: **Teil A** ist die Vorbereitung des Betriebssystems (DietPi) — das macht der Benutzer, *bevor* PiPortal ins Spiel kommt. **Teil B** ist der idempotente PiPortal-Installer, der den Rest übernimmt.

Wichtig vorab, weil es leicht zu verwechseln ist: Wenn hier von der **„PiPortal-Config"** die Rede ist, ist immer die Datei **`config/piportal.conf`** im Repo gemeint — **nicht** `dietpi-config`. Das WLAN richtest du in DietPi ein (Teil A), nicht in der PiPortal-Config.

---

## Voraussetzungen

**Hardware**

- **Raspberry Pi Zero 2 W** (die **WH**-Variante bringt die Stiftleiste bereits verlötet mit — praktisch, aber kein Muss).
- **microSD-Karte** (16 GB genügen; ab 64 GB richtet PiPortal automatisch mehr Auslagerungsspeicher ein).
- Ein Weg, den Pi in eine **USB-A-Buchse** des PCs zu bekommen: der **GeeekPi-USB-Dongle-Aufsatz** (steckt den Pi direkt in die Buchse und versorgt ihn darüber) — **oder**, ganz ohne Aufsatz, ein simples **USB-OTG-Kabel** vom Daten-Micro-USB des Pi zum PC. Der Aufsatz ist bequem, aber optional.
- Ein **WLAN**, in das sich der Pi einwählen kann (Router und/oder Handy-Hotspot).

**Software / Können**

- Ein Windows-PC (10/11) mit dem mitgelieferten OpenSSH-Client (Standard).
- Grundlagen SSH und Editieren einer Textdatei auf dem Pi (`nano`).

Alle **Paketabhängigkeiten** installiert der PiPortal-Installer selbst (siehe unten) — du musst auf dem Pi nichts vorab per Hand installieren, außer einem lauffähigen, mit dem Internet verbundenen DietPi.

---

## Teil A — Betriebssystem vorbereiten (DietPi)

Dieser Teil gehört nicht zu PiPortal, ist aber die Grundlage. Reihenfolge:

1. **DietPi-Image auf die microSD schreiben.** Image von [dietpi.com](https://dietpi.com/) laden und mit dem [Raspberry Pi Imager](https://www.raspberrypi.com/software/) oder Balena Etcher auf die Karte schreiben.
2. **WLAN schon vor dem ersten Start hinterlegen.** Auf der frisch beschriebenen Karte (Boot-Partition) in `dietpi.txt` das WLAN aktivieren (`AUTO_SETUP_NET_WIFI_ENABLED=1`) und in `dietpi-wifi.txt` deine Zugangsdaten eintragen. SSH ist bei DietPi standardmäßig aktiv.
3. **microSD in den Pi Zero 2 W(H) einlegen.**
4. **Pi mit dem PC verbinden** — entweder über den GeeekPi-USB-Aufsatz oder per USB-OTG-Kabel am Daten-Port. Beim allerersten Start richtet DietPi sich selbst ein (einige Minuten; ein Reboot ist dabei normal).

> **Mehrere WLANs / später erweitern.** DietPi ist und bleibt die Quelle deiner WLAN-Netze. Du kannst jederzeit weitere Netze hinzufügen — am saubersten mit `dietpi-config` → *Network Options: Adapters* → *WiFi*, oder direkt in `/etc/wpa_supplicant/wpa_supplicant.conf`. PiPortal übernimmt **alle** dort hinterlegten Netze (dazu unten mehr). In diesem Projekt sind es typischerweise zwei: das Heim-WLAN und ein Handy-Hotspot als Ausweichnetz.

Wenn du dich anschließend vom PC aus verbinden willst (noch ohne PiPortal), geht das per SSH über die WLAN-IP des Pi (steht im Router, oder via `dietpi.local`):

```bash
ssh dietpi@<WLAN-IP-des-Pi>
```

---

## Teil B — PiPortal einrichten

Auf dem laufenden, mit dem WLAN verbundenen Pi:

```bash
# 1. Repo auf den Pi holen (per git clone oder als Archiv kopieren)
cd ~/PiPortal

# 2. Eigene Einstellungen anlegen
cp config/piportal.conf.example config/piportal.conf
nano config/piportal.conf

# 3. Installer starten (interaktives Menü) …
sudo ./install.sh
# … oder ohne Menü:
sudo ./install.sh --all --non-interactive
```

Nach dem Lauf einmal neu starten, damit das USB-Gadget-Overlay greift:

```bash
sudo reboot
```

Der Installer ist **idempotent**: Ein erneuter Lauf über eine bestehende Installation ändert nur, was geändert werden muss. Rückgängig machen lässt sich alles mit `sudo ./uninstall.sh` (WLAN-Zugang, SAE-Härtung und SSH bleiben dabei bewusst erhalten).

### Was in die PiPortal-Config gehört (und was nicht)

`config/piportal.conf` ist gitignoriert und enthält deine individuellen Werte — u. a. den SMB-Benutzer, das SMB-Passwort und **optional** WLAN-Angaben. Zum WLAN gleich mehr; der entscheidende Punkt: **die WLAN-Felder lässt du im Normalfall leer**, weil DietPi das WLAN schon verwaltet.

### Abhängigkeiten (installiert der Installer automatisch)

Der Installer zieht per `apt` nur, was fehlt: `dnsmasq`, `wpasupplicant`, `iw`, `samba` + `samba-common-bin`, `dosfstools`, `mtools`, `avahi-daemon`, `gettext-base`, `zram-tools`. Für das **optionale** KI-Labor (Claude Code CLI, per Default aus) zusätzlich `curl`, `ca-certificates` und `nodejs`. Voraussetzung ist nur eine funktionierende Internetverbindung des Pi (also das eingerichtete WLAN aus Teil A).

---

## Das WLAN-Modell (wichtig)

PiPortal fährt **hybrid**, und der Normalfall ist bewusst „Hände weg vom OS":

- **Standard — DietPi verwaltet die Netze.** Lässt du die WLAN-Felder in `config/piportal.conf` **leer** (Auslieferungszustand), fasst der Installer die `wpa_supplicant.conf` **nicht an**. Deine in DietPi eingerichteten Netze bleiben unverändert, und der Roaming-Dienst nutzt **alle** davon — egal ob eins, zwei oder fünf. Ein später in DietPi hinzugefügtes Netz wird automatisch mitgenutzt; nichts muss in PiPortal nachgezogen werden.
- **Reihenfolge / Vorzug — über `priority=` im OS.** Welches Netz bevorzugt wird, steht in `wpa_supplicant.conf` je Netzblock als `priority=<Zahl>` (höher = bevorzugt), z. B. Heimnetz `priority=100`, Hotspot `priority=1`. `wpa_supplicant` verbindet sich mit dem Netz höchster Priorität, das in Reichweite ist. Der PiPortal-Roaming-Dienst leitet sein „Heimnetz" (für den *aktiven* Rückwechsel, sobald es wieder in Reichweite ist) **automatisch aus der höchsten OS-`priority` ab** — live, ohne dass etwas in die PiPortal-Config kopiert werden muss. Fügst du in DietPi ein höher priorisiertes Netz hinzu, wird es von selbst zum neuen Heimnetz. (`WIFI_HOME_SSID` in `config/piportal.conf` bleibt als optionaler Override, falls du den Vorzug manuell festlegen willst — leer = OS entscheidet.)
- **Nach Reinstall/Uninstall bleiben die Netze erhalten**, weil sie im OS (`wpa_supplicant.conf`) liegen — der Uninstaller schützt diese Datei ausdrücklich, damit der Pi per WLAN und SSH erreichbar bleibt.
- **Optional — von der PiPortal-Config gesteuert.** Trägst du in `config/piportal.conf` SSIDs ein (`WIFI_HOME_SSID` / `WIFI_HOTSPOT_SSID`), schreibt der Installer daraus eine `wpa_supplicant.conf` mit genau diesen Profilen (Heim bevorzugt, Hotspot als Ausweich) und **ersetzt** dabei den bisherigen Inhalt — vorher wird automatisch ein Backup angelegt. Diese Variante ist für Setups gedacht, in denen PiPortal das WLAN allein verwalten soll. Willst du „nimm was da ist und passe dich an", lässt du die Felder leer.

Praktischer Rat: WLAN in DietPi einrichten (native Methode, `dietpi-config`), PiPortal-Config-WLAN leer lassen. So bleibt DietPi die eine Wahrheitsquelle fürs WLAN, und weitere Netze fügst du jederzeit dort hinzu.

---

## Am PC benutzen

Stick einstecken, ~30 Sekunden warten. Windows erkennt die Netzwerkkarte automatisch (**treiberlos** per NCM auf Windows 11, RNDIS-Fallback für Windows 7–10) und zeigt das read-only Laufwerk **PIPORTAL** mit den Wegweiser-Dateien (`LIESMICH.txt`, `readme.txt`, `README.md`) samt Verknüpfung zum geschützten Netzlaufwerk.

- **Netzlaufwerk öffnen:** im Explorer `\\10.10.0.1\PiPortal`, oder Doppelklick auf `PiPortal-Netzlaufwerk.url`. Benutzernamen als `10.10.0.1\<benutzer>` eingeben.
- **Passwort setzen (erstes Mal) / zurücksetzen (falls vergessen):** Doppelklick auf `SMB-Passwort.vbs` — dasselbe Werkzeug erkennt selbst, was nötig ist.
- **Terminal:** `ssh <benutzer>@10.10.0.1`, oder Doppelklick auf `connect-piportal.cmd`.

Der SMB-Benutzername ist nicht fest verdrahtet: der Installer nimmt ihn aus `config/piportal.conf` (`SMB_USER`) oder leitet ihn — bei leerem Wert — aus dem OS ab (der Nicht-Root-Login, der den Installer gestartet hat; nie root).

---

## Verifizieren

Auf dem Pi:

```bash
piportal --status
```

zeigt kompakt IPs, Uptime, CPU-Temperatur, RAM/Swap und den Zustand der Dienste (Gadget, dnsmasq, Samba, WLAN-Roaming). Am Windows-PC ist der Erfolg sichtbar, sobald das **PIPORTAL**-Laufwerk erscheint und `\\10.10.0.1\PiPortal` nach Anmeldung öffnet.

---

## Deinstallieren

```bash
sudo ./uninstall.sh            # Dienste stoppen, jüngstes Backup zurückspielen
sudo ./uninstall.sh --purge    # zusätzlich PiPortal-Dateien/-Share entfernen
```

WLAN-Zugang, die SAE-/WPA3-Härtung und SSH bleiben in beiden Fällen erhalten — der Pi bleibt erreichbar.

---

Tiefergehende Hintergründe: Architektur-Entscheidungen in [`ARCHITECTURE.de.md`](ARCHITECTURE.de.md), das vollständige Was/Wie/Warum der Live-Inbetriebnahme in [`DESIGN_NOTES.de.md`](DESIGN_NOTES.de.md), Sicherheit in [`SECURITY.de.md`](SECURITY.de.md).
