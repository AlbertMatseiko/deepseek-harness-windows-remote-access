# Final architecture

## Components

| Component | Runs on | Role |
|---|---|---|
| DeepSeek Harness (`dsh`) | Windows PC, `127.0.0.1:3080` | Agent runtime |
| `start-dsh.ps1` | Windows PC | Starts DSH, captures the launch URL, writes `latest-url.txt`, starts the redirect server |
| `redirect-server.js` | Windows PC, `127.0.0.1:3090` | Basic Auth → `302` to the current launch URL |
| Tailscale Serve | Windows PC, HTTPS 443 inside the tailnet | Publishes `/` and `/latest` |
| LxBox | Android | The only VPN client: Hiddify outbound + Tailscale endpoint |
| Hiddify subscription | Inside LxBox | Normal internet, Google, YouTube |
| Tailscale endpoint in LxBox | Inside LxBox | Access to `*.ts.net` and tailnet addresses |

## Request flow

```
Phone browser
  │  https://<pc>.<tailnet>.ts.net/latest
  ▼
LxBox (sing-box)
  ├─ *.ts.net route → Tailscale endpoint
  └─ everything else → Hiddify node
  │
  ▼
Tailscale Serve on the PC (443)
  ├─ /latest → 127.0.0.1:3090
  └─ /       → 127.0.0.1:3080
  │
  ▼
redirect-server.js (Basic Auth)
  │  302 Location: https://<pc>.<tailnet>.ts.net/?token=...
  ▼
DSH (3080)
  │  token → 303 + Set-Cookie
  ▼
DSH Web UI in the phone browser
```

## Why LxBox

Android allows only one active `VpnService`. Therefore:

- Hiddify + the official Tailscale app cannot run at the same time;
- Tailscale for Android supports split tunneling **by app**, not by domain;
- Happ is built on Xray and has no Tailscale outbound;
- LxBox is a sing-box client that keeps a **Tailscale endpoint and a Hiddify outbound inside one VPN**.

LxBox does not replace the Hiddify server: it uses the same subscription and nodes. The Happ app is not running in this setup.

## Ports and files

| Item | Value |
|---|---|
| DSH Web | `127.0.0.1:3080` |
| Redirect `/latest` | `127.0.0.1:3090` |
| Tailscale Serve | HTTPS 443 inside the tailnet |
| `DSH_HOME` | `%USERPROFILE%\.dsh` |
| Auth hash | `%USERPROFILE%\.dsh\latest-auth.json` |
| Current launch URL | `%USERPROFILE%\.dsh\latest-url.txt` |
| Logs | `%LOCALAPPDATA%\dsh-latest\` |
| Local config | `%USERPROFILE%\.dsh\remote-config.ps1` (outside the repository) |

## Token lifecycle

1. `dsh web` creates a **process launch token** at startup and prints `...?token=...`.
2. `start-dsh.ps1` captures that URL and writes it to `latest-url.txt`.
3. After Basic Auth, `/latest` returns `302` to that URL.
4. DSH validates the token, sets a signed cookie (normally valid for 30 days), and redirects to `/`.
5. While the DSH process is alive, the token remains valid; the cookie survives browser restarts.
6. When DSH restarts, the token changes. `start-dsh.ps1` updates `latest-url.txt`, so `/latest` automatically serves the new token.
7. If DSH is restarted **outside the script**, the file remains stale and `/latest` serves an old token. Always start DSH through the script or shortcut.

## Security properties

- DSH listens only on loopback; it is not published directly.
- Tailscale Serve is reachable only by devices in the tailnet.
- `/latest` is protected by Basic Auth and does not contain a token in the bookmark.
- `latest-url.txt` contains a live token; its ACL is limited to the current user.
- The Basic Auth password is stored as a salted SHA-256 hash.
- Funnel is not used.

## Limitations

- Basic Auth is the only protection on `/latest`; if the phone is lost, revoke the LxBox node and rotate the password.
- After the redirect, the token may end up in browser history.
- LxBox is a third-party GPL client and is not bundled here.
- DSH is a developer preview; versions are pinned and updates can break plugins.
