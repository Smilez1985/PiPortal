🇬🇧 English · **[🇩🇪 Deutsch](ROADMAP.de.md)**

# PiPortal — Roadmap

*As of: 2026-09-22 06:41 CEST*

The core project is complete and verified on hardware. The points below are **planned directions and ideas** — not promises and not deadlines; they describe where PiPortal should grow. What has already shipped is listed with dates in [`CHANGELOG.md`](../CHANGELOG.md).

---

## Portable admin & AI toolbox

The larger vision behind PiPortal is a self-contained workbench you can carry anywhere:

- **Curated admin toolbox** *(noted 2026-09-22)* — a defined set of portable admin/dev tools for the isolated environment (file transfer, disk/hardware info, terminal helpers), so the stick is a ready-to-use kit rather than a bare OS. (Today the user puts their own portable tools on the share.)
- **Fuller Cowork integration** *(noted 2026-09-22)* — a preconfigured Cowork / AI-coding environment in the isolated space, so the stick is also a portable AI workstation. *(The Claude Code CLI already installs and starts via `piportal start claude`; this item is the richer, preconfigured setup.)*

## Networking / Wi-Fi

- **Config-driven Wi-Fi: additive instead of replacing, any number of networks** *(noted 2026-09-22)* — today the default path (Wi-Fi fields in `config/piportal.conf` left empty) already uses **all** networks configured in DietPi, honors their order (`priority=`) and is extendable via `dietpi-config`; the home preference for the active switch-back is derived live from the highest OS `priority` (shipped in [1.1.0]). What remains is only the **optional** config-driven variant: today it writes exactly two profiles (home + hotspot) and **replaces** the existing `wpa_supplicant.conf`. Planned: make it additive (never overwrite existing DietPi networks) and support any number of profiles from the config.

---

*Have an idea or want to help? Open an issue.*
