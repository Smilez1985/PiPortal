🇬🇧 English · **[🇩🇪 Deutsch](INSTALL.de.md)**

# PiPortal — Installation Guide

This guide takes you from a blank microSD card to a fully working PiPortal. It has two clearly separated parts: **Part A** is preparing the operating system (DietPi) — the user does this *before* PiPortal enters the picture. **Part B** is the idempotent PiPortal installer, which handles the rest.

One thing to get straight up front, because it is easy to confuse: whenever this guide says the **"PiPortal config"**, it always means the file **`config/piportal.conf`** in the repo — **not** `dietpi-config`. You set up Wi-Fi in DietPi (Part A), not in the PiPortal config.

---

## Requirements

**Hardware**

- **Raspberry Pi Zero 2 W** (the **WH** variant ships with the header pre-soldered — handy, but not required).
- **microSD card** (16 GB is enough; from 64 GB up, PiPortal automatically provisions more swap).
- A way to get the Pi into a **USB-A port** on the PC: the **GeeekPi USB dongle adapter** (plugs the Pi straight into the port and powers it) — **or**, with no adapter at all, a plain **USB-OTG cable** from the Pi's data micro-USB to the PC. The adapter is convenient but optional.
- A **Wi-Fi network** the Pi can join (a router and/or a phone hotspot).

**Software / skills**

- A Windows PC (10/11) with the built-in OpenSSH client (default).
- Basic SSH and editing a text file on the Pi (`nano`).

All **package dependencies** are installed by the PiPortal installer itself (see below) — you do not need to install anything by hand on the Pi beforehand, other than a working, internet-connected DietPi.

---

## Part A — Prepare the operating system (DietPi)

This part is not PiPortal itself, but it is the foundation. Order:

