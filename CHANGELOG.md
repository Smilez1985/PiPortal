🇬🇧 English · **[🇩🇪 Deutsch](CHANGELOG.de.md)**

# Changelog

All notable changes to PiPortal. Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versioning per [SemVer](https://semver.org/).

## [1.0.0] — 2026-09-22

First complete, hardware-verified release. Live-tested on Windows 11: the RNDIS adapter, the `PIPORTAL` read-only drive, a DHCP lease on `10.10.0.x`, and the hardened SMB share all come up, while the host keeps its own internet and SSH over `usb0` stays available.

### Added
- **PiPortal CLI** (`/usr/local/bin/piportal`, module 45): `--status` (compact overview:
  IPs, uptime/load, CPU temp, RAM/swap/zram, connected host, services – without htop),
  `--wifi-switch` (menu / `next` / targeted ID for switching Wi-Fi, e.g. home network→hotspot,
  also controllable from the host via USB-SSH), `--update` (dietpi-update + apt upgrade + reboot).
  Convenience aliases `cls`/`clean` (clear screen), `pp`, `ppstatus`.
- **Module 15 (boot tuning)**: hard-sets `AUTO_SETUP_BOOT_WAIT_FOR_NETWORK=0` and
  disables `systemd-networkd-wait-online` – fast boot, no hangs in Wi-Fi AP/
  hotspot mode. Reproducible on fresh SD cards.
- **UDC wait loop in the gadget script**: actively waits for the USB controller at
  boot (dwc2 loads asynchronously) and binds with retry – makes the first configfs start
  after the reboot timing-safe.
- **g_multi migration in module 30**: archives the old `/pi-usb-drive.img` to
  `/srv/piportal/legacy/` and removes orphaned `g_multi` entries from `/etc/modules`.
- **Module 01 (hostname)**: sets the hostname (default `PiPortal`) idempotently via
  `/etc/hostname`, `/etc/hosts` and `hostnamectl`. Config variable `PIPORTAL_HOSTNAME`.
- **README section "Migration from an existing g_multi setup"**.
- **Module 05 (swap & zram)**: sets up the SD swapfile based on SD card size
  (≥64 GB→16 GB, ≥32 GB→8 GB, ≥16 GB→4 GB, otherwise 2 GB) via DietPi's
  `dietpi-set_swapfile`, capped to the free space. Ensures zram
  (compressed RAM swap, ~75% RAM) and sets `vm.swappiness`. Idempotent:
  rebuilds the swapfile only on a relevant size deviation. New config variables
  `SWAP_MODE`, `SWAP_LOCATION`, `SWAP_RESERVE_MIB`, `SWAPPINESS`, `ENABLE_ZRAM`,
  `ZRAM_PERCENT`.
- **Consolidated documentation**: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) verified against the
  shipping code (single source of truth) and [`docs/DESIGN_NOTES.md`](docs/DESIGN_NOTES.md) added — the
  full what/how/why of the live bring-up and its root-cause fixes. Both bilingual (EN/DE).
- **OS install guard** (`assert_os`, the first check in `install.sh`, before the root check): refuses to
  run on pentest distributions (Kali, Parrot, …) via an `/etc/os-release` blocklist. All other systems
  are allowed — no single-OS lock-in.
- **Security & roadmap docs**: [`docs/SECURITY.md`](docs/SECURITY.md) (Security-by-Design barriers +
  dual-use disclaimer) and [`docs/ROADMAP.md`](docs/ROADMAP.md) (planned admin toolbox / Cowork
  integration, NCM profile, publish cycle). Both bilingual (EN/DE).
- **Update routine** (`tools/update/`, installed by module 47): modular, fail-safe maintenance
  (`system` → `harden_wlan` → `piportal` self-update → `claude`, each strictly "if exist"). No auto-update
  at boot — a login prompt asks when a run is **due** (default every 14 days) and, if you run it, whether
  to auto-reboot afterwards.
- **WLAN SAE hardening** (`harden_wlan` + live guard): protects against the `brcmfmac` WPA3/SAE regression
  (`feature_disable=0x2282000` in `cmdline.txt` + modprobe.d) so an OS update's reboot cannot kill Wi-Fi on
  a WPA2/WPA3-transition access point.
- **Network-share credential tools**: `piportal --smb-passwd` (first-time setup / password change, no data loss)
  and `piportal --smb-reset` (full reset incl. wipe), plus the Windows helpers `SMB-Passwort_setzen.vbs` and
  `SMB-Passwort_vergessen.vbs` on the signpost drive. Authorization is the SSH login. `LIESMICH.txt` is now
  also placed on the share (H:) and notes the Windows login form (`10.10.0.1\dietpi`).
- **mDNS via avahi** so `\\PiPortal.local` resolves from the host (NetBIOS stays off). Hostname set to
  `PiPortal` by module 01.
- **`piportal --poweroff`**: clean shutdown (`sync` + `poweroff`) so the stick can be unplugged safely
  without risking SD-card corruption.
- **`piportal start claude`**: launches the Claude Code CLI, installing it (latest, no pin) on first use.
- **Gadget default corrected** to `portal.img` (was a stale `.iso`) so the read-only signpost survives a reboot.

