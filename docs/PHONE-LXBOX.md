# Phone: LxBox + Tailscale + Hiddify

Goal: one Android VPN client that sends normal traffic through a Hiddify node and `*.ts.net` through a built-in Tailscale endpoint. The official Tailscale and Hiddify apps must be off as VPNs while LxBox is running.

## 1. Install LxBox

LxBox 2.25.18+:

- [GitHub Releases](https://github.com/Leadaxe/LxBox/releases) — choose `arm64-v8a` for modern phones;
- [F-Droid](https://f-droid.org/ru/packages/com.leadaxe.lxbox/).

SHA-256 for `2.25.18 arm64-v8a` APK:

```
eac15c50dd034651d75e7194b1644feb4e8fb82701b357c0c19ee787625e02f2
```

A public Google Play listing may not exist; use GitHub/F-Droid.

On first launch LxBox will ask about:

- background activity — allow it and choose “Unrestricted” if your Android build offers it;
- update checks — you can skip them and update manually from GitHub.

## 2. Add the Hiddify subscription

1. Copy the subscription URL from Hiddify/Happ (do not publish it).
2. LxBox → **Servers** → **Subscription URL or proxy link**.
3. Paste the URL and press **+**.
4. Wait for the nodes to import. The subscription appears in the server list.

If the subscription does not import, add an individual proxy link (`vless://`, `vmess://`, `trojan://`, `ss://`, `hysteria2://`, etc.) the same way.

## 3. Add the Tailscale endpoint

1. Open https://login.tailscale.com/admin/settings/keys.
2. **Generate auth key**:
   - one-off is enough;
   - tags only if your ACL requires them;
   - expiry as you prefer.
3. Copy the `tskey-auth-...` key.
4. LxBox → **Servers** → **+** → **Add server…** → **Tailscale** tab.
5. Fill in:

| Field | Value |
|---|---|
| Tag | `tailscale` (or any label) |
| Auth key | `tskey-auth-...` |
| Control URL | `https://controlplane.tailscale.com` (leave as is) |
| Hostname | e.g. `LxBox-phone` |
| Ephemeral | off |
| Accept routes | off |
| Exit node | empty |

6. Press **Add**.
7. A new node such as `LxBox-phone` appears in Tailscale admin → Machines. Allow it to reach the PC through your ACL if needed.

> LxBox creates a **separate tailnet node**; it does not use the official Tailscale app. The official app may stay installed, but its VPN must be off.

## 4. Check routing

1. LxBox → menu (☰) → **Routing**.
2. **Presets** tab → find **“Tailscale networks”** → it should say **“In rules”**.
   - This preset sends tailnet addresses through the Tailscale endpoint and resolves `ts.net` through its MagicDNS.
3. **Directions** tab → enable the direction containing the Hiddify nodes (for example `VPN`).
4. On the main screen, select that direction and press **Start**.

If the direction selector is empty, open the direction under **Routing → Directions**, make sure it is enabled, save it, and return to the main screen.

## 5. Start

1. Make sure Hiddify and the official Tailscale app are **not connected as VPNs**.
2. LxBox → **Start**.
3. Android asks for VPN permission — **OK**.
4. Verify:
   - Google and YouTube open through the Hiddify node;
   - LxBox shows the Hiddify direction;
   - the Tailscale node is active in the admin console.

## 6. Open DSH

In the phone browser:

```
https://<pc>.<tailnet>.ts.net/latest
```

Enter the Basic Auth username/password set on the PC by `setup-auth.ps1`. After login, DSH sets its cookie.

Bookmark `/latest` — not a URL containing `?token=`.

### If Chrome will not open it

Chrome may cache an old redirect/token or Basic Auth credentials. Options:

- open `/latest?nocache=< random >` to bypass the cache;
- clear site data for `<pc>.<tailnet>.ts.net`;
- use **DuckDuckGo** or another browser — this has been verified to work.

## 7. If you use Hiddify standalone

If you switch back to Hiddify as the only VPN and Google/YouTube do not open while ping works:

1. Hiddify → Settings → Inbound → **TUN implementation**.
2. Switch **gvisor → system**.
3. Reconnect.

The symptom “TLS handshake failed, net_error -100” with working ping is usually an MTU/gVisor issue (`tun0 MTU 9000`). After switching to system the MTU becomes about 1492 and TLS works.

## 8. Limitations

- Android allows only one VPN. LxBox, Hiddify, and Tailscale cannot be active at the same time.
- LxBox is a third-party client (GPL-3.0) and is not part of this repository.
- The Hiddify subscription and Tailscale auth key are secrets; do not publish them.
- If the phone is lost, revoke the `LxBox-phone` node in Tailscale admin and rotate the Basic Auth password.
