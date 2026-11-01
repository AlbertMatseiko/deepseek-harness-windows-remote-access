# Set Up DeepSeek Harness on Windows with Remote Control from a Smartphone

**Windows + Tailscale + LxBox + Basic Auth `/latest`**

A personal user case and a reproducible guide for setting up [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) on Windows with secure remote control from an Android smartphone. The phone keeps using an existing VPN client (Hiddify/Happ nodes), while Tailscale is used only for one host. The design has **no public ingress — it is tailnet-only**.

The story behind the setup, including what did and did not work: [docs/USER-CASE.md](docs/USER-CASE.md). Windows installation: [docs/DSH-WINDOWS.md](docs/DSH-WINDOWS.md).

> This is the final working setup, not a research plan. Hostnames, paths, and secrets are placeholders. Local-only files live outside this repository.

---

## What you get

**No public ingress, tailnet-only.** DSH listens only on `127.0.0.1:3080`; Tailscale Serve publishes it over HTTPS only to devices in your tailnet. Tailscale Funnel is not used. This reduces the attack surface, but it is not an absolute security guarantee — see [docs/SECURITY.md](docs/SECURITY.md).

- DSH runs on the Windows PC and listens only on `127.0.0.1:3080`.
- Tailscale Serve publishes DSH inside your tailnet over HTTPS.
- The phone runs **LxBox**, a single sing-box VPN client that can:
  - send normal traffic through your Hiddify subscription;
  - send `*.ts.net` and tailnet addresses through its built-in **Tailscale endpoint**.
- Android allows only one active `VpnService`, so Hiddify and the official Tailscale app cannot run at the same time. LxBox solves this with one VPN slot.
- A stable URL, `https://<pc>.<tailnet>.ts.net/latest`, is protected by **Basic Auth** and redirects to the current DSH launch token. The token is not stored in Telegram and is not part of the bookmark.

```
Phone (LxBox / sing-box)
  ├─ default traffic ──────► Hiddify subscription
  └─ *.ts.net, tailnet ────► Tailscale endpoint
                                    │
                                    ▼
                         Tailscale Serve (443)
                          ├─ /       → 127.0.0.1:3080  (DSH)
                          └─ /latest → 127.0.0.1:3090  (Basic Auth → 302 token)
```

---

## Repository layout

```
README.md                  — this file: quick start and password rotation
docs/
  USER-CASE.md             — the personal story: what worked and what did not
  DSH-WINDOWS.md           — DSH installation and configuration on Windows
  ARCHITECTURE.md          — final architecture, flows, ports
  PHONE-LXBOX.md           — phone setup: LxBox + Hiddify + Tailscale
  SECURITY.md              — threat model, secrets, access rotation
  TROUBLESHOOTING.md       — common failures and diagnostics
scripts/
  config.example.ps1       — local configuration template
  setup-auth.ps1           — Basic Auth username/password
  start-dsh.ps1            — starts DSH and the redirect server
  redirect-server.js       — Basic Auth → 302 to the current token
  install-shortcut.ps1     — desktop shortcut
  install-task.ps1         — optional autostart
  README.md                — script reference
examples/
  cordis.patch.yml         — example DSH profile patch
AGENTS.md                  — agent rules for this repository
```

A working copy may also contain `local/` (screenshots, APK, research notes) and `scripts/config.ps1`; neither is part of the published repository.

---

## Requirements

### PC

- Windows 10/11.
- Node.js 22.19+ (tested on 24.x).
- PowerShell 7 (`pwsh`).
- pnpm (`dsh plugin` uses it).
- DSH `0.2.1-rc.5` (pinned; the project is a developer preview).
- Tailscale, signed in to the same tailnet as the phone.
- **MagicDNS** and **HTTPS certificates** enabled in the Tailscale admin console.

### Phone

