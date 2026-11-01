#requires -Version 7.0
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$desktop = [Environment]::GetFolderPath("Desktop")
$shortcutPath = Join-Path $desktop "DeepSeek Harness.lnk"
$pwsh = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\pwsh.exe"
if (-not (Test-Path $pwsh)) {
    $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
}

$script = Join-Path $PSScriptRoot "start-dsh.ps1"
$workspace = Split-Path $PSScriptRoot -Parent
$configCandidates = @(
    (Join-Path $env:USERPROFILE ".dsh\remote-config.ps1"),
    (Join-Path $PSScriptRoot "config.ps1")
)
foreach ($configPath in $configCandidates) {
    if (Test-Path $configPath) {
        . $configPath
        break
    }
}
if ([string]::IsNullOrWhiteSpace($DshPublicHost)) {
    throw "Create %USERPROFILE%\.dsh\remote-config.ps1 from scripts\config.example.ps1 and set DshPublicHost first."
}

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $pwsh
$shortcut.Arguments = '-NoProfile -ExecutionPolicy Bypass -NoExit -File "' + $script + '" -PublicHost "' + $DshPublicHost + '" -OpenBrowser'
$shortcut.WorkingDirectory = $workspace
$shortcut.Description = "Start DeepSeek Harness web + /latest redirect"
$shortcut.IconLocation = "$pwsh,0"
$shortcut.WindowStyle = 1
$shortcut.Save()

$check = $shell.CreateShortcut($shortcutPath)
Write-Host "Created: $shortcutPath"
Write-Host "target=$($check.TargetPath)"
Write-Host "args=$($check.Arguments)"
Write-Host "cwd=$($check.WorkingDirectory)"
