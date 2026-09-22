🇬🇧 English · **[🇩🇪 Deutsch](ROADMAP.de.md)**

# PiPortal — Roadmap

The core project (1.0.0) is complete and hardware-verified. The items below are **planned directions and ideas**, not commitments or dates. They describe where PiPortal is meant to grow; nothing here is shipped yet.

---

## Portable admin & AI toolbox

The bigger vision behind PiPortal is a self-contained, carry-anywhere workbench:

- **Curated admin toolbox** — a defined set of administration/development tools available inside the isolated environment (file transfer, terminal, and similar day-to-day helpers), so the stick is a ready-to-use kit rather than a bare OS.
- **Cowork / Claude integration** — pull an AI-coding environment (Cowork / Claude Code CLI) into the isolated space so the stick doubles as a portable AI workstation that never touches the host. The Claude Code CLI is already optionally installable today (`ENABLE_CLAUDE_CODE=1`, off by default); the plan is a fuller, preconfigured setup.

## Networking

- **Optional NCM profile** for pure Windows 11 environments (better throughput than RNDIS). RNDIS stays the default for maximum reach across older Windows; NCM would be an opt-in profile — see the future-direction note in [`ARCHITECTURE.md`](ARCHITECTURE.md).

## Storage

- **Automatic publish cycle** for the signpost image (`forced_eject` → swap `lun.0/file`), so content updates on the read-only volume propagate to the host cleanly without a reconnect.

## Robustness (unplug safety)

- **Read-only / overlay root** so a hard power-off — pulling the stick from the USB port — can't corrupt
  the OS. The catch (thanks to the design note that surfaced it): a naive overlay makes *everything*
  volatile, so the **writable SMB share must move to a separate writable partition** excluded from the
  overlay, otherwise the share would be wiped on every reboot. That is a bigger change — hence roadmap,
  not shipped. Until then: `piportal --poweroff` shuts down cleanly before unplugging.

## Quality

- **shellcheck CI** (GitHub Actions) over all shell scripts, as a lightweight guard against regressions.

---

*Have an idea or want to help? Open an issue.*
