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
$Share  = 'C:\ProgramData\gamble-guard'

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
# A previous install locked this folder to SYSTEM + Administrators; reclaim it so
# an update can overwrite, otherwise re-running the installer fails on the first write.
if (Test-Path $Share) {
  takeown /F $Share /R /D Y 2>&1 | Out-Null
  icacls $Share /reset /T /C 2>&1 | Out-Null
}
New-Item -ItemType Directory -Path $Share -Force | Out-Null
[IO.File]::WriteAllLines((Join-Path $Share 'blocklist.txt'), ([string[]]$set))
# Pull the companion scripts from the repo zip rather than raw.githubusercontent,
# which is CDN-cached and can serve a stale copy for several minutes after a push.
$zip = Join-Path $env:TEMP 'gg.zip'; $ex = Join-Path $env:TEMP 'gg-src'
Remove-Item -Recurse -Force $ex -EA SilentlyContinue
Invoke-WebRequest -UseBasicParsing -TimeoutSec 180 `
  -Uri 'https://codeload.github.com/prime-server/gamble-guard/zip/refs/heads/main' -OutFile $zip
Expand-Archive -Path $zip -DestinationPath $ex -Force
$win = Join-Path $ex 'gamble-guard-main\win'
foreach ($f in 'gambleguard.ps1','watch.ps1','uninstall.ps1') {
  Copy-Item -Path (Join-Path $win $f) -Destination (Join-Path $Share $f) -Force
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

# tasks run as SYSTEM so a standard user cannot stop them.
# schtasks.exe is used rather than Register-ScheduledTask: the latter needs a
# RepetitionDuration, and [TimeSpan]::MaxValue serialises to an out-of-range XML duration.
foreach ($t in @(@{n='gamble-guard';f='gambleguard.ps1'}, @{n='gamble-guard-watch';f='watch.ps1'})) {
  $cmd = 'powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File ' + $Share + '\' + $t.f
  schtasks.exe /Create /TN $t.n /TR $cmd /SC MINUTE /MO 2 /RU SYSTEM /RL HIGHEST /F | Out-Null
  if ($LASTEXITCODE -ne 0) { Write-Error "Could not create scheduled task $($t.n)"; exit 1 }
}

# apply the block before locking the folder down
& (Join-Path $Share 'gambleguard.ps1')

# Lock to SYSTEM + Administrators. Set the ACL on the FOLDER only and let children
# inherit: (OI)(CI) are container inheritance flags, so granting them directly on a
# file (icacls /T) drops the ACE and leaves the file with an empty DACL - unreadable
# even to an elevated administrator.
icacls $Share /inheritance:r /grant 'SYSTEM:(OI)(CI)F' 'Administrators:(OI)(CI)F' | Out-Null
icacls $Share /reset /T | Out-Null

schtasks.exe /Run /TN 'gamble-guard' | Out-Null

Write-Host ''
Write-Host "Done. $($set.Count) domains blocked across Chrome, Edge, Firefox and Brave."
Write-Host 'Two scheduled tasks re-apply it every 2 minutes and restore each other if deleted.'
Write-Host 'Verify:  Resolve-DnsName bet365.com'
