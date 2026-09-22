🇬🇧 English · **[🇩🇪 Deutsch](README.de.md)**

# PiPortal

**A mini computer in the shape of a USB stick that you simply plug into a PC — and that instantly appears as a network and a small drive, without installing anything.**

![PiPortal – a Raspberry Pi stepping through a portal](images/piportal-hero.jpg)

---

## What is this, exactly?

PiPortal turns a tiny **Raspberry Pi Zero 2 W** (fitted with an adapter that lets it plug straight into a USB port) into a full-fledged little Linux computer in the form factor of a chunky USB stick.

When you plug it into a PC, two things happen at once:

- The PC recognizes it as a **network adapter** — so you can log into the little machine from a terminal and control it, with no extra cable needed.
- The PC shows a **small drive** — a "signpost" that points to a protected file area you use to exchange files securely.

The clever part: the stick has its **own internet over Wi-Fi** (e.g. your phone's hotspot). It uses that uplink for itself and never touches the host's network — so it puts no load on the PC's network or internet connection, and the PC's own connection stays completely untouched.

The whole thing is meant to be a **mobile Swiss Army knife for tech enthusiasts and admins**: a sealed-off work environment you can carry anywhere — for example, to run development and AI tools without touching the actual PC.

---

## What can PiPortal do?

- **Plug in and go** — no driver, no installation, no admin: the drive needs none, and the network adapter binds **driverlessly on Windows 11** (via NCM) as well as on Windows 7–10 (automatic RNDIS fallback). The right one is picked automatically (`NET_MODE=auto`).
- **Its own internet** — the stick connects over Wi-Fi to its own network (router or phone hotspot) and keeps the connection even when you move to another room.
- **Clean separation** — internet traffic deliberately runs only over the stick's Wi-Fi, never over the PC. The PC's connection stays completely unaffected.
- **Secure file exchange** — instead of a writable USB drive (which can get corrupted when accessed simultaneously), there's a read-only "signpost" and a real, password-protected network folder.
- **Ready for demanding tasks** — despite just 512 MB of RAM, clever memory optimization keeps even demanding tools running stably.
- **Its own command center** — the `piportal` command shows the system state at a glance, switches Wi-Fi networks, or updates the whole system — and it works even from the PC over the USB connection.
- **One click, fully set up** — an installer configures everything automatically and can be safely re-run at any time.

---

## Requirements (hardware)

- **Raspberry Pi Zero 2 W**
- **GeeekPi USB dongle adapter** (makes the Pi plug straight into a USB-A port and powers it through it) — **optional**: a plain **USB-OTG cable** on the data port works too
- **microSD card** (16 GB is enough; from 64 GB up you automatically get more swap space)
- a **Wi-Fi network** the Pi can connect to (router or phone hotspot)

![PiPortal – top side with heatsink, GPIO header and USB-A plug](images/piportal-oben.jpg)

![PiPortal – top side from another angle, USB plug facing left](images/piportal-unten.jpg)

The USB-A plug sits on the Pi's **data port** (not the power-only port), so data and power run through the same socket. For continuous operation under load, you can additionally connect the second micro-USB port (`PWR IN`) to a power bank.

![PiPortal – close-up of the connector side: mini-HDMI, the USB data port, PWR_IN, and the inserted microSD card, with the finned heatsink above](images/piportal-detail.jpg)

---

## Installation

> **Full step-by-step guide** (requirements, DietPi preparation, Wi-Fi model, dependencies, verification): [`docs/INSTALL.md`](docs/INSTALL.md). Below is the short version.

### 1. Prepare the operating system

1. Download **DietPi** (a particularly lean Raspberry Pi Linux) from [dietpi.com](https://dietpi.com/) and write it to the microSD card using the [Raspberry Pi Imager](https://www.raspberrypi.com/software/) or Balena Etcher.
2. Before the first boot, on the SD card **enable Wi-Fi** in the `dietpi.txt` file and enter your **credentials** in `dietpi-wifi.txt`, so the Pi goes online right away. SSH is enabled by default on DietPi.
3. Insert the SD card into the Pi, plug the Pi into the USB port, and wait for the first boot (DietPi sets itself up on first boot — this takes a few minutes).

### 2. Connect to the Pi

From the PC via SSH (Windows already ships with `ssh`):

```bash
ssh dietpi@<Pi-IP>
```

The IP is shown in your router or can be reached via `dietpi.local`.

### 3. Set up PiPortal

```bash
# Get the repo onto the Pi
git clone https://github.com/Smilez1985/PiPortal.git
cd PiPortal

# Create your own settings (SMB user/password …)
cp config/piportal.conf.example config/piportal.conf
nano config/piportal.conf

# Start the installer
sudo ./install.sh
```

> **Wi-Fi normally does NOT belong in this file.** Your networks are managed by DietPi (step 1 / later `dietpi-config`); PiPortal automatically uses **all** networks configured there. Leave the Wi-Fi fields in `config/piportal.conf` **empty** by default — only fill in SSIDs if PiPortal should manage Wi-Fi on its own (which then replaces the existing configuration). Details: [`docs/INSTALL.md`](docs/INSTALL.md).

The menu guides you through all the steps. Then reboot once:

```bash
sudo reboot
```

### 4. Use it on the PC

Plug in the stick and wait ~30 seconds. Windows automatically detects the network adapter and shows the **PIPORTAL** drive with a shortcut to the protected file folder. Terminal access:

```bash
ssh dietpi@10.10.0.1
```

Or double-click `connect-piportal.cmd` on the PIPORTAL drive.

---

## The `piportal` command center

After installation, the `piportal` command is available on the Pi — usable from the PC too over the USB connection, even when there's currently no Wi-Fi:

| Command | Effect |
|---|---|
| `piportal --status` | Everything important at a glance: IP addresses, uptime, CPU temperature, memory, connected PC, services. |
| `piportal --wifi-switch` | Menu for switching Wi-Fi networks (e.g. home network → phone hotspot). |
| `piportal --wifi-switch next` | Switches directly to the next configured Wi-Fi network. |
| `piportal --update` | Update the system and reboot (with `-y`, no confirmation prompt). |
| `piportal --help` | Overview of all commands. |

Handy shortcuts: `cls` / `clean` clear the screen, `cd..` navigates up, `pp` = `piportal`.

---

## Technical appendix

<details>
<summary>For those who want the full details — click to expand</summary>

### Architecture

PiPortal builds a **configfs/libcomposite USB composite gadget** (single-config, Windows-compatible):

| Function | Purpose | Host view |
|---|---|---|
| **NCM / RNDIS** (auto, MS-OS descriptors) | USB networking, driverless (inbox driver) | Win 11 → NCM; Win 7–10 → automatic RNDIS fallback |
| **Mass Storage** (read-only FAT) | Signpost to the SMB share | all |

File exchange runs over **hardened SMB** (`\\10.10.0.1\PiPortal`, SMB2+/SMB3, no guest). dnsmasq hands the PC an address **without** hijacking its internet gateway.

### Network topology

```
   Windows PC                Pi Zero 2 W (PiPortal)              Uplink
  ┌───────────┐   USB       ┌──────────────────────┐   Wi-Fi  ┌──────────┐
  │  USB NIC  │◄───────────►│ usb0  10.10.0.1/24    │          │ Router / │
  │ 10.10.0.x │  DHCP from Pi│ (DHCP server, no GW) │          │ phone AP │
  │           │             │ wlan0 ── DHCP client ─┼─────────►│ Internet │
  │  \\10.10.0.1\PiPortal ──┼─► SMB (hardened)      │          └──────────┘
  └───────────┘             └──────────────────────┘
```

### Installation phases (idempotent, repeatable at any time)

Backup → hostname → swap/zram → USB networking & DHCP → boot tuning → Wi-Fi roaming →
USB gadget → SMB portal → CLI → extras. Undo with `sudo ./uninstall.sh`.

### Memory optimization

SD swapfile staggered by card size (≥64 GB → 16 GB, ≥32 GB → 8 GB …) plus **zram**
(compressed swap in RAM, ~75% of memory). RAM disk (`/tmp`, `/var/log`) via
DietPi-RAMlog.

### Security & secrets

No secrets in the repo — Wi-Fi names, passwords, and tokens live only in the local,
git-ignored `config/piportal.conf`. SMB is hardened (SMB2+/SMB3, no guest access, only
on `usb0`). The signpost volume is read-only and contains no credentials.

Details on the architectural decisions: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md). The full
what/how/why of the live bring-up and its root-cause fixes: [`docs/DESIGN_NOTES.md`](docs/DESIGN_NOTES.md).

</details>

---

## Project structure

```
PiPortal/
├── install.sh / uninstall.sh   · One-click installer & rollback
├── config/                     · central configuration (template with placeholders)
├── lib/ · modules/ · assets/   · installer building blocks, scripts, CLI, portal content
├── docs/                       · installation, CLI, architecture, design, security, tailscale & roadmap docs (EN/DE)
└── images/                     · photos of the device
```

## Security by design

PiPortal is a **defensive** tool, not an attack device — and it is built to make misuse harder:

- The installer **refuses to run on pentest distributions** (Kali, Parrot, …) as its very first check.
- It hands the host **no gateway and no DNS** and never enables IP forwarding — it cannot tunnel the host's traffic.
- The signpost drive is **read-only**; the real share needs a **username and password** (no guest access).
- **No secrets** ship in the repo — every credential is set up at install time.

Full rationale and the dual-use disclaimer: [`docs/SECURITY.md`](docs/SECURITY.md). Planned directions: [`docs/ROADMAP.md`](docs/ROADMAP.md).

## Responsible use

PiPortal is a **transparent** administration and development tool. It presents itself
openly as a network adapter and a drive — it injects no keystrokes, runs nothing
automatically on the host, hides nothing, and leaves no payload behind. What happens is
always initiated by the person operating it.

Like any capable networking tool — a laptop, `nmap`, SSH, or a phone hotspot — it can be
misused. That responsibility lies with the user, not the tool:

- Use it only on **your own devices**, or with the **explicit permission** of the owner.
- Accessing computers, networks, or data without authorization is **illegal** in most
  jurisdictions and wrong everywhere.
- You alone are responsible for how you use it.

PiPortal is deliberately **not** designed as a covert-access or attack device, and it is
not intended to be turned into one. A tool is neutral; only actions can be harmful.

---

## License

MIT — see [`LICENSE`](LICENSE).