1. **Write the DietPi image to the microSD.** Get the image from [dietpi.com](https://dietpi.com/) and write it with the [Raspberry Pi Imager](https://www.raspberrypi.com/software/) or Balena Etcher.
2. **Set up Wi-Fi before the first boot.** On the freshly written card (boot partition), enable Wi-Fi in `dietpi.txt` (`AUTO_SETUP_NET_WIFI_ENABLED=1`) and enter your credentials in `dietpi-wifi.txt`. SSH is enabled by default on DietPi.
3. **Insert the microSD into the Pi Zero 2 W(H).**
4. **Connect the Pi to the PC** — either through the GeeekPi USB adapter or via a USB-OTG cable on the data port. On the very first boot DietPi sets itself up (a few minutes; a reboot along the way is normal).

> **Multiple Wi-Fi networks / adding more later.** DietPi is and remains the source of your Wi-Fi networks. You can add more at any time — cleanest via `dietpi-config` → *Network Options: Adapters* → *WiFi*, or directly in `/etc/wpa_supplicant/wpa_supplicant.conf`. PiPortal uses **all** networks configured there (more on this below). In this project it is typically two: the home Wi-Fi and a phone hotspot as a fallback.

If you then want to connect from the PC (still without PiPortal), use SSH over the Pi's Wi-Fi IP (from your router, or via `dietpi.local`):

```bash
ssh dietpi@<pi-wifi-ip>
```

---

## Part B — Set up PiPortal

On the running Pi, connected to Wi-Fi:

```bash
# 1. Get the repo onto the Pi (git clone or copy an archive)
cd ~/PiPortal

# 2. Create your own settings
cp config/piportal.conf.example config/piportal.conf
nano config/piportal.conf

# 3. Run the installer (interactive menu) …
sudo ./install.sh
# … or without the menu:
sudo ./install.sh --all --non-interactive
```

Reboot once afterwards so the USB gadget overlay takes effect:

```bash
sudo reboot
```

The installer is **idempotent**: re-running it over an existing install changes only what needs changing. Everything can be undone with `sudo ./uninstall.sh` (Wi-Fi access, SAE hardening and SSH are deliberately preserved).

### What belongs in the PiPortal config (and what doesn't)

`config/piportal.conf` is gitignored and holds your individual values — among them the SMB user, the SMB password and **optionally** Wi-Fi details. More on Wi-Fi in a moment; the key point: **leave the Wi-Fi fields empty by default**, because DietPi already manages Wi-Fi.

### Dependencies (installed automatically)

The installer pulls via `apt` only what is missing: `dnsmasq`, `wpasupplicant`, `iw`, `samba` + `samba-common-bin`, `dosfstools`, `mtools`, `avahi-daemon`, `gettext-base`, `zram-tools`. For the **optional** AI lab (Claude Code CLI, off by default) it adds `curl`, `ca-certificates` and `nodejs`. The only prerequisite is a working internet connection on the Pi (i.e. the Wi-Fi set up in Part A).

---

## The Wi-Fi model (important)

PiPortal runs **hybrid**, and the default is deliberately "hands off the OS":

- **Default — DietPi manages the networks.** If you leave the Wi-Fi fields in `config/piportal.conf` **empty** (as shipped), the installer does **not** touch `wpa_supplicant.conf`. Your DietPi-configured networks stay untouched, and the roaming service uses **all** of them — whether one, two or five. A network added later in DietPi is picked up automatically; nothing needs to be redone in PiPortal.
- **Order / preference — via `priority=` in the OS.** Which network is preferred is set per network block in `wpa_supplicant.conf` as `priority=<number>` (higher = preferred), e.g. home network `priority=100`, hotspot `priority=1`. `wpa_supplicant` connects to the highest-priority network in range. The PiPortal roaming service derives its "home network" (for the *active* switch-back once it is in range again) **automatically from the highest OS `priority`** — live, without copying anything into the PiPortal config. Add a higher-priority network in DietPi and it becomes the new home on its own. (`WIFI_HOME_SSID` in `config/piportal.conf` remains an optional override if you want to set the preference manually — empty = the OS decides.)
- **Networks survive reinstall/uninstall**, because they live in the OS (`wpa_supplicant.conf`) — the uninstaller explicitly protects this file so the Pi stays reachable over Wi-Fi and SSH.
- **Optional — driven by the PiPortal config.** If you fill in SSIDs in `config/piportal.conf` (`WIFI_HOME_SSID` / `WIFI_HOTSPOT_SSID`), the installer writes a `wpa_supplicant.conf` from exactly those profiles (home preferred, hotspot as fallback) and **replaces** the previous content — a backup is taken automatically first. This variant is for setups where PiPortal should manage Wi-Fi on its own. If you want "use what's there and adapt", leave the fields empty.

Practical advice: set up Wi-Fi in DietPi (the native method, `dietpi-config`) and leave the PiPortal config's Wi-Fi empty. That keeps DietPi as the single source of truth for Wi-Fi, and you add more networks there whenever you like.

---

## Using it on the PC

Plug the stick in, wait ~30 seconds. Windows recognizes the network adapter automatically (**driverless** via NCM on Windows 11, RNDIS fallback for Windows 7–10) and shows the read-only **PIPORTAL** drive with the signpost files (`LIESMICH.txt`, `readme.txt`, `README.md`) plus a shortcut to the protected network drive.

- **Open the network drive:** in Explorer, `\\10.10.0.1\PiPortal`, or double-click `PiPortal-Netzlaufwerk.url`. Enter the user name as `10.10.0.1\<user>`.
- **Set the password (first time) / reset it (if forgotten):** double-click `SMB-Passwort.vbs` — the same tool detects which one is needed.
- **Terminal:** `ssh <user>@10.10.0.1`, or double-click `connect-piportal.cmd`.

The SMB user name is not hardcoded: the installer takes it from `config/piportal.conf` (`SMB_USER`) or — if left empty — derives it from the OS (the non-root login that started the installer; never root).

---

## Verify

On the Pi:

```bash
piportal --status
```

shows a compact view of IPs, uptime, CPU temperature, RAM/swap and the state of the services (gadget, dnsmasq, Samba, Wi-Fi roaming). On the Windows PC, success is visible as soon as the **PIPORTAL** drive appears and `\\10.10.0.1\PiPortal` opens after sign-in.

---

## Uninstall

```bash
sudo ./uninstall.sh            # stop services, restore the latest backup
sudo ./uninstall.sh --purge    # additionally remove PiPortal files/share
```

Wi-Fi access, the SAE/WPA3 hardening and SSH are preserved in both cases — the Pi stays reachable.

---

For deeper background: architecture decisions in [`ARCHITECTURE.md`](ARCHITECTURE.md), the full what/how/why of the live bring-up in [`DESIGN_NOTES.md`](DESIGN_NOTES.md), security in [`SECURITY.md`](SECURITY.md).
