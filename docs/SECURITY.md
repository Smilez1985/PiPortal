🇬🇧 English · **[🇩🇪 Deutsch](SECURITY.de.md)**

# PiPortal — Security & Responsible Use

PiPortal is a **transparent, defensive** administration and lab tool. It is deliberately **not** an attack device, and it is built so that turning it into one takes conscious, self-responsible effort. This document explains what sets it apart from a "hacktool" and lists the Security-by-Design barriers that are actually present in the code — nothing here is aspirational.

---

## What PiPortal is — and what it isn't

**Purpose.** A mobile home lab: a self-contained environment for development and AI-coding agents (the Claude Code CLI is optionally installable, off by default) and a portable toolbox for administrators. The focus is **isolation, not infiltration** — it provides an environment *separated from* the host and shields the host from faulty code; it is not designed to break into foreign systems.

**No offensive tooling in the box.** Unlike a dedicated pentest dongle, PiPortal ships with **no exploits, no vulnerability scanners, and no automated attack scripts.** It uses standard Linux kernel gadget support (`dwc2` + `libcomposite`/configfs) and standard services (`dnsmasq`, Samba) to solve concrete technical problems — for example, avoiding filesystem corruption on the shared volume — not to attack anything.

**Transparent by design.** It announces itself openly as a network adapter and a drive. It injects no keystrokes, runs nothing automatically on the host, hides nothing, and leaves no payload behind. Everything that happens is initiated by the person operating it.

---

## Security-by-Design barriers (verifiable in the code)

1. **OS blocklist — pentest distributions are refused.** The installer's very first check (`assert_os` in `lib/common.sh`, before the root check even runs) reads `/etc/os-release` and **aborts on Kali, Parrot and similar** offensive distributions (matched against `ID`/`ID_LIKE`). Everything else is allowed — there is no lock-in to a single OS. Bypassing this requires deliberately editing the source.
2. **No gateway to the host + no IP forwarding.** The `usb0` interface config carries no gateway line, dnsmasq deliberately does **not** hand the host a default gateway or DNS (options 3/6/15 suppressed), and the installer **never** enables `net.ipv4.ip_forward`. The Pi therefore cannot route or tunnel the host's traffic over its own Wi-Fi without a conscious, manual change.
3. **Read-only signpost volume.** The emulated USB drive is mounted **read-only** (`ro=1`) for the host. It cannot be used to silently copy files or malware *off* the host onto the Pi through the drive.
4. **Authenticated SMB, no guest access.** The actual data store requires a username and password (`map to guest = Never`, `restrict anonymous = 2`, `valid users`). Merely plugging the dongle in grants no access to any files.
5. **No hardcoded secrets.** The repository contains no passwords, API tokens, or private IP addresses. Every sensitive value is set up individually at install time.
6. **The network face is driverless — a usability feature, not a security barrier.** NCM binds without admin on Windows 11 and RNDIS on Windows 7–10, so PiPortal does *not* rely on the host lacking a driver to limit misuse. The barriers that actually constrain it are points 1–5 above.

---

## Dual-use disclaimer

Like any capable networking tool — a laptop, `nmap`, SSH, or a phone hotspot — PiPortal can be misused. That responsibility lies with the user, not the tool:

- Use it only on **your own devices**, or with the **explicit permission** of the owner.
- Accessing computers, networks, or data without authorization is **illegal** in most jurisdictions and wrong everywhere.
- Deliberately repurposing PiPortal — for example removing the OS blocklist, enabling IP forwarding, or adding offensive tooling — is a conscious act performed entirely at the user's own risk and responsibility. The author accepts **no liability** for such modifications.

A tool is neutral; only actions can be harmful. PiPortal is intentionally **not** built as a covert-access or attack device, and is not intended to be turned into one. Planned future work is tracked in [`ROADMAP.md`](ROADMAP.md).
