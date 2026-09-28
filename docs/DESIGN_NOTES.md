🇬🇧 English · **[🇩🇪 Deutsch](DESIGN_NOTES.de.md)**

# PiPortal — Design Notes (what, how, and why)

This document records the engineering story behind PiPortal: where the device started, what was planned, and — most importantly — the problems that only showed up on real hardware and how each one was solved. The three core architecture *decisions* live in [`ARCHITECTURE.md`](ARCHITECTURE.md); this file is the narrative and the root-cause log.

Throughout, the code is the single source of truth. Where an early plan and the shipping code disagree, the code won and this document explains why.

---

## 0. Origin

PiPortal began as a hand-written theory document, drafted with the help of a search assistant. That original file contained **secrets in cleartext** (a device password, internal IP addresses), so it is deliberately **not** part of this repo — it stays local and is excluded via `.gitignore`. Its technical substance was scrubbed, fact-checked against the live device and current sources, and rebuilt into this clean, reproducible project.

The goal: a Raspberry Pi Zero 2 W on a USB dongle that plugs into any PC and instantly offers a network adapter plus a small drive, with its own Wi-Fi uplink, changing nothing on the host — set up by one idempotent installer, with no secrets in the repo.

---

## 1. Starting point (the device as found)

A live recon over SSH established the ground truth before anything was changed. The device already did some things well — a static `usb0` IP as an update-safe drop-in, correct default routing (internet over Wi-Fi, not over USB), Wi-Fi roaming with priorities, a lean boot — but it also carried real problems:

