🇬🇧 English · **[🇩🇪 Deutsch](TAILSCALE.de.md)**

# PiPortal — Tailscale onboarding (optional feature)

Tailscale is a mesh VPN: devices find each other through a **coordination server**
and then talk directly (peer-to-peer), encrypted. For the PiPortal that means you
can reach it (and your home network through it) from anywhere, without opening
ports on your router.

This feature is **opt-in and off by default**. On request the installer brings
only the **client** — it signs you in **nowhere** and puts **no** keys, URLs or
other data into the repo. Signing in (onboarding) is up to you; this file shows
how.

---

## Prerequisite — no server, no feature

Tailscale always needs a coordination server. You have exactly two options:

1. **Tailscale cloud** — a (free) account at [tailscale.com](https://tailscale.com/).
2. **Your own Headscale server** — the self-hosted, open-source alternative to the
   Tailscale cloud ([headscale](https://headscale.net/)). You set this up
   beforehand (a project of its own, not part of PiPortal).

**If you have neither, just leave the feature out:** `ENABLE_TAILSCALE="0"` in
`config/piportal.conf` (that is the shipped default). The PiPortal works fully
without Tailscale.

---

## Step 1 — install the client (opt-in)

In `config/piportal.conf`:

```bash
ENABLE_TAILSCALE="1"
```

Then run the installer (or just this phase):

```bash
sudo ./install.sh --only 55_tailscale --non-interactive
```

The installer picks the install method to match the system:

- **DietPi** → via the catalog (`dietpi-software install 58`), staying in DietPi's
  package management.
- **Arch/Alpine** → natively from the distro repo (`pacman` / `apk`).
- **Debian/Ubuntu/Fedora/RHEL/openSUSE** → via the official Tailscale install
  script, which does the correct vendor-repo dance per package manager
  (`apt`/`dnf`/`yum`/`zypper`).
- otherwise → the official install script as a fallback.

The `tailscaled` service runs afterwards (so `tailscale up` works), **but nothing
is signed in and nothing is connected**. The installer also sets up a **boot hook**
(`piportal-tailscale-down.service`) that leaves Tailscale **disconnected after every
reboot**.

**Deliberately manual and non-persistent:** Tailscale only runs when you start it
manually with `tailscale up …`, and it is off again after a reboot. That keeps it
simple and prevents the subnet self-hijack on the home network (see below).

---

## Step 2 — onboarding (you do this)

### A) Tailscale cloud

```bash
sudo tailscale up
```

The command prints a login URL; confirm it in the browser with your Tailscale
account. Done.

### B) Your own Headscale server

First create a **preauth key** on your Headscale (single-use, time-limited) — the
exact command depends on your Headscale version, e.g.:

```bash
sudo headscale preauthkeys create -u <USER-ID> --expiration 24h
```

Then sign in on the PiPortal:

```bash
sudo tailscale up \
  --login-server https://<YOUR-HEADSCALE-URL> \
  --authkey <YOUR-PREAUTH-KEY>
```

**Reconnecting later** (the login is kept across `tailscale down`/reboot, so **no**
key needed):

```bash
sudo tailscale up --login-server https://<YOUR-HEADSCALE-URL>
```

`tailscale up` with **no** flags complains ("requires mentioning all non-default
flags") because the `--login-server` preference is saved — just mention it (as
above) or use `sudo tailscale up --reset`.

Notes:

- **`--login-server`** points at *your* server instead of the Tailscale cloud.
  Omit it and you accidentally sign in to Tailscale.
- **No `--advertise-routes`:** the PiPortal advertises no route. A subnet router
  (if you want one) is provided by another, always-on device.
- **Leave `--accept-routes` OFF while the PiPortal is on the home network.** It
  sits *inside* the advertised subnet itself; accepting the route would send its
  **own** LAN traffic through the tunnel and cut off LAN-local access to it. Away
  from home (a different subnet) `--accept-routes` would be harmless and useful —
  but you don't need it just to **reach** the PiPortal (see the next section).
- **`--accept-dns`** stays at the default (on) if your coordination server hands
  out a DNS server (e.g. a Pi-hole) and the PiPortal should use it.

**Disconnect:** `sudo tailscale down`. After a reboot it is off anyway (boot hook)
— run `tailscale up …` again when needed.

---

## Accessing the PiPortal from your phone (the actual point)

You reach the PiPortal **via its tailnet IP** (`100.64.x.x`), not via the IP the
current Wi-Fi hands it. From your phone (with the Tailscale app in the same tailnet),
whether the PiPortal hangs on a powerbank+hotspot, at home, or anywhere else:

```bash
ssh <user>@100.64.x.x
```

The tailnet IP **never changes**, no matter which network the PiPortal is on — no
need to know the hotspot IP, no port forwarding. If your phone is the hotspot, the
two even build a direct P2P connection.

This is **independent of `--accept-routes`**: *reaching* the PiPortal only needs
tailnet membership. You'd only need `--accept-routes` if the PiPortal in turn should
actively reach **other home devices** (filter via Pi-hole DNS, a NAS …).

And: `--accept-routes` is **not** an exit node. It only pulls the advertised subnets
into the tunnel, **not** your default route — so your internet on the hotspot still
goes out directly (split tunnel). To route *all* traffic through home (like a
full-tunnel WireGuard), that's an exit node (`tailscale up --exit-node=<home-IP>`),
separate and opt-in.

## Step 3 — verify

On the PiPortal:

```bash
tailscale status      # shows your own 100.64.x.x and the peers
tailscale ip -4       # your own tailnet IPv4
```

On the coordination server the PiPortal shows up as a node with an address from
`100.64.0.0/10` (on Headscale: `sudo headscale nodes list`).

---

## Gotcha with self-hosted Headscale: DNS rebind protection

If your control URL (e.g. a DuckDNS/DynDNS name) resolves to a **private** IP
inside your LAN, many routers (the FRITZ!Box among them) discard such answers as a
suspected "DNS rebind" attack. `tailscale up` then fails with
`failed to resolve …`. Fixes, depending on the device:

1. In the router, add the name as an **exception to DNS rebind protection** (helps
   all LAN devices).
2. On the PiPortal, add a direct `/etc/hosts` entry (last resort):
   `<private-IP-of-your-server>  <YOUR-HEADSCALE-URL>`.

---

## Removing it again

- **Leave the tailnet:** `sudo tailscale logout` (and delete the node on the
  server; on Headscale `sudo headscale nodes delete -i <ID>`).
- **Uninstall the client:** via the package manager it came from
  (`apt`/`dnf`/`pacman`/`apk`/… or DietPi).
- The PiPortal **uninstaller deliberately leaves Tailscale alone** — it removes
  only PiPortal's own parts, not your VPN membership.

---

## Privacy / security

The repo contains **no** keys, server URLs or account data. The preauth key is
single-use and expires; the control URL is something only you supply at
`tailscale up`. PiPortal installs the client but never decides which network it
connects to — that stays entirely with you.
