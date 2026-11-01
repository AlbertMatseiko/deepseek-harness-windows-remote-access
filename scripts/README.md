# Scripts

All scripts target Windows + PowerShell 7 (`pwsh`) + Node.js.

## config.ps1

Copy the template **outside the repository**, into the user's DSH home:

```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.dsh" | Out-Null
```

```powershell
Copy-Item .\scripts\config.example.ps1 "$env:USERPROFILE\.dsh\remote-config.ps1"
```

Set the PC's tailnet DNS name:

```powershell
$DshPublicHost = "<machine>.<tailnet>.ts.net"
```

`remote-config.ps1` never enters git because it lives outside the repository. For backward compatibility the scripts also read `scripts\config.ps1`, but that path is gitignored and not recommended.

## setup-auth.ps1

Sets the Basic Auth username/password for `/latest`. `~/.dsh/latest-auth.json` stores only a salt and a SHA-256 hash.

```powershell
pwsh -NoProfile -File .\scripts\setup-auth.ps1
```

Running it again changes the password. After a password change, restart `start-dsh.ps1`, because the redirect server reads the auth file at startup.

## start-dsh.ps1

Starts DSH and the Basic Auth redirect server.

```powershell
pwsh -NoProfile -File .\scripts\start-dsh.ps1 -OpenBrowser
```

Parameters:

| Parameter | Default | Meaning |
|---|---|---|
| `-PublicHost` | from `remote-config.ps1` | PC DNS name in the tailnet |
| `-DshPort` | `3080` | DSH port |
| `-RedirectPort` | `3090` | redirect server port |
| `-OpenBrowser` | off | open the local Web UI |

The script writes the current launch URL to `%USERPROFILE%\.dsh\latest-url.txt`. On exit it kills the DSH process tree so the file and the process cannot drift apart.

## redirect-server.js

A local HTTP server on `127.0.0.1:3090`:

- requires Basic Auth;
- reads `%USERPROFILE%\.dsh\latest-url.txt`;
- returns `302` to the current launch URL.

Environment variables:

| Variable | Meaning |
|---|---|
| `DSH_LATEST_HOST` | PC DNS name (required) |
| `DSH_LATEST_PORT` | port, default `3090` |
| `DSH_HOME` | DSH home, default `%USERPROFILE%\.dsh` |

Normally started automatically by `start-dsh.ps1`.

## install-shortcut.ps1

Creates a `DeepSeek Harness` desktop shortcut. The shortcut runs `start-dsh.ps1` through `pwsh` and opens the Web UI.

```powershell
pwsh -NoProfile -File .\scripts\install-shortcut.ps1
```

## install-task.ps1

Optional autostart at Windows sign-in.

```powershell
pwsh -NoProfile -File .\scripts\install-task.ps1
```

**Do not enable autostart and the shortcut at the same time** — both need port 3080. If Task Scheduler returns `Access denied`, run PowerShell as administrator.

## Changing the password

Short version:

1. `pwsh -NoProfile -File .\scripts\setup-auth.ps1`
2. Stop the current `start-dsh.ps1` window.
3. Start `start-dsh.ps1` again.
4. Clear the saved Basic Auth credentials in the phone browser.

More details: the root `README.md` and `docs/SECURITY.md`.
