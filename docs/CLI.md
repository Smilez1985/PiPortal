🇬🇧 English · **[🇩🇪 Deutsch](CLI.de.md)**

# PiPortal — CLI commands (cheat sheet)

After installation the **`piportal`** command is available on the PiPortal — also
usable from the PC over the USB connection (`ssh <user>@10.10.0.1`), even when
there is no Wi-Fi. A short version of this cheat sheet also lives on the signpost
drive (`PiPortal-Befehle.txt`), so it is right there when you pick the PiPortal up
again after months.

`piportal` with no argument, or `piportal --help`, shows the help.

---

## Commands

| Command | Short | What it does |
|---|---|---|
| `piportal --status` | `ppstatus`, `-s` | Compact overview: IPs, uptime/load, CPU temp, RAM/swap/zram, connected host, services. |
| `piportal --wifi-switch` | `-w` | Switch Wi-Fi profile (menu). |
| `piportal --wifi-switch next` | | Rotate to the next configured Wi-Fi. |
| `piportal --wifi-switch <id>` | | Switch directly to a Wi-Fi ID. |
| `piportal --update` | `-u` | `dietpi-update` + `apt upgrade` + reboot (`-y` to skip the prompt). |
| `piportal --poweroff` | `off` | Shut down cleanly (then safe to unplug). |
| `piportal --smb-passwd` | | **Set** the network-drive password (none set yet) **or reset** it (already set → wipes the share). Detects the state itself. `--smb-reset` is an alias. |
| `piportal --publish` | | Rebuild the signpost drive + re-insert it at the host (without unplugging). After changes under `/srv/piportal/signpost/`. |
| `piportal --tailscale-up` | `tsup` | **Connect** Tailscale (login server from the config). Lasts only until the next reboot. |
| `piportal --tailscale-down` | `tsdown` | **Disconnect** Tailscale. |
| `piportal start claude` | | Start the Claude Code CLI (installs it automatically if needed). |
| `piportal --version` | `-V` | Show the installed version (from `/etc/piportal/version`). |
| `piportal --help` | `-h` | This help. |

**More convenience aliases** (from the next login): `cls`/`clean` (clear screen),
`pp` (= `piportal`), `cd..`/`cd...`/`..`.

---

## Setting up the Tailscale shortcut (your own data, not in the repo)

`piportal --tailscale-up` (or `tsup`) runs the long
`tailscale up --login-server <URL>` as a one-liner. The URL is **not** in the repo
but in your **local** config `config/piportal.conf` (after installation
`/etc/piportal/piportal.conf`, gitignored):

```bash
# your own Headscale:
TAILSCALE_LOGIN_SERVER="https://your-headscale.example.org"
# or leave empty -> Tailscale cloud ('tailscale up')
TAILSCALE_LOGIN_SERVER=""
```

So the command works for **any** user with **their own** credentials — the repo
ships only the empty template, no foreign logins. Setting the password / onboarding
stays manual (see [`TAILSCALE.md`](TAILSCALE.md)).

The PiPortal is then reachable from your phone anywhere via its **tailnet IP**
(`100.64.x.x`): `ssh <user>@100.64.x.x`.

---

## Prerequisite / access

- On the PiPortal itself: just type `piportal …`.
- From the PC over USB: `ssh <user>@10.10.0.1`, then `piportal …`.
- Commands that change something (Wi-Fi, update, SMB, poweroff, Tailscale) ask for
  the `sudo` password when needed.
