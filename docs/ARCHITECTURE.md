🇬🇧 English · **[🇩🇪 Deutsch](ARCHITECTURE.de.md)**

# PiPortal — Architecture Decisions

This document explains the three core architecture decisions behind PiPortal, a Raspberry Pi Zero 2 W that presents itself to a host PC as a composite USB gadget (network + storage). Each decision is stated with a short rationale and links to the sources that back it.

**The code is the single source of truth.** Where the original plan and the shipping implementation diverged during live bring-up on real hardware, this document describes what the code actually does; the reasoning behind each change is recorded in [`DESIGN_NOTES.md`](DESIGN_NOTES.md).

The USB-side LAN uses the fixed address range `10.10.0.x` (the Pi is `10.10.0.1` on `usb0`). This is intentional and public.

---

## Decision 1 — Gadget technique: configfs / libcomposite (not legacy `g_multi`)

**Decision: build the gadget with configfs/libcomposite instead of the legacy `g_multi` kernel module.**

Rationale:
- For **Ethernet + mass storage at the same time**, configfs is the intended, modern path. `g_multi` is legacy and has practically disappeared from current (2024–2026) guides.
- Only configfs enables **MS-OS descriptors** (needed for Decision 2) and **runtime LUN switching** (used in Decision 3 to hot-swap the signpost image).
- The Pi Zero 2 W kernel (6.18) fully supports `libcomposite`.

Implementation (see `assets/gadget/piportal-gadget.sh`, `modules/30_gadget.sh`):
- `dtoverlay=dwc2` in `config.txt` only switches on the USB-OTG controller — it does **not** build a gadget.
- Load `dwc2` + `libcomposite` early via `/etc/modules-load.d/piportal.conf`.
- Build the gadget as a **systemd oneshot** (`piportal-gadget.service`) that calls the gadget script with `up`.
- The device is a proper **IAD composite** (`bDeviceClass=0xEF`, `SubClass=0x02`, `Protocol=0x01`), vendor `0x1d6b`, product `0xa4ac`.
- **Idempotency:** every `up` first runs an explicit **teardown** (detach the UDC via `echo "" > UDC`, remove only the `os_desc` and config **symlinks**, then `rmdir` configs/functions/strings in reverse order). None of the public reference scripts are re-run-safe out of the box — that part is built on top, so `restart` and repeated installs are safe.
- **UDC wait/bind with retry:** `dwc2` loads asynchronously at boot, so the script waits up to ~10 s for a UDC to appear and then retries the bind — the first start after a reboot is timing-safe.
- **Interface order:** RNDIS is created and linked first so it occupies the first interfaces (Windows expects RNDIS at slot 0/1).

Why the official `rpi-usb-gadget` is not enough: it only offers `g_ether` (Ethernet-only), **no mass storage**, and is NetworkManager-based (this project uses ifupdown).

Sources:
- ohyaan — ConfigFS composite gadget (Ethernet + mass storage): https://ohyaan.github.io/tips/creating_a_usb_composite_multi-function_gadget_on_raspberry_pi_using_configfs/
- Ben Hardill — "Composite USB Gadgets" (canonical two-config pattern): https://www.hardill.me.uk/wordpress/
- thagrol — "USB Mass Storage Gadget – Beginner's Guide": https://github.com/thagrol/usb-gadget
- PIBSAS/pizero2wEth (Pi Zero 2 W, RNDIS + ECM): https://github.com/PIBSAS/pizero2wEth

---

## Decision 2 — Single-config RNDIS + MS-OS descriptors for Windows (CDC-ECM is an optional second config, off by default)

**Decision: ship a single USB configuration containing RNDIS (with MS-OS descriptors) + mass storage. CDC-ECM/NCM exist as an optional second config for Linux/macOS but are disabled by default (`ENABLE_ECM=0`, `ENABLE_NCM=0`).**

Rationale (goal: "works on as many *foreign* Windows PCs as possible, with no admin effort"):
- **RNDIS + os_desc** (`compat-id RNDIS`, `sub 5162001`, vendor code `0xcd`, `MSFT100`) is the **only** USB-Ethernet protocol with a no-install inbox driver across **Windows 7/8/10/11**. It binds on a fresh, unknown PC with no driver install and no admin rights.
- **Multiple USB configurations broke Windows in practice.** The original plan was a two-config gadget (config 1 = RNDIS for Windows, config 2 = CDC-ECM for Linux/macOS). On real hardware Windows bound **no** function drivers at all — neither the network adapter nor the drive appeared — because Windows has poor support for multi-config devices and then loads nothing. The shipping default is therefore a **single config** (RNDIS + mass storage). ECM/NCM remain in the script as an opt-in second config for Linux/macOS-only use.
- **NCM alone excludes Windows 10** (no inbox driver → manual driver selection requiring admin); even on Win11 it only auto-binds with an extra `WINNCM` os_desc. So NCM stays off by default.
- The Raspberry Pi **driver `.exe`** requires admin rights + installation on the target PC → contradicts the "leave no trace on foreign PCs" goal.

Product ID note: the identifier is `0x1d6b:0xa4ac`. An earlier value (`…:0104`) had been **negatively cached** by a test PC after many reconnects, so Windows stopped re-evaluating the MS-OS descriptors; a fresh product ID makes the host treat it as a new device and load "Remote NDIS Compatible Device" automatically. The os_desc/compat IDs were correct throughout — see [`DESIGN_NOTES.md`](DESIGN_NOTES.md).

