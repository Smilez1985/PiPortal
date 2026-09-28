🇬🇧 English · **[🇩🇪 Deutsch](CHANGELOG.de.md)**

# Changelog

All notable changes to PiPortal. Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versioning per [SemVer](https://semver.org/).

## [1.4.0] — 2026-09-29 01:40 CEST

### Fixed
- **`write_file_if_changed()` could silently empty its target file.** The function wrote through
  `mktemp`, unchecked. If `TMPDIR` points at a non-existent directory — or the RAM disk is full —
  `mktemp` returns an empty path, `cat > ""` fails, and `install` is then handed an empty source:
  the target ends up blank. Among the files written this way are
  `/etc/wpa_supplicant/wpa_supplicant.conf` and **`/boot/firmware/cmdline.txt`**, where an empty
  file means the Pi no longer boots.

  The function now writes a sidecar file **next to the target** and renames it with `mv` — the
  same pattern the SAE hardening already used for `cmdline.txt`. No `/tmp` involved, no extra
  write cycle, and `mv` within one partition is atomic: a power loss mid-write leaves either the
  old or the new version behind, never a truncated one.

  An empty payload no longer replaces a non-empty file (almost always a broken pipeline upstream).
  Callers that mean it pass `--allow-empty`. Ownership of an existing target is preserved.

- **Module 30 now sanity-checks `cmdline.txt` before writing.** Removing the legacy `g_multi`
  tokens wrote the result unconditionally. If the transformation had produced an empty line or
  dropped `root=`, the device would not have booted. The module now verifies the line and takes a
  backup first — the same guard module 20 already applies to `wpa_supplicant.conf`.

### Changed
- **`piportal --update` now updates PiPortal itself, not the operating system.**
  It fetches the repo and runs the idempotent installer over it. Full maintenance —
  system packages, Wi-Fi hardening, PiPortal, optional software — moved to the new
  **`piportal --update-all`** (`-U`). Both drive the same modular routine in
  `tools/update/`; `--update` just selects the `piportal` module. Wanting a new
  PiPortal version should not force `apt upgrade` along with it.

### Added
- **Update channels via `UPDATE_CHANNEL`** in `piportal.conf`:
  `release` (default) pulls the highest published `vX.Y.Z` tag — devices in the
  field only receive states that were deliberately published. `main` follows the
  development branch. Tag selection sorts by version, so `v1.10.0` correctly beats
  `v1.2.0`. Switching back from a tag to `main` is handled; a dirty working tree
  aborts the update instead of being overwritten.
- **`tests/`** – shell test suites for `write_file_if_changed` (14 cases, including
  the broken-`TMPDIR` regression), the version stamp module and the channel logic
  (10 cases against a real git repo).

---

## [1.3.0] — 2026-09-29 00:45 CEST

### Added
- **`piportal --version` (alias `-V`)** – prints the installed version. The single source of
  truth is the `VERSION` file in the repo root; module 48 stamps it into
  `/etc/piportal/version` at install time, so the CLI can answer without the repo being present.
  If the file is missing (installation predates 1.3.0 or was copied by hand), the command says so
  and names the fix.
- **Module 48 – version stamp**, idempotent like every other phase:
  file missing → create · same version → leave untouched · different version → update.
  On an upgrade it calls `migrate_from()`, the designated place for changes that affect existing
  installations. A version bump must never break a running PiPortal — the installer handles the
  transition, not a release note telling people to reinstall.
  A downgrade is refused in `--non-interactive` mode and asks for confirmation otherwise.

### Fixed
- **`write_file_if_changed()` could silently truncate its target.** `mktemp` was called without
  checking its result. With `TMPDIR` pointing at a non-existent directory it returns an empty
  path, `cat > ""` fails, and `install` was then handed an empty source — the target file ended
  up blank. Now the call falls back to an explicit template and aborts if both attempts fail.

---

## [1.2.0] — 2026-09-22 15:35 CEST

### Added
- **CLI shortcut `piportal --tailscale-up` / `--tailscale-down`** (aliases `tsup`/`tsdown`):
  runs the long `tailscale up --login-server <URL>` as a one-liner and shows the tailnet IP + the
  phone-SSH command. The URL comes from `TAILSCALE_LOGIN_SERVER` in the **local, gitignored** config
  (the repo ships only the empty template — no foreign logins). The CLI reads the root-only config
  for this via `sudo` (config stays `0640`).
- **`docs/CLI.md` / `docs/CLI.de.md`** – cheat sheet of all `piportal` commands. A short version
  (`PiPortal-Befehle.txt`) also lives on the signpost drive and the share, for quick reference when
  you pick the PiPortal up again after months.
- **Module 55 – Tailscale client (opt-in, `ENABLE_TAILSCALE=1`, off by default)**: on request installs
  **only** the Tailscale client as preparation, **package-manager-agnostic** — DietPi via the catalog
  (`dietpi-software 58`), Arch/Alpine natively (`pacman`/`apk`), Debian/Ubuntu/Fedora/RHEL/openSUSE
  via the official Tailscale install script (correct vendor-repo path per `apt`/`dnf`/`yum`/`zypper`),
  otherwise the script as a fallback. **No onboarding**, **no** keys/URLs/data in the repo — signing in
  (`tailscale up …`) is up to the user.
- **Deliberately manual and non-persistent**: `tailscaled` runs (so `tailscale up` works), a boot hook
  (`piportal-tailscale-down.service`) leaves Tailscale **disconnected after every reboot**. It only runs
  after a manual `tailscale up …` and is off again after a reboot — which also prevents the subnet
  self-hijack when the PiPortal is on the home network.
- **`docs/TAILSCALE.md` / `docs/TAILSCALE.de.md`**: onboarding guide, making clear the feature requires
  a Tailscale account **or** a self-hosted Headscale server (with no server the opt-in stays 0). Covers
  the cloud/Headscale paths, manual reconnect, reaching the PiPortal from a phone via the **tailnet IP**
  (`100.64.x.x`, network-independent), the `--accept-routes` caveat for the on-LAN device
  (split tunnel ≠ exit node), and the DNS-rebind gotcha.

---

## [1.1.0] — 2026-09-22 06:41 CEST

Follow-up work after the first hardware release, all verified live on the device.

### Added
- **`piportal --publish`** + publish helper (`assets/gadget/piportal-publish.sh`): rebuilds the
  signpost image from the persistent signpost staging (`/srv/piportal/signpost`) and re-inserts it
  at the host cleanly via `forced_eject` — changed content appears **without unplugging**. Module 40
  uses the same helper (exactly one path, no duplicated logic).
- **Bilingual signpost**: an English `readme.txt` alongside `LIESMICH.txt`, plus a bilingual,
  collapsible `README.md` (DE/EN via `<details>`) on both the signpost drive and the share.
- **`docs/INSTALL.md` / `docs/INSTALL.de.md`** — a full installation guide (requirements, DietPi
  preparation, Wi-Fi model, dependencies, verification). The README install section was corrected
  accordingly (Wi-Fi model clarified, USB-OTG cable noted as an alternative to the GeeekPi adapter).

### Changed
- **Wi-Fi roaming derives the home network from the OS**: the roaming service now determines the
  preferred network (for the active switch-back) **live from the highest `priority` in
  `wpa_supplicant.conf`** instead of a fixed config value. The OS stays the single source of truth
  (networks, passwords, order); networks added/reordered in DietPi take effect on their own — no
  watcher, no overwrite. `WIFI_HOME_SSID` in the config remains an optional override.
- **SMB password — one tool for both cases**: `piportal --smb-passwd` detects the state itself
  (no password set → first-time setup with no data loss; already set → reset). The two former VBS
  files (`SMB-Passwort_setzen.vbs` / `SMB-Passwort_vergessen.vbs`) are merged into one
  `SMB-Passwort.vbs`; `--smb-reset` remains as an alias.
- **User name no longer hardcoded**: the signpost/Windows files use real variables
  (`${PP_USER}` / `${PP_IP}` / `${PP_SHARE}`) that the installer renders from the config via
  `envsubst`. `SMB_USER` is — if left empty in the config — derived from the OS or file path
  (`SUDO_USER` → `logname` → repo owner), never root. `gettext-base` added as a dependency.

### Hardening
- **Locale-independent**: `export LC_ALL=C.UTF-8` in all parsing scripts (installer, CLI,
  roaming/publish/net-detect helpers, updater) → deterministic parsing on English as well as German
  DietPi, no crash from localized tool output.
- **CRLF for Windows files**: the render step emits all signpost/share files with CRLF;
  `.gitattributes` extended with `*.vbs` and the portal texts (`LIESMICH.txt`, `readme.txt`). All
  shell scripts remain LF without BOM (verified).
- **shellcheck CI** (GitHub Actions) across all shell scripts as a lightweight regression guard.

---

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
- **NCM by default with automatic RNDIS fallback** (`NET_MODE=auto`): the Windows network face comes up as
  CDC-NCM — which binds **driverlessly on Windows 11** (verified live: silent adapter + DHCP lease, no admin)
  — and automatically falls back to RNDIS if the connected host doesn't accept NCM (Windows 7–10). Detector
  `piportal-net-detect` + `WINNCM` os_desc; single-config throughout. RNDIS is now opt-in/fallback, not the default.
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