- **Legacy `g_multi` gadget.** No MS-OS descriptors (Windows didn't auto-bind RNDIS), a forced ACM COM port (yellow bang in Device Manager), and no runtime LUN control.
- **Writable mass storage.** The `g_multi` LUN was read-write, so the PC and the Pi could write the same 50 MB FAT image at once — a data-corruption risk with no cache-coherency channel between the two.
- **dnsmasq hijacked the host.** The USB DHCP config sent the PC a default gateway and DNS, so the host could route its whole internet into the dead `usb0` link.
- **No SMB portal.** The actual "portal" concept (signpost → protected share) did not exist yet; Samba wasn't installed.
- **Secrets in cleartext.** Both Wi-Fi SSIDs and the PSK sat in `wpa_supplicant.conf`, and SSIDs were hard-coded into the roaming script — all of which had to become placeholders before any repo.
- **Kernel 6.18** was new enough for the modern configfs path — the enabler for everything below.

---

## 2. The plan

Three architecture decisions were validated against current best practice before touching the running device (full rationale + sources in [`ARCHITECTURE.md`](ARCHITECTURE.md)):

1. **Gadget technique → configfs / libcomposite** (retire `g_multi`).
2. **Windows networking → NCM-first with automatic RNDIS fallback** (`NET_MODE=auto`): NCM binds driverlessly on Windows 11, RNDIS covers Windows 7–10 — see [`ARCHITECTURE.md`](ARCHITECTURE.md).
3. **Storage → a read-only signpost + hardened SMB for all real data** (kill the corruption risk).

Alongside these, a fixed list of corrections applied regardless of the big decisions: suppress the dnsmasq gateway/DNS options (K1), never ship writable storage (K2), move all secrets to a gitignored config (K3), replace the fragile roaming loop with a systemd service (K4), tidy orphaned static lines in `interfaces` (K5), install and harden Samba (K6), and make the Node/Claude-Code lab an optional, switchable module (K7).

The installer was built modular and idempotent — every step is "if not exist → create" — with a backup phase first and a rollback path, so each iteration could be tested by simply re-installing over the top. The only thing at risk during a bad run was the SD card.

---

## 3. What changed during live bring-up

The plan survived contact with reality mostly intact — but several things only failed on actual Windows hardware, and those fixes are the real value of this section. Each is now encoded in the shipping code.

**3.1 CD-ROM emulation rejected by kernel 6.18 (error 525).**
The plan served the signpost as an emulated CD-ROM (`cdrom=1`, ISO9660) because Windows treats optical media as strictly read-only. On the Pi's kernel 6.18, binding an ISO file in `cdrom=1` mode is refused with **error 525**. Fix: serve a small **FAT16 image with `ro=1` + `removable=1`** instead — Windows still treats it as a write-protected stick and writes no junk to it. `ro`/`removable` must be set *before* the backing `file`, since the kernel only accepts those attributes while no file is bound.

**3.2 FAT16 "too small" at 4 MB.**
The first signpost image was 4 MB and failed to format as FAT16 ("too small" — too few clusters). Bumped to **16 MB**, the smallest broadly Windows-compatible FAT16 size, built without mounting via `mkfs.vfat -F 16` + `mtools`.

**3.3 Windows loaded no drivers at all from a multi-config gadget.**
The plan used two USB configurations (config 1 = RNDIS for Windows, config 2 = CDC-ECM for Linux/macOS). On real hardware Windows bound **nothing** — no network adapter, no drive — because it handles multi-config devices poorly and then loads no function drivers. Fix: ship a **single config** (RNDIS + mass storage); `ENABLE_ECM=0` by default. ECM/NCM remain available for Linux/macOS-only use.

**3.4 RNDIS wouldn't bind — a poisoned driver cache.**
Even with correct MS-OS/compat descriptors, the RNDIS adapter refused to appear. Root cause: after many test reconnects, the test PC had **negatively cached** the USB identifier `1d6b:0104` and stopped re-evaluating the descriptors. Fix: change the product ID to **`0xa4ac`** → Windows sees a fresh device and auto-loads "Remote NDIS Compatible Device". The descriptors were correct the whole time; only the host's cache was stale.

**3.5 Windows ended up on APIPA — the 0-byte DHCP option trap.**
The host kept falling back to a `169.254.x.x` self-assigned address. Root cause: to *suppress* DHCP options 119/121/249, the config listed them with empty values — but dnsmasq emits such options (which it never sends on its own) as a **0-byte option**, and Windows discards the entire DHCP OFFER on seeing one (DISCOVER/OFFER, but never REQUEST/ACK). Fix: **remove those three lines entirely** (only 3/6/15 are legitimately suppressed) and add `dhcp-authoritative`. Windows then cleanly leases a `10.10.0.x` address.

**3.6 Gadget restart failed — a broken teardown.**
A second `up`/`restart` failed with `ln: … Invalid argument` because the teardown didn't remove the `os_desc` config symlink (a faulty `[ -L glob ]` test). Fix: the teardown now loops and removes the `os_desc` and config symlinks correctly, so the gadget is genuinely re-run/restart-safe — which the idempotency guarantee depends on.

**3.7 Fresh install tried to start the gadget too early.**
On an empty SD card, module 30 attempted a live gadget start even though the just-added `dtoverlay=dwc2` only takes effect after a reboot (no UDC exists yet). Fix: the live start is now guarded on UDC presence, and `install.sh` prints the reboot notice in the fresh-install case too. The gadget script additionally waits up to ~10 s for the UDC and retries the bind, so the first post-reboot start is timing-safe.

**3.8 An OS-update migration risk, checked and cleared.**
DietPi has been migrating `dhclient` → `udhcpc`, which can break networking on `ifupdown2` (upstream issue #8040). Before running `dietpi-update`, this was checked: the device uses classic `ifupdown`, so the migration is safe here. Noted so future updates keep verifying it.

---

## 4. Result

The finished device was verified live on a Windows 11 PC: plugging the stick in brings up the **network adapter** (NCM on Windows 11), the **PIPORTAL** read-only drive with its `.url` signpost, a clean **DHCP lease** on `10.10.0.x`, and a reachable **hardened SMB share** — while the host keeps its own internet and SSH over `usb0` stays up. Re-running the installer over an existing install changes nothing it doesn't need to, and a fresh SD card reproduces the whole setup with one reboot.

---

## 5. Trade-offs and known limits (not a roadmap)

- **NCM by default, RNDIS as the automatic fallback (shipped, `NET_MODE=auto`).** NCM binds driverlessly on Windows 11 — verified live — and the detector falls back to RNDIS for Windows 7–10, which have no inbox NCM driver. RNDIS is now the fallback/opt-in, not the default; this follows the industry direction (Linux disabled its RNDIS host driver in 2023 as insecure).
- **Single config** trades the tidy Linux/macOS ECM face for rock-solid Windows binding. ECM is one config flag away when a host needs it.
- **Read-only signpost** means the stick itself never carries user data by design — everything real goes over SMB. That is the whole point of removing the corruption risk, not a limitation to work around.
- **512 MB RAM** is mitigated, not erased, by zram plus a size-staggered SD swapfile; heavy tools run, but this is a Zero 2 W, not a workstation.

---

## 6. Versioning and releases

**The `VERSION` file in the repo root is the single source of truth.**
Module 48 stamps it into `/etc/piportal/version` at install time so that
`piportal --version` can answer even on a device without the repo.

**A version bump never breaks a running installation.**
This deliberately departs from the usual reading of SemVer, where a major bump
is expected to break something. For an idempotent installer that would be a
contradiction: if `install.sh` brings an existing installation to the target
state anyway, handling the transition between two versions is its job — not
the user's.

In practice: whatever changes in a new release and affects existing
installations belongs in `migrate_from()` in module 48. Each block checks with
`ver_lt` whether it still applies to the version found, and stays in place
permanently. Jumping from 1.0.0 to 1.5.0 runs every applicable migration in
order.

So there is no release note saying "please reinstall" and no breakage pushed
onto the user. A `git pull` plus `sudo ./install.sh --all` must always suffice.

**A downgrade is never performed silently.** If the installed version is newer
than the source, module 48 asks — and refuses in `--non-interactive` mode.
Pulling an older source over a newer installation is almost always a mistake.

**Tags are immutable.** A published tag is never moved. Mistakes in a release
are fixed by a new patch release.
