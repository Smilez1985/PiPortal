**[🇬🇧 English](TAILSCALE.md)** · 🇩🇪 Deutsch

# PiPortal — Tailscale-Onboarding (optionales Feature)

Tailscale ist ein Mesh-VPN: Geräte finden sich über einen **Koordinationsserver**
und reden danach direkt (Peer-to-Peer) miteinander, verschlüsselt. Für den
PiPortal heißt das: von unterwegs erreichst du ihn (und über ihn dein Heimnetz),
ohne Portfreigaben am Router.

Dieses Feature ist **Opt-in und standardmäßig aus**. Der Installer bringt auf
Wunsch nur den **Client** mit — er meldet dich **nirgends** an und legt **keine**
Keys, URLs oder sonstigen Daten ins Repo. Das Anmelden (Onboarding) machst du
selbst; diese Datei zeigt wie.

---

## Voraussetzung — ohne Server kein Feature

Tailscale braucht immer einen Koordinationsserver. Du hast genau zwei
Möglichkeiten:

1. **Tailscale-Cloud** — ein (kostenloses) Konto auf [tailscale.com](https://tailscale.com/).
2. **Eigener Headscale-Server** — die selbst gehostete, quelloffene Alternative
   zur Tailscale-Cloud ([headscale](https://headscale.net/)). Den musst du
   vorher aufsetzen (eigenes Projekt, nicht Teil von PiPortal).

**Hast du weder das eine noch das andere, lass das Feature einfach weg:**
`ENABLE_TAILSCALE="0"` in `config/piportal.conf` (das ist der Auslieferungswert).
Der PiPortal funktioniert vollständig ohne Tailscale.

---

## Schritt 1 — Client mitinstallieren (Opt-in)

In `config/piportal.conf`:

```bash
ENABLE_TAILSCALE="1"
```

Dann den Installer laufen lassen (oder gezielt nur diese Phase):

```bash
sudo ./install.sh --only 55_tailscale --non-interactive
```

Der Installer wählt die Installationsart passend zum System:

- **DietPi** → über den Katalog (`dietpi-software install 58`), bleibt in der
  DietPi-Paketverwaltung.
- **Arch/Alpine** → nativ aus dem Distro-Repo (`pacman` / `apk`).
- **Debian/Ubuntu/Fedora/RHEL/openSUSE** → über das offizielle
  Tailscale-Install-Script, das den korrekten Vendor-Repo-Weg je Paketmanager
  (`apt`/`dnf`/`yum`/`zypper`) geht.
- sonst → offizielles Install-Script als Fallback.

Der Dienst `tailscaled` läuft danach (damit `tailscale up` greift), **aber es
wird nichts angemeldet und nichts verbunden**. Zusätzlich richtet der Installer
einen **Boot-Hook** ein (`piportal-tailscale-down.service`), der Tailscale nach
**jedem Reboot getrennt** lässt.

**Bewusst manuell und nicht persistent:** Tailscale läuft nur, wenn du es
manuell mit `tailscale up …` startest, und ist nach einem Reboot wieder aus.
Das hält es einfach und verhindert den Subnetz-Self-Hijack im Heimnetz (siehe
unten).

---

## Schritt 2 — Onboarding (machst du selbst)

### A) Tailscale-Cloud

```bash
sudo tailscale up
```

Der Befehl zeigt eine Login-URL; im Browser mit deinem Tailscale-Konto
bestätigen. Fertig.

### B) Eigener Headscale-Server

Erst auf deinem Headscale einen **Preauth-Key** erzeugen (Einweg-Material,
begrenzt gültig) — der genaue Befehl hängt von deiner Headscale-Version ab, z. B.:

```bash
sudo headscale preauthkeys create -u <BENUTZER-ID> --expiration 24h
```

Dann auf dem PiPortal anmelden:

```bash
sudo tailscale up \
  --login-server https://<DEINE-HEADSCALE-URL> \
  --authkey <DEIN-PREAUTH-KEY>
```

**Später neu verbinden** (Login bleibt nach `tailscale down`/Reboot erhalten, also
**ohne** Key):

```bash
sudo tailscale up --login-server https://<DEINE-HEADSCALE-URL>
```

`tailscale up` **ohne** Flags meckert („requires mentioning all non-default
flags"), weil die `--login-server`-Vorgabe gespeichert ist — nenne sie einfach
mit (wie oben) oder nutze `sudo tailscale up --reset`.

Hinweise:

- **`--login-server`** zeigt auf *deinen* Server statt auf die Tailscale-Cloud.
  Fehlt die Option, meldest du dich versehentlich bei Tailscale an.
- **Kein `--advertise-routes`:** der PiPortal bietet keine Route an. Einen
  Subnet-Router stellt (falls gewünscht) ein anderes, dauerhaft laufendes Gerät.
- **`--accept-routes` bewusst AUS lassen, solange der PiPortal im Heimnetz hängt.**
  Er sitzt selbst *innerhalb* des angebotenen Subnetzes; nähme er die Route an,
  würde er seinen **eigenen** LAN-Verkehr über den Tunnel umleiten und sich damit
  den LAN-lokalen Zugriff kappen. Unterwegs (fremdes Subnetz) wäre `--accept-routes`
  unschädlich und nützlich — aber zum bloßen **Erreichen** des PiPortal brauchst du
  es ohnehin nicht (siehe nächster Abschnitt).
- **`--accept-dns`** bleibt auf der Vorgabe (an), wenn dein Koordinationsserver
  einen DNS-Server vorgibt (z. B. einen Pi-hole) und der PiPortal den nutzen soll.

**Trennen:** `sudo tailscale down`. Nach einem Reboot ist es ohnehin wieder aus
(Boot-Hook) — dann bei Bedarf erneut `tailscale up …`.

---

## Vom Handy auf den PiPortal zugreifen (der eigentliche Nutzen)

Du erreichst den PiPortal **über seine Tailnet-IP** (`100.64.x.x`), nicht über die
IP, die ihm das jeweilige WLAN gibt. Vom Handy (mit Tailscale-App im selben
Tailnet), egal ob PiPortal am Powerbank+Hotspot, im Heimnetz oder sonstwo hängt:

```bash
ssh <benutzer>@100.64.x.x
```

Die Tailnet-IP **ändert sich nie**, egal an welchem Netz der PiPortal hängt — kein
Kennen der Hotspot-IP nötig, keine Portfreigabe. Ist dein Handy selbst der Hotspot,
bauen die beiden sogar eine direkte P2P-Verbindung auf.

Das ist **unabhängig von `--accept-routes`**: den PiPortal zu *erreichen* braucht
nur Tailnet-Mitgliedschaft. `--accept-routes` bräuchtest du nur, wenn der PiPortal
umgekehrt aktiv **andere Heim-Geräte** erreichen soll (Pi-hole-DNS filtern, NAS …).

Und: `--accept-routes` ist **kein** Exit-Node. Es zieht nur die angebotenen
Subnetze in den Tunnel, **nicht** deine Default-Route — dein Internet läuft am
Hotspot also weiter direkt (Split-Tunnel). Willst du *allen* Verkehr übers Heim
leiten (wie ein Full-Tunnel-WireGuard), ist das ein Exit-Node
(`tailscale up --exit-node=<Heim-IP>`), separat und opt-in.

## Schritt 3 — Prüfen

Auf dem PiPortal:

```bash
tailscale status      # zeigt die eigene 100.64.x.x und die Peers
tailscale ip -4       # die eigene Tailnet-IPv4
```

Auf dem Koordinationsserver taucht der PiPortal als Node mit einer Adresse aus
`100.64.0.0/10` auf (bei Headscale: `sudo headscale nodes list`).

---

## Stolperstein bei selbst gehostetem Headscale: DNS-Rebind-Schutz

Zeigt deine Steuer-URL (z. B. ein DuckDNS-/DynDNS-Name) im Heimnetz auf eine
**private** IP, verwerfen viele Router (u. a. die FRITZ!Box) solche Antworten als
mutmaßlichen „DNS-Rebind"-Angriff. `tailscale up` scheitert dann mit
`failed to resolve …`. Abhilfe, je nach Gerät:

1. Im Router den Namen als **Ausnahme vom DNS-Rebind-Schutz** eintragen (hilft
   allen LAN-Geräten).
2. Auf dem PiPortal einen direkten `/etc/hosts`-Eintrag setzen (Notnagel):
   `<private-IP-deines-Servers>  <DEINE-HEADSCALE-URL>`.

---

## Wieder entfernen

- **Aus dem Tailnet nehmen:** `sudo tailscale logout` (und auf dem Server den
  Node löschen, bei Headscale `sudo headscale nodes delete -i <ID>`).
- **Client deinstallieren:** über den Paketmanager, mit dem er kam
  (`apt`/`dnf`/`pacman`/`apk`/… bzw. DietPi).
- Der PiPortal-**Uninstaller lässt Tailscale bewusst in Ruhe** — er entfernt nur
  PiPortal-eigene Teile, nicht deine VPN-Mitgliedschaft.

---

## Datenschutz / Sicherheit

Im Repo liegen **keine** Keys, Server-URLs oder Kontodaten. Der Preauth-Key ist
Einweg-Material und läuft ab; die Steuer-URL gibst nur du bei `tailscale up` an.
PiPortal installiert den Client, entscheidet aber nie, mit welchem Netz er sich
verbindet — das bleibt vollständig bei dir.
