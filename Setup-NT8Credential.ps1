<#
.SYNOPSIS
    One-time setup: stores your NinjaTrader login (username + password) in
    Windows Credential Manager so Launch-NT8-AutoLogin.ps1 can retrieve it
    later without ever writing it to a file or script in plaintext.

.EXAMPLE
    .\Setup-NT8Credential.ps1
#>

. (Join-Path $PSScriptRoot 'CredentialStore.ps1')

$Target = 'NT8AutoLogin'

$userName = Read-Host "NinjaTrader username (leave blank to keep '$Target' as-is)"
if ([string]::IsNullOrWhiteSpace($userName)) {
    $userName = $env:USERNAME
}

$securePassword = Read-Host "NinjaTrader password" -AsSecureString

Save-GenericCredential -Target $Target -UserName $userName -Password $securePassword

Write-Host "Saved credential for '$userName' under Windows Credential Manager target '$Target'." -ForegroundColor Green
Write-Host "You can verify it in Control Panel > Credential Manager > Windows Credentials (look for '$Target')."
Write-Host "To remove it later: Remove-GenericCredential -Target '$Target' (after dot-sourcing CredentialStore.ps1)."
