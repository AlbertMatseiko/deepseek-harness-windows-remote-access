#requires -Version 7.0
[CmdletBinding()]
param(
    [string]$PublicHost = "",
    [int]$DshPort = 3080,
    [int]$RedirectPort = 3090,
    [switch]$OpenBrowser
)

$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
$configCandidates = @(
    (Join-Path $env:USERPROFILE ".dsh\remote-config.ps1"),
    (Join-Path $root "config.ps1")
)
foreach ($configPath in $configCandidates) {
    if (Test-Path $configPath) {
        . $configPath
        break
    }
}
if ([string]::IsNullOrWhiteSpace($PublicHost) -and -not [string]::IsNullOrWhiteSpace($DshPublicHost)) {
    $PublicHost = $DshPublicHost
}
if ([string]::IsNullOrWhiteSpace($PublicHost) -or $PublicHost -match '[/:]') {
    throw "Specify the Tailscale DNS name without a scheme: -PublicHost '<machine>.<tailnet>.ts.net', or create %USERPROFILE%\.dsh\remote-config.ps1 from config.example.ps1."
}

$dshHome = Join-Path $env:USERPROFILE ".dsh"
$authFile = Join-Path $dshHome "latest-auth.json"
$urlFile = Join-Path $dshHome "latest-url.txt"
$redirectScript = Join-Path $root "redirect-server.js"
$logDir = Join-Path $env:LOCALAPPDATA "dsh-latest"
$dshLog = Join-Path $logDir "dsh-web.log"
$dshErr = Join-Path $logDir "dsh-web.err.log"
$redirectLog = Join-Path $logDir "redirect.log"
$redirectErr = Join-Path $logDir "redirect.err.log"

New-Item -ItemType Directory -Force -Path $dshHome | Out-Null
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

if (-not (Test-Path $authFile)) {
    throw "Missing $authFile. Run: pwsh -NoProfile -File `"$root\setup-auth.ps1`""
}

# Fail early instead of starting a second DSH on an occupied port.
if (Get-NetTCPConnection -State Listen -LocalPort $DshPort -ErrorAction SilentlyContinue) {
    throw "Port $DshPort is already in use. Stop the old dsh web and retry."
}

$env:DSH_HOME = $dshHome
$env:DSH_LATEST_HOST = $PublicHost
$env:DSH_LATEST_PORT = "$RedirectPort"

$node = (Get-Command node -ErrorAction Stop).Source

$redirect = $null
if (-not (Get-NetTCPConnection -State Listen -LocalPort $RedirectPort -ErrorAction SilentlyContinue)) {
    $redirect = Start-Process -FilePath $node `
        -ArgumentList @($redirectScript) `
        -PassThru `
        -WindowStyle Hidden `
        -RedirectStandardOutput $redirectLog `
        -RedirectStandardError $redirectErr
}

$dshBin = Join-Path $env:APPDATA "npm\node_modules\@deepseek-ai\dsh\lib\bin.js"
if (-not (Test-Path $dshBin)) {
    throw "Missing $dshBin. Check the global @deepseek-ai/dsh installation."
}

Remove-Item $dshLog, $dshErr -Force -ErrorAction SilentlyContinue
$dsh = Start-Process -FilePath $node `
    -ArgumentList @($dshBin, 'web', '--no-open', '--public-url', "https://$PublicHost/", '--trusted-host', $PublicHost) `
    -PassThru `
    -WindowStyle Hidden `
    -RedirectStandardOutput $dshLog `
    -RedirectStandardError $dshErr

try {
    $tokenUrl = $null
    $deadline = (Get-Date).AddSeconds(90)

    while ((Get-Date) -lt $deadline) {
        if ($dsh.HasExited) {
            throw "dsh web exited with code $($dsh.ExitCode). Logs: $dshLog and $dshErr"
        }

        $text = ""
        if (Test-Path $dshLog) {
            $text += (Get-Content -Raw -Path $dshLog -ErrorAction SilentlyContinue)
        }
        if (Test-Path $dshErr) {
            $text += "`n" + (Get-Content -Raw -Path $dshErr -ErrorAction SilentlyContinue)
        }

        $pattern = 'https?://(?:127\.0\.0\.1|' + [regex]::Escape($PublicHost) + ')(?::\d+)?/\?token=[A-Za-z0-9_-]+'
        $match = [regex]::Match($text, $pattern)
        if ($match.Success) {
            $tokenUrl = $match.Value
            break
        }
        Start-Sleep -Milliseconds 500
    }

    if (-not $tokenUrl) {
        throw "Timed out waiting for the launch URL from dsh web. Logs: $dshLog and $dshErr"
    }

    if ($tokenUrl.StartsWith('https://')) {
        $publicTokenUrl = $tokenUrl
    }
    else {
        $publicTokenUrl = $tokenUrl -replace '^http://127\.0\.0\.1:\d+', "https://$PublicHost"
    }
    Set-Content -Path $urlFile -Value $publicTokenUrl -Encoding utf8NoBOM
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $grant = "*${sid}:(R,W)"
    try {
        icacls $urlFile /inheritance:r /grant:r $grant | Out-Null
    }
    catch {
        Write-Warning "Could not restrict ACL for $urlFile"
    }

    Write-Host "DSH:    https://$PublicHost/"
    Write-Host "Latest: https://$PublicHost/latest"
    Write-Host "Logs:   $logDir"

    if ($OpenBrowser) {
        $localTokenUrl = $publicTokenUrl
        if ($localTokenUrl -match '^https://') {
            $localTokenUrl = $localTokenUrl -replace '^https://[^/]+', "http://127.0.0.1:$DshPort"
        }
        try {
            Start-Process $localTokenUrl
        }
        catch {
            Write-Warning "Could not open the browser: $($_.Exception.Message)"
        }
    }

    Wait-Process -Id $dsh.Id
}
finally {
    if ($null -ne $dsh -and -not $dsh.HasExited) {
        taskkill /PID $dsh.Id /T /F 2>$null | Out-Null
    }
    if ($null -ne $redirect -and -not $redirect.HasExited) {
        Stop-Process -Id $redirect.Id -Force -ErrorAction SilentlyContinue
    }
    Remove-Item $urlFile -Force -ErrorAction SilentlyContinue
}
