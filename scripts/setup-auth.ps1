#requires -Version 7.0
[CmdletBinding()]
param(
    [string]$User = "dsh"
)

$ErrorActionPreference = "Stop"

$dshHome = Join-Path $env:USERPROFILE ".dsh"
New-Item -ItemType Directory -Force -Path $dshHome | Out-Null
$authFile = Join-Path $dshHome "latest-auth.json"

if ([string]::IsNullOrWhiteSpace($User)) { $User = "dsh" }

$secure = Read-Host "Password for Basic Auth (user '$User')" -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try {
    $password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
}
finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
}

if ([string]::IsNullOrWhiteSpace($password)) {
    throw "Empty password is not allowed."
}

$saltBytes = New-Object byte[] 16
[Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($saltBytes)
$salt = [Convert]::ToBase64String($saltBytes)

$sha = [Security.Cryptography.SHA256]::Create()
try {
    $hashBytes = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes("${salt}:${User}:${password}"))
}
finally {
    $sha.Dispose()
}
$hash = -join ($hashBytes | ForEach-Object { $_.ToString("x2") })

[ordered]@{
    user = $User
    salt = $salt
    hash = $hash
} | ConvertTo-Json | Set-Content -Path $authFile -Encoding utf8NoBOM

$sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$grant = "*${sid}:(R,W)"
try {
    icacls $authFile /inheritance:r /grant:r $grant | Out-Null
}
catch {
    Write-Warning "Could not restrict ACL for $authFile"
}

Write-Host ""
Write-Host "Saved: $authFile"
Write-Host "User: $User"
Write-Host "The password is stored only as a SHA-256 hash. Remember it — you will need it on the phone."
