# User case: DSH on Windows with phone remote control

This is a personal experience, not an official DeepSeek guide. The goal was simple: run DeepSeek Harness on a Windows laptop and occasionally control it from an Android phone without giving up the VPN client used for everything else.

## Starting point

- Windows 11, Node.js 24, PowerShell 7.
- Android phone (Huawei, EMUI 14.2 / HarmonyOS 4.2).
- Main VPN: Happ with Hiddify nodes; later it turned out the Hiddify client also worked.
- Wanted: DSH on the laptop, phone access through Tailscale, while normal traffic goes through a Hiddify node.

## What I tried

1. **DSH Web UI** — the main interface; runs locally on `127.0.0.1:3080`.
2. **dsh-TUI** — a convenient terminal UI; version `0.18.0` supports DSH `0.2.1-rc.5`.
3. **VS Code Sidebar (DSH Sidebar)** — a native sidebar; its managed runtime can conflict with an already-running DSH, so it is simpler to run one runtime and connect to it.
4. **Tailscale on the phone** — works, but occupies the only VPN slot.
5. **Happ/Hiddify on the phone** — also a VPN app. Android will not run it together with Tailscale: there is only one `VpnService`.
6. **Tailscale split tunneling** — Android supports per-app, not per-domain. “Only one site through Tailscale” is not natively configurable.
7. **Happ** — an Xray-based client; it has no Tailscale outbound, so Tailscale cannot be embedded into Happ.
8. **Hiddify as the only VPN** — same subscription, but Google/YouTube did not open: ping worked while TLS handshakes failed. The cause was `tun0 MTU 9000` with gVisor. Switching TUN implementation from gvisor to **system** fixed HTTPS.
9. **LxBox** — a sing-box client that supports both Hiddify nodes and a built-in Tailscale endpoint. This became the final solution: one VPN slot, normal traffic through Hiddify, `*.ts.net` through Tailscale.
10. **`/latest` + Basic Auth** — to avoid copying `?token=` every time. A local redirect server returns the current launch URL after Basic Auth; the phone bookmark contains only the stable `/latest`.

## What did not work

- Two VPN apps at the same time in one Android profile.
- Tailscale per-domain split tunneling.
- Happ as a single client with Tailscale inside.
- Hiddify with default gVisor: ping works, Google/YouTube do not (TLS/MTU).
- Chrome with a cached redirect: `/latest` looked broken while DuckDuckGo opened DSH.

## What worked

- **LxBox** as the only VPN: Hiddify subscription + Tailscale endpoint.
- The **“Tailscale networks”** preset in LxBox: tailnet names and addresses go through Tailscale.
- **Tailscale Serve** on the PC: `/` → DSH, `/latest` → Basic Auth redirect.
- **Basic Auth redirect** instead of manually copying the token.
- **DuckDuckGo** for `/latest` when Chrome keeps using stale cache.
- A desktop shortcut for manual DSH startup.

## Lessons learned

- On Android, “two VPNs” almost always means “one VPN client with two outbounds”.
- If ping works but HTTPS does not, check MTU/TUN stack, not DNS.
- The DSH launch token lives in the process and changes on restart. The startup script must update `latest-url.txt`, otherwise `/latest` serves an old token.
- Basic Auth protects `/latest`, but this is effectively an entry point to the agent: keep the phone locked and never enable Funnel.
- DSH is a developer preview: pin versions.

## Who this is for

- Windows users who want HTTPS access to DSH from an Android phone.
- People who already have a Hiddify/Happ subscription and do not want to give it up.
- People willing to set up LxBox, Tailscale Serve, and Basic Auth once.