Future direction (documented, not a roadmap item): the industry trend points to **NCM** (Linux disabled its RNDIS host driver in 2023 as insecure; Microsoft recommends NCM). RNDIS is the **pragmatic** 2026 choice for maximum foreign-Windows reach, not the future-proof one.

Sources:
- MS-OS descriptor / RNDIS ordering: https://learn.microsoft.com/en-us/answers/questions/474108/does-rndis-need-to-be-listed-as-the-first-function
- NCM auto-bind issue (field report): https://forum.beagleboard.org/t/pocketbeagle-2-usb-network-access-from-windows-usb-ncm-driver/42001
- Linux disables the RNDIS host driver: https://itsfoss.gitlab.io/post/linux-is-all-set-to-disable-microsofts-rndis-drivers/
- postmarketOS moves to NCM: https://postmarketos.org/edge/2023/10/29/rndis-ncm/

---

## Decision 3 — Read-only FAT16 signpost image + hardened SMB (instead of writable storage)

**Decision: the mass-storage LUN is a pure signpost served read-only; all real data transfer goes exclusively over hardened SMB.**

Rationale:
- **A read-only medium removes the corruption risk.** The original setup exposed a writable 50 MB FAT image that both the PC and the Pi could write at once — with no coherency channel between the host cache and the Pi's loop mount, that risks corruption. Serving the LUN read-only (`ro=1`) means Windows only ever reads it; user data never travels over the mass-storage device at all.
- **Read-only FAT16, not CD-ROM/ISO9660.** The plan was to emulate a CD-ROM (`cdrom=1`, ISO9660). On the Pi's **kernel 6.18** that fails: binding an ISO file in `cdrom=1` mode is rejected with **error 525** (empirically verified). The working, Windows-compatible path is a small **FAT16 image with `ro=1` + `removable=1`** — Windows treats it as a write-protected USB stick and writes no `System Volume Information` / `$RECYCLE.BIN` / indexer junk to it.
- **`ro` and `removable` are set before `file`.** The kernel only accepts these LUN attributes while no backing file is bound, so the script writes `ro=1` and `removable=1` first, then the image path.
- **16 MB image.** FAT16 needs enough clusters; a 4 MB image fails to format as "too small". 16 MB is the smallest broadly Windows-compatible size and is ample for the signpost. Built without mounting via `mkfs.vfat -F 16` + `mtools` (`mcopy`).
- Contents: `LIESMICH.txt` (how to reach the share), a `.url` shortcut to `\\10.10.0.1\PiPortal`, and the `connect-piportal.cmd` SSH helper.

Runtime image swap: because the LUN is `removable=1`, a rebuilt image can be hot-swapped into a running gadget by writing an empty string and then the new path into `lun.0/file` — `modules/40_portal_smb.sh` does exactly this when it regenerates the image.

AutoRun reality: AutoRun on removable drives has been **dead since 2011 (KB971029)** — `autorun.inf` starts nothing. The design assumes the user opens the drive and clicks the `.url` manually; the volume just gets a clean label (`PIPORTAL`).

Access paths to the SMB share (order shown in the signpost):
1. Fixed UNC path `\\10.10.0.1\PiPortal` (always reliable).
2. Hostname `\\PiPortal.local\PiPortal` (mDNS, usually works, not guaranteed).

SMB hardening (`smb.conf`, see `modules/40_portal_smb.sh`):
- `server min protocol = SMB2`, `client min protocol = SMB2`, `server max protocol = SMB3_11` (no SMB1); `server signing = mandatory`; `smb encrypt = required` only when `SMB_ENCRYPT=1` (CPU cost on the Zero 2 W).
- `security = user`, `map to guest = Never`, `restrict anonymous = 2`, `guest ok = no`, `valid users = <smb-user>`.
- `interfaces = lo usb0 10.10.0.1` + `bind interfaces only = yes`, `smb ports = 445`, `disable netbios = yes` (no NetBIOS/139).
- The config is validated with `testparm` before the service is restarted.

Sources:
- Kernel Mass Storage Gadget (ro/cdrom/removable): https://docs.kernel.org/usb/mass-storage.html
- gadget_cdrom (swap logic): https://github.com/tjmnmk/gadget_cdrom
- AutoRun is dead: https://learn.microsoft.com/en-us/answers/questions/4189978/is-autorun-inf-on-a-removable-drive-disabled-on-wi
- SMB hardening Win11 / Server 2025: https://techcommunity.microsoft.com/blog/filecab/smb-security-hardening-in-windows-server-2025--windows-11/4226591

---

## Summary — the shipping architecture

A **configfs composite gadget** built by an idempotent systemd oneshot, exposing a **single USB configuration**:

1. **RNDIS** (with MS-OS descriptors, product `0x1d6b:0xa4ac`) → the Windows face, driverless on foreign PCs.
2. **Mass storage** as a **read-only FAT16 image** (`ro=1 removable=1`, 16 MB) → a visible signpost with a `.url` pointing to the SMB share.
3. **CDC-ECM/NCM** → an optional second config for Linux/macOS, **off by default** (multi-config breaks Windows driver binding).

The actual data transfer runs exclusively over **hardened SMB** on `usb0` (`10.10.0.1`). dnsmasq hands the Windows host a lease while suppressing gateway/DNS (options 3/6/15 empty) and deliberately **not** listing options 119/121/249 — dnsmasq would otherwise emit them as 0-byte options and Windows would discard the whole DHCP OFFER (landing on APIPA). The host keeps its own internet; SSH over `usb0` stays up. See [`DESIGN_NOTES.md`](DESIGN_NOTES.md) for how each of these was arrived at during live bring-up.
