# Network & Tailscale

Load for any networking, tailnet, node-reachability, or homelab-egress task.

## Tailnet — `cockatoo-dominant.ts.net` (MagicDNS on)

Address nodes by **MagicDNS name or `100.x` tailnet IP — never by LAN/DHCP address.**

| Node | Tailnet IP | Role |
|---|---|---|
| `chittymini-00` | `100.69.69.0` | this Mac, traveling workstation (untagged personal node) |
| `chittymini-01..06` | `100.69.69.1..6` | cluster (tagged-devices) |
| `chittyclaw` | `100.69.69.7` | OpenClaw node (tagged) |
| `chittyserv-vm` | `100.86.86.0` | primary gateway + OpenClaw host + **split-DNS resolver** (`:61890`) |
| `ai` | `100.86.86.1` | Linux, `nick@` |

- IP plan by prefix: `100.69.69.x` = minis+claw, `100.86.86.x` = servers/AI, `100.68.68.x` = personal/mobile. `chittymini-0N` ⇒ `100.69.69.N`.
- Nearest DERP = Chicago (`ord`, ~36ms).

## Tailscale on chittymini-00 — Homebrew ONLY

- Binary: **`/opt/homebrew/bin/tailscale`** (v1.98+), NOT `/Applications/Tailscale.app`.
- The `.app` daemon + login-item helper cause **3 fighting instances → MagicDNS NXDOMAIN.** Never suggest "open the app and sign in." Use the brew `tailscaled`.
- Diagnostics: `tailscale status` (peers), `tailscale dns status` (split-DNS/MagicDNS), `tailscale netcheck` (DERP/tether drift), `tailscale debug prefs` (RouteAll/exit/tags).

## Split-DNS dependency

Google/YouTube/googleapis domains route to `chittyserv-vm`'s DoH resolver (`100.86.86.0:61890`); `ts.net` → Tailscale nameservers. **If `chittyserv-vm` is down, Google-domain resolution on tailnet devices breaks** (no fallback). Check it first when tailnet name resolution fails.

## Homelab egress — macOS Internet Sharing on chittymini-00

Chain: **iPhone USB tether (`en10`, `172.20.10.x`, cellular) → NAT → built-in Ethernet `en0` → `bridge100` (`192.168.234.1`, bootpd DHCP) → TP-Link → mini nodes.**

- This is a **phone tether — treat egress as fragile/metered, and a single point of failure** for the whole `192.168.234.0/24` subnet. The tether IP is NAT'd and volatile.
- **Why -00 hosts this:** -00 is the operator's orchestration seat, and the iPhone is physically tethered here — so this is a legitimate *transient/travel-scoped* role for -00 (it pivots in and out of the cluster), not a permanent pinned infra role. Kept idempotent/opt-out so it detaches cleanly. See `environment.md` node roles.
- Boot persistence: LaunchDaemon `cc.chitty.internetsharing` (`/usr/local/sbin/cc.chitty.internetsharing.sh`, `/Library/LaunchDaemons/cc.chitty.internetsharing.plist`, log `/var/log/cc.chitty.internetsharing.log`). Idempotent: only acts if `bridge100` lacks `en0` or `bootpd` is down; then applies NAT + `tailscale up`. Never force-restarts a healthy session.
- Health: `ifconfig bridge100 | grep 'member: en0'` + `pgrep bootpd`. Manual kick: `launchctl kickstart system/com.apple.InternetSharing`. If nodes have a LAN IP but no internet: reload sharing to reinstall pf NAT (`... kickstart -k ...`).
- NAT config written to `/Library/Preferences/SystemConfiguration/com.apple.nat`; the daemon script is the source of truth, not the GUI.

## Two separate home networks — don't conflate

- `192.168.234.0/24` — this box's homelab NAT (cluster).
- eero mesh `192.168.4.0/22` (gw `192.168.4.1`, manage via phone app only) — cameras (Reolink/ManyCam), Echos, IoT, `mac-mini-workstation`. Documented in `dev-ops/network-registry.json` (which covers **only** the eero net, despite calling itself the source of truth; it drives `camera-monitor.sh`/`camera-fix.sh`).

## Gotchas

- **Cluster DHCP is lease-order, not reserved** — mini↔`192.168.234.x` mapping reshuffles on reboot. Never hardcode a cluster IP; use tailnet identity. Leases: `/private/var/db/dhcpd_leases`.
- This gateway node is **untagged**; the cluster is `tagged-devices` — ACL/exit-node behavior differs.