- Android.
- A Hiddify subscription or individual proxy links.
- LxBox 2.25.18+ ([GitHub Releases](https://github.com/Leadaxe/LxBox/releases), [F-Droid](https://f-droid.org/ru/packages/com.leadaxe.lxbox/)). A public Google Play listing may not exist; use GitHub/F-Droid.
- The official Tailscale and Hiddify apps may stay installed, but they must be **off as VPNs** while LxBox is running.

---

## Windows quick start

### 0. Install and configure DSH

If DSH is not configured yet:

- install Node.js 22.19+, PowerShell 7, and DSH `0.2.1-rc.5`;
- run `dsh web` and open `http://127.0.0.1:3080`;
- **Settings → Models → DeepSeek** — paste your API key;
- choose `deepseek-flash`, select a workspace, and set permissions to `workspace-write + ask`.

Details: [docs/DSH-WINDOWS.md](docs/DSH-WINDOWS.md).

### 1. Install remote-access dependencies

```powershell
npm install -g pnpm@latest
```

```powershell
npm install -g @deepseek-ai/dsh@0.2.1-rc.5
```

```powershell
winget install --id Microsoft.PowerShell --source winget
```

```powershell
winget install --id Tailscale.Tailscale --source winget
```

Verify:

```powershell
dsh --version
```

Expected: `0.2.1-rc.5`.

### 2. Create the local configuration

Copy the template **outside the repository** and set your PC's tailnet DNS name:

```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.dsh" | Out-Null
```

```powershell
Copy-Item .\scripts\config.example.ps1 "$env:USERPROFILE\.dsh\remote-config.ps1"
```

```powershell
notepad "$env:USERPROFILE\.dsh\remote-config.ps1"
```

Example:

```powershell
$DshPublicHost = "desktop-abc123.tail1234.ts.net"
```

The file lives outside the repository, so the real hostname cannot accidentally be committed.

### 3. Set the Basic Auth password

```powershell
pwsh -NoProfile -File .\scripts\setup-auth.ps1
```

The password is entered without echo. `~/.dsh/latest-auth.json` stores only a salt and a SHA-256 hash.

### 4. Configure Tailscale Serve

Once:

```powershell
tailscale serve --bg --set-path / 3080
```

```powershell
tailscale serve --bg --set-path /latest 3090
```

```powershell
tailscale serve status
```

You should see two handlers: `/` → `127.0.0.1:3080` and `/latest` → `127.0.0.1:3090`.

### 5. Start DSH

```powershell
pwsh -NoProfile -File .\scripts\start-dsh.ps1 -OpenBrowser
```

The script:

- starts `dsh web` on `127.0.0.1:3080`;
- captures the launch URL with the token;
- writes the current URL to `~/.dsh/latest-url.txt`;
- starts the Basic Auth redirect server on `127.0.0.1:3090`;
- opens the local Web UI when `-OpenBrowser` is passed.

Keep the PowerShell window open (it can be minimized). Closing the window stops DSH; this is intentional, so the process and `latest-url.txt` cannot drift apart.

### 6. Desktop shortcut

```powershell
pwsh -NoProfile -File .\scripts\install-shortcut.ps1
```

This creates `DeepSeek Harness.lnk`, which starts `start-dsh.ps1` through PowerShell 7 and opens the Web UI.

### 7. Autostart — optional

Autostart is **not enabled by default**. To start DSH at Windows sign-in:

```powershell
pwsh -NoProfile -File .\scripts\install-task.ps1
```

Do not run the shortcut and the scheduled task at the same time: both need port 3080.

---

## Phone

Full instructions: [docs/PHONE-LXBOX.md](docs/PHONE-LXBOX.md). In short:

1. Install LxBox (arm64 APK from GitHub or F-Droid).
2. Add your Hiddify subscription as a regular source.
3. Add a **Tailscale** server:
   - auth key from Tailscale admin → Settings → Keys;
   - hostname such as `LxBox-phone`;
   - Ephemeral: off; Accept routes: off; Exit node: empty.
4. In Routing → Presets, make sure **“Tailscale networks”** is in the rules.
5. Pick the direction containing the Hiddify nodes and start LxBox.
6. Turn off Hiddify and the official Tailscale app as VPNs; LxBox must be the only VPN.
7. In the phone browser, open:

```
https://<pc>.<tailnet>.ts.net/latest
```

Enter the Basic Auth username/password. Bookmark `/latest`, not the URL with a token.

If Chrome keeps showing a stale cache or auth error, use DuckDuckGo or open `/latest?nocache=...`.

---

## How to change the Basic Auth password

The password protects `/latest`, the endpoint that hands out the current DSH token. Rotate it if you suspect a leak or simply on a schedule.

### 1. Set a new password

```powershell
pwsh -NoProfile -File .\scripts\setup-auth.ps1
```

The script overwrites `~/.dsh/latest-auth.json` with a new hash.

### 2. Restart DSH and the redirect server

`redirect-server.js` reads the auth file at startup, so the old process keeps accepting the old password until it is restarted.

Stop the current `start-dsh.ps1` window (`Ctrl+C` or close it) and start it again:

```powershell
pwsh -NoProfile -File .\scripts\start-dsh.ps1
```

If you use the scheduled task:

```powershell
Stop-ScheduledTask -TaskName "DSH Web latest"
```

```powershell
Start-ScheduledTask -TaskName "DSH Web latest"
```

### 3. Update the password in the phone browser

The old Basic Auth credentials may be cached:

- clear site data for `<pc>.<tailnet>.ts.net`;
- or open `/latest?nocache=...` in a private tab;
- or use DuckDuckGo if Chrome keeps filling in the old password.

### 4. Verify

Open `/latest`, enter the new password, and confirm that DSH opens. After the redirect server restarts, the old password must no longer work.

> Changing the password does not change the DSH token. The password protects only `/latest`; after login DSH uses its own cookie.

---

## Security

- `/latest` is an **entry point to DSH**, not a harmless page. Basic Auth is mandatory.
- Do not enable `tailscale funnel`; the service must remain accessible only inside the tailnet.
- Restrict Tailscale access with ACLs to your devices.
- Do not commit or share `%USERPROFILE%\.dsh\remote-config.ps1`, `latest-auth.json`, or `latest-url.txt`.
- Keep the phone locked; if it is lost, revoke the LxBox node in the Tailscale admin console.
- `latest-url.txt` contains a live token while DSH is running. The file is protected by the current user's ACL.
- After the redirect, the token may end up in browser history. For strict setups, open `/latest` in a private tab.

Details: [docs/SECURITY.md](docs/SECURITY.md).

---

## Troubleshooting

| Symptom | Check |
|---|---|
| `dsh web authentication required` | DSH was restarted outside `start-dsh.ps1`, or `latest-url.txt` is stale. Restart through the script and open `/latest?nocache=...` |
| `401` on `/latest` | Wrong Basic Auth; the browser cached an old password; clear site data |
| `503 DSH is not ready` | DSH is not up yet, or `latest-url.txt` is missing; check the logs |
| `403` from DSH | `--trusted-host` in `start-dsh.ps1` does not match the browser host |
| Port 3080 is in use | Stop the old `dsh web`; do not run two instances |
| LxBox will not connect | Are Hiddify/Tailscale off as VPNs? Is LxBox allowed to run without battery restrictions? |
| Google/YouTube fail in Hiddify | In Hiddify, switch TUN implementation from gvisor to system (MTU/TLS issue) |
| Chrome will not open `/latest` | Stale redirect cache; use DuckDuckGo or `?nocache=...` |

Logs:

```
%LOCALAPPDATA%\dsh-latest\dsh-web.log
%LOCALAPPDATA%\dsh-latest\dsh-web.err.log
%LOCALAPPDATA%\dsh-latest\redirect.log
```

Details: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

---

## FAQ

### How do I set up DeepSeek Harness on Windows with remote control from a smartphone?

Install DSH on Windows, run the `/latest` scripts, publish DSH through Tailscale Serve, and use LxBox on the phone with a Hiddify outbound plus the built-in Tailscale endpoint. Start with [Windows quick start](#windows-quick-start), then follow [docs/PHONE-LXBOX.md](docs/PHONE-LXBOX.md).

### Can I use DeepSeek Harness with Hiddify/Happ and Tailscale at the same time?

Not as two separate Android VPN apps: Android allows only one active `VpnService`. LxBox solves this by keeping both outbounds inside one sing-box client: Hiddify for normal traffic and a Tailscale endpoint for `*.ts.net`. The official Tailscale and Hiddify apps stay off as VPNs.

### Is there any public ingress?

No. DSH listens only on `127.0.0.1:3080`; Tailscale Serve exposes it only inside the tailnet. Tailscale Funnel is not used. `/latest` is additionally protected by Basic Auth. This reduces the attack surface, but it is not an absolute security guarantee.

### Does this work when the phone and the PC are on different networks?

Yes. Both devices only need internet access and membership in the same tailnet. Tailscale establishes a direct connection when possible and uses an encrypted DERP relay when NAT traversal fails. The PC does not need a public IP or port forwarding.

### How do I change the Basic Auth password?

Run `scripts/setup-auth.ps1` again, restart `start-dsh.ps1` (or the scheduled task), and clear the saved Basic Auth credentials in the phone browser. Full steps: [How to change the Basic Auth password](#how-to-change-the-basic-auth-password).

### Is this an official DeepSeek project?

No. This is a personal user case and a community guide. DeepSeek Harness is an MIT-licensed DeepSeek project; LxBox is a separate GPL-3.0 client and is not bundled here.

---

## Documentation

- [docs/USER-CASE.md](docs/USER-CASE.md) — personal experience: what was tried and what worked.
- [docs/DSH-WINDOWS.md](docs/DSH-WINDOWS.md) — DSH installation and configuration on Windows.
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — final architecture and flows.
- [docs/PHONE-LXBOX.md](docs/PHONE-LXBOX.md) — phone: LxBox + Tailscale + Hiddify.
- [docs/SECURITY.md](docs/SECURITY.md) — secrets, ACLs, password rotation.
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) — failures and logs.
- [scripts/README.md](scripts/README.md) — script reference.

---

## License

MIT — see [LICENSE](LICENSE). LxBox is a separate GPL-3.0 project and is not bundled here.
