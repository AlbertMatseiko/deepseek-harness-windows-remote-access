# Troubleshooting

## `dsh web authentication required; reopen the URL printed by dsh web`

DSH received a stale or invalid launch token.

Possible causes:

- DSH was restarted manually while `latest-url.txt` still points to the old process;
- `start-dsh.ps1` exited and removed the URL file while DSH kept running;
- the browser cached an old redirect.

What to do:

1. Make sure DSH is started through `scripts\start-dsh.ps1` or the desktop shortcut.
2. Restart it through the script.
3. Open `/latest?nocache=...` or clear site data.

Check on the PC:

```powershell
Get-NetTCPConnection -State Listen | Where-Object LocalPort -in 3080,3090
```

```powershell
Get-Item "$env:USERPROFILE\.dsh\latest-url.txt" | Select-Object LastWriteTime, Length
```

The file should not be older than the DSH process.

## `401` on `/latest`

Wrong Basic Auth credentials.

- Enter the username/password from `setup-auth.ps1`.
- The browser may have cached an old password: clear site data or use a private tab.
- After changing the password, always restart `start-dsh.ps1`.

## `503 DSH is not ready`

The redirect server is running but cannot read `latest-url.txt` or the URL is invalid.

- DSH has not finished starting; wait.
- `start-dsh.ps1` could not parse the launch URL; inspect `%LOCALAPPDATA%\dsh-latest\dsh-web.log`.
- `latest-url.txt` is missing or does not contain `https://<pc>.<tailnet>.ts.net/?token=...`.

## `403` from DSH

`--trusted-host` in `start-dsh.ps1` does not match the host used by the browser.

Check:

```powershell
dsh web --public-url "https://<pc>.<tailnet>.ts.net/" --trusted-host "<pc>.<tailnet>.ts.net"
```

`--trusted-host` admits the Host; `--public-url` only advertises the address.

## Port 3080/3090 is in use

```powershell
Get-NetTCPConnection -State Listen | Where-Object LocalPort -in 3080,3090
```

Stop the old DSH/redirect process. Do not run the shortcut and the autostart task at the same time.

Kill the process tree:

```powershell
Get-NetTCPConnection -State Listen | Where-Object { $_.LocalPort -in 3080,3090 } |
  ForEach-Object { taskkill /PID $_.OwningProcess /T /F }
```

## Chrome will not open `/latest`, but DuckDuckGo does

Chrome cached an old redirect/token or Basic Auth credentials.

- Open `/latest?nocache=<random>`.
- Clear site data for `<pc>.<tailnet>.ts.net`.
- Use DuckDuckGo.

## LxBox: Google/YouTube do not work

- Verify that the direction containing Hiddify nodes is selected and LxBox is connected.
- Make sure Hiddify and the official Tailscale app are **not** connected as VPNs.
- If using Hiddify standalone: Settings → Inbound → TUN implementation → **system** instead of gvisor. This fixes the MTU 9000 / TLS handshake failures.

## LxBox will not open `*.ts.net`

- The Tailscale endpoint was added with a valid auth key and appears in the admin console.
- In Routing → Presets, **“Tailscale networks”** is “In rules”.
- No rule sends `ts.net` to direct/block.
- The new `LxBox-...` node is not blocked by an ACL.

## LxBox will not start / VPN drops

- Allow LxBox to run without battery restrictions.
- Make sure no other VPN is active.
- Restart LxBox after changing the TUN implementation.

## Logs

```
%LOCALAPPDATA%\dsh-latest\dsh-web.log
%LOCALAPPDATA%\dsh-latest\dsh-web.err.log
%LOCALAPPDATA%\dsh-latest\redirect.log
%LOCALAPPDATA%\dsh-latest\redirect.err.log
```

## Quick token check on the PC

```powershell
$u = (Get-Content -Raw "$env:USERPROFILE\.dsh\latest-url.txt").Trim()
$local = $u -replace '^https://[^/]+', 'http://127.0.0.1:3080'
Invoke-WebRequest -Uri $local -MaximumRedirection 0 -SkipHttpErrorCheck | Select-Object StatusCode
```

Expected: `303`. A `401` means the file is stale or DSH was restarted manually.
