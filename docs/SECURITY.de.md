**[🇬🇧 English](SECURITY.md)** · 🇩🇪 Deutsch

# PiPortal — Sicherheit & verantwortungsvolle Nutzung

PiPortal ist ein **transparentes, defensives** Administrations- und Labor-Werkzeug. Es ist bewusst **kein** Angriffsgerät und so gebaut, dass eine Umgestaltung zu einem solchen bewussten, eigenverantwortlichen Aufwand erfordert. Dieses Dokument erklärt, was es von einem „Hacktool" unterscheidet, und listet die „Security by Design"-Barrieren auf, die tatsächlich im Code stecken — nichts hier ist bloß Absicht.

---

## Was PiPortal ist — und was nicht

**Einsatzzweck.** Ein mobiles Home Lab: eine abgeschottete Umgebung für Entwicklung und KI-Coding-Agenten (die Claude Code CLI ist optional installierbar, per Default aus) und ein portabler Werkzeugkasten für Administratoren. Der Fokus liegt auf **Isolation, nicht Infiltration** — es stellt eine *vom Host getrennte* Umgebung bereit und schützt den Host vor fehlerhaftem Code; es ist nicht darauf ausgelegt, in Fremdsysteme einzudringen.

**Keine Angriffswerkzeuge an Bord.** Anders als ein dedizierter Pentest-Dongle enthält PiPortal im Auslieferungszustand **keine Exploits, keine Schwachstellen-Scanner und keine automatisierten Angriffs-Skripte.** Es nutzt reguläre Linux-Kernel-Gadget-Unterstützung (`dwc2` + `libcomposite`/configfs) und Standarddienste (`dnsmasq`, Samba), um konkrete technische Probleme zu lösen — etwa Dateisystem-Korruption auf dem gemeinsamen Datenträger zu vermeiden — nicht, um etwas anzugreifen.

**Transparent per Design.** Es meldet sich offen als Netzwerkkarte und Laufwerk an. Es tippt keine Tastenanschläge ein, startet nichts eigenmächtig auf dem Host, verbirgt nichts und hinterlässt keine Payload. Was geschieht, wird immer von der bedienenden Person angestoßen.

---

## „Security by Design"-Barrieren (im Code belegbar)

1. **OS-Blacklist — Pentest-Distributionen werden abgelehnt.** Die allererste Prüfung des Installers (`assert_os` in `lib/common.sh`, noch vor der Root-Prüfung) liest `/etc/os-release` und **bricht auf Kali, Parrot und ähnlichen** Angriffs-Distributionen ab (Abgleich gegen `ID`/`ID_LIKE`). Alles andere ist erlaubt — es gibt keine Bindung an ein einziges OS. Wer das umgehen will, muss den Quelltext bewusst ändern.
2. **Kein Gateway zum Host + kein IP-Forwarding.** Die `usb0`-Interface-Config enthält keine Gateway-Zeile, dnsmasq drückt dem Host bewusst **kein** Default-Gateway und **keinen** DNS auf (Optionen 3/6/15 unterdrückt), und der Installer aktiviert **nirgends** `net.ipv4.ip_forward`. Der Pi kann den Traffic des Hosts also nicht ohne bewusste, manuelle Änderung über sein eigenes WLAN routen oder tunneln.
3. **Schreibgeschützter Wegweiser-Datenträger.** Das emulierte USB-Laufwerk wird für den Host **read-only** eingebunden (`ro=1`). Es kann nicht genutzt werden, um unbemerkt Dateien oder Schadsoftware *vom* Host über das Laufwerk auf den Pi zu kopieren.
4. **Authentifiziertes SMB, kein Gastzugang.** Der eigentliche Datenspeicher verlangt Benutzername und Passwort (`map to guest = Never`, `restrict anonymous = 2`, `valid users`). Das bloße Einstecken des Dongles gewährt keinen Zugriff auf Dateien.
5. **Keine hardcodierten Secrets.** Das Repository enthält keine Passwörter, API-Tokens oder privaten IP-Adressen. Jeder sensible Wert wird bei der Installation individuell eingerichtet.
6. **Die Netzwerkseite ist treiberlos — ein Usability-Merkmal, keine Sicherheitsbarriere.** NCM bindet auf Windows 11 ohne Admin, RNDIS auf Windows 7–10; PiPortal verlässt sich also *nicht* darauf, dass dem Host ein Treiber fehlt, um Missbrauch zu begrenzen. Die tatsächlich einschränkenden Barrieren sind die Punkte 1–5 oben.

---

## Dual-Use-Disclaimer

Wie jedes mächtige Netzwerkwerkzeug — ein Laptop, `nmap`, SSH oder ein Handy-Hotspot — lässt sich PiPortal missbrauchen. Diese Verantwortung liegt beim Nutzer, nicht beim Werkzeug:

- Nur an **eigenen Geräten** verwenden — oder mit **ausdrücklicher Erlaubnis** des Besitzers.
- Der Zugriff auf fremde Computer, Netzwerke oder Daten ohne Genehmigung ist in den meisten Rechtsordnungen **strafbar** und überall unrecht.
- Die bewusste Umgestaltung von PiPortal — etwa das Entfernen der OS-Blacklist, das Aktivieren von IP-Forwarding oder das Hinzufügen von Angriffswerkzeugen — ist ein bewusster Akt, der vollständig auf eigenes Risiko und in eigener Verantwortung geschieht. Der Autor übernimmt für solche Änderungen **keine Haftung**.

Ein Werkzeug ist neutral; schädlich sind nur Handlungen. PiPortal ist bewusst **kein** Werkzeug für verdeckten Zugriff oder Angriffe und soll auch nicht zu einem solchen umgebaut werden. Geplante Weiterentwicklungen stehen in [`ROADMAP.md`](ROADMAP.md).
