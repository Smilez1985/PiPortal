🇬🇧 English · **[🇩🇪 Deutsch](ROADMAP.de.md)**

# PiPortal — Roadmap

The core project (1.0.0) is complete and hardware-verified. The items below are **planned directions and ideas**, not commitments or dates — they describe where PiPortal is meant to grow. What has already shipped is recorded in the [`CHANGELOG.md`](../CHANGELOG.md) with its date.

---

## Portable admin & AI toolbox

The bigger vision behind PiPortal is a self-contained, carry-anywhere workbench:

- **Curated admin toolbox** — a defined set of portable admin/dev tools staged for the isolated environment (file transfer, disk/hardware info, terminal helpers), so the stick is a ready-to-use kit rather than a bare OS. (Today the user drops their own portable tools onto the share.)
- **Fuller Cowork integration** — a preconfigured Cowork/AI-coding environment in the isolated space so the stick doubles as a portable AI workstation. *(The Claude Code CLI itself already installs and launches via `piportal start claude` — shipped in 1.0.0; this item is the richer, preconfigured setup.)*

## Storage

- **Automatic publish cycle** for the signpost image (`forced_eject` → swap `lun.0/file`), so content updates on the read-only volume propagate to the host cleanly without a reconnect.

## Quality

- **shellcheck CI** (GitHub Actions) over all shell scripts, as a lightweight guard against regressions.

---

*Have an idea or want to help? Open an issue.*