### Fixed
- **Windows host received no DHCP address (ended up on APIPA 169.254.x.x):** The
  dnsmasq options 119/121/249 were configured with an empty value in order to
  suppress them – but dnsmasq sends such options (which it does NOT send on its own)
  as a **0-byte option**, causing Windows to discard the entire DHCP OFFER (DISCOVER/OFFER,
  but never REQUEST/ACK). The three lines were removed (only 3/6/15 are suppressed);
  additionally `dhcp-authoritative` was set. Windows now cleanly gets a 10.10.0.x IP.
- **RNDIS network adapter did not bind under Windows (driver cache):** After many
  test reconnects, Windows had negatively cached the USB identifier `1d6b:0104` and no
  longer re-evaluated the MS OS descriptors. Product ID changed to `0xa4ac` → Windows sees
  a fresh device and loads "Remote NDIS Compatible Device" automatically. os_desc/compat IDs
  were correct the whole time.
- **Windows bound no gadget drivers (no RNDIS adapter, no drive):** The cause was
  a multi-config gadget (RNDIS + ECM). Windows has poor support for multiple USB configurations
  and then loads no function drivers. Default is now **single-config (RNDIS
  + Mass Storage only)**, `ENABLE_ECM=0`. ECM only for Linux/macOS hosts.
- **FAT signpost image too small:** 4 MB fails as FAT16 ("too small") → 16 MB.
- **Gadget teardown did not remove the os_desc config link** (broken `[ -L glob ]` logic).
  On `restart`, the rebuild failed with `ln: … Invalid argument`. Teardown now cleans up
  os_desc symlinks correctly → gadget is re-run/restart-safe.
- **Portal LUN could not be bound (kernel 6.18, error 525):** The RPi kernel 6.18
  refuses to bind an ISO file in `cdrom=1` mode (empirically verified). Switched
  from CD-ROM/ISO9660 to a **read-only FAT image + `ro=1`** – the Windows-compatible
  signpost stick. `ro`/`removable` are now correctly set BEFORE `file`. Module 40 now builds
  the image with `mkfs.vfat` + `mtools` instead of `xorriso`. Config: `PORTAL_IMAGE` → `.img`.
- **Fresh installation (empty SD, no g_multi):** Module 30 incorrectly attempted a
  live start of the gadget, even though the `dwc2` overlay only takes effect after the reboot
  (no UDC present yet). The live start is now skipped and correctly points to the reboot.
  `install.sh` now also prints the reboot notice in the fresh-install case (no longer
  only when g_multi is active).
- **Complete self-sufficiency for dependencies:** `wpasupplicant`/`iw` are now ensured in
  module 20 via `ensure_pkg` (previously they were only assumed to be present).
- **Account creation:** Module 40 creates the Unix user if `SMB_USER` does not exist
  (`smbpasswd -a` requires it) – previously a hard error with a differing username.

## [0.1.0] — 2026-08-03

First structured version. Migrates the manually developed (via Google Search AI) initial setup into a reproducible, idempotent repo.

### Added
- **One-click installer** (`install.sh`) with interactive menu, `--only`/`--all`/`--non-interactive` flags.
- **Modular phases** (`modules/00_backup` … `50_extras`), each idempotent (`if not exist`).
- **lib/common.sh** — shared helpers: colored logging, idempotency functions, backup routine, config loader.
- **configfs/libcomposite gadget** (`assets/gadget/piportal-gadget.sh`) as a replacement for legacy `g_multi`: RNDIS (with MS OS descriptors) + CDC-ECM + Mass Storage (CD-ROM, read-only). Deterministic MAC addresses derived from `machine-id`. Clean teardown → re-run-safe.
- **systemd units** for the gadget and Wi-Fi roaming (replacing the fragile `custom.sh` in DietPi autostart).
- **dnsmasq fix**: suppresses gateway (option 3) and DNS (option 6), `bind-dynamic`, `port=0` — the Windows host keeps its internet.
- **SMB portal** (`modules/40_portal_smb.sh`): Samba hardened (SMB2+/SMB3, no guest, single user, `usb0` only) + CD-ROM signpost image with `LIESMICH.txt` and a `.url` shortcut.
- **Windows helper** `connect-piportal.cmd` (uses Windows' built-in `ssh.exe`, no PuTTY needed).
- **uninstall.sh** — rollback from the most recent automatic backup.
- **Documentation**: current-state recon, corrected roadmap, best-practice analysis (E1–E3) with sources, device photos.

### Changed (compared to the manual initial setup)
- Gadget switched from legacy `g_multi` to **configfs/libcomposite**.
- Wi-Fi roaming switched from an infinite loop in autostart to a **systemd service** with restart policy.
- Signpost storage switched from a writable 50 MB FAT to a **read-only CD-ROM (ISO9660)** — eliminates the data corruption risk.
- All secrets (SSIDs, PSKs) moved out of scripts into the gitignored `config/piportal.conf`.

### Security
- Secret-scan gate planned before every repo commit; `.gitignore` protects local configuration and backups.
