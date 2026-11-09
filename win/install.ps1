# gamble-guard installer for Windows. Run from an ELEVATED PowerShell:
#   irm https://raw.githubusercontent.com/prime-server/gamble-guard/main/win/install.ps1 | iex
param([switch]$Partner)
$ErrorActionPreference = 'Stop'

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
      ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Error 'Run this from an Administrator PowerShell.'; exit 1
}

$Repo   = 'https://raw.githubusercontent.com/prime-server/gamble-guard/main'
$ListUrl= 'https://blocklistproject.github.io/Lists/gambling.txt'
$Share  = 'C:\Program Files\gamble-guard'

Write-Host '==> fetching blocklist'
$raw = (Invoke-WebRequest -UseBasicParsing -Uri $ListUrl -TimeoutSec 180).Content -split "`n"
$set = [Collections.Generic.HashSet[string]]::new()
foreach ($l in $raw) {
  $t = $l.Trim()
  if ($t -match '^0\.0\.0\.0\s+([A-Za-z0-9][A-Za-z0-9.\-]*)$') { [void]$set.Add('0.0.0.0 ' + $Matches[1].ToLower()) }
}
try {
  foreach ($l in ((Invoke-WebRequest -UseBasicParsing -Uri "$Repo/extra-domains.txt" -TimeoutSec 60).Content -split "`n")) {
    $t = $l.Trim(); if ($t -match '^0\.0\.0\.0\s+\S+$') { [void]$set.Add($t.ToLower()) }
  }
} catch { Write-Host '    (extra-domains.txt unavailable, continuing)' }
if ($set.Count -lt 1000) { Write-Error "Blocklist looks wrong ($($set.Count) entries)."; exit 1 }
Write-Host "    $($set.Count) domains"

Write-Host '==> installing'
New-Item -ItemType Directory -Path $Share -Force | Out-Null
[IO.File]::WriteAllLines((Join-Path $Share 'blocklist.txt'), ([string[]]$set))
foreach ($f in 'gambleguard.ps1','watch.ps1','uninstall.ps1') {
  (Invoke-WebRequest -UseBasicParsing -Uri "$Repo/win/$f" -TimeoutSec 60).Content |
    Set-Content -Path (Join-Path $Share $f) -Encoding UTF8
}

if ($Partner) {
  Write-Host ''
  Write-Host '>>> Hand the keyboard to your accountability partner.'
  $p1 = Read-Host -AsSecureString '    Passphrase (hidden)'
  $p2 = Read-Host -AsSecureString '    Again'
  $b1 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($p1))
  $b2 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($p2))
  if (-not $b1 -or $b1 -ne $b2) { Write-Error 'Passphrases empty or did not match.'; exit 1 }
  $sha = [BitConverter]::ToString(
    [Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($b1))
  ).Replace('-','').ToLower()
  Set-Content -Path (Join-Path $Share 'partner.sha256') -Value $sha
  Write-Host '    Stored. Removal now requires this passphrase.'
}

# tasks run as SYSTEM so a standard user cannot stop them
foreach ($t in @(@{n='gamble-guard';f='gambleguard.ps1'}, @{n='gamble-guard-watch';f='watch.ps1'})) {
  $a = New-ScheduledTaskAction -Execute 'powershell.exe' `
       -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$Share\$($t.f)`""
  $tr = New-ScheduledTaskTrigger -Once -At (Get-Date) `
        -RepetitionInterval (New-TimeSpan -Minutes 2) -RepetitionDuration ([TimeSpan]::MaxValue)
  $pr = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
  Register-ScheduledTask -TaskName $t.n -Action $a -Trigger $tr -Principal $pr -Force | Out-Null
}

# lock the folder down to SYSTEM + Administrators
icacls $Share /inheritance:r /grant 'SYSTEM:(OI)(CI)F' 'Administrators:(OI)(CI)F' /T | Out-Null

& (Join-Path $Share 'gambleguard.ps1')
Start-ScheduledTask -TaskName 'gamble-guard'

Write-Host ''
Write-Host "Done. $($set.Count) domains blocked across Chrome, Edge, Firefox and Brave."
Write-Host 'Two scheduled tasks re-apply it every 2 minutes and restore each other if deleted.'
Write-Host 'Verify:  Resolve-DnsName bet365.com'
