#requires -Version 7.0
[CmdletBinding()]
param(
    [string]$TaskName = "DSH Web latest"
)

$ErrorActionPreference = "Stop"

$script = Join-Path $PSScriptRoot "start-dsh.ps1"
$workspace = Split-Path $PSScriptRoot -Parent
$configCandidates = @(
    (Join-Path $env:USERPROFILE ".dsh\remote-config.ps1"),
    (Join-Path $PSScriptRoot "config.ps1")
)
if (-not (Test-Path $script)) {
    throw "Missing $script"
}
if (-not ($configCandidates | Where-Object { Test-Path $_ })) {
    throw "Create %USERPROFILE%\.dsh\remote-config.ps1 from scripts\config.example.ps1 and set DshPublicHost first."
}

$pwsh = (Get-Command pwsh -ErrorAction Stop).Source
$action = New-ScheduledTaskAction -Execute $pwsh -Argument "-NoProfile -WindowStyle Hidden -File `"$script`"" -WorkingDirectory $workspace
$trigger = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1)

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Description "DeepSeek Harness web + Basic Auth /latest redirect" `
    -Force | Out-Null

Write-Host "Task '$TaskName' created."
Write-Host "Check: Get-ScheduledTask -TaskName '$TaskName'"
Write-Host "Run now: Start-ScheduledTask -TaskName '$TaskName'"
