# Removes gamble-guard - but not on impulse. Elevated PowerShell.
#   .\uninstall.ps1            request removal, or complete it once the wait is up
#   .\uninstall.ps1 -Status    how long is left
param([switch]$Status)
$ErrorActionPreference = 'Stop'
$Share = 'C:\Program Files\gamble-guard'
$Req   = Join-Path $Share 'unlock.request'
$Part  = Join-Path $Share 'partner.sha256'
$Days  = if ($env:DELAY_DAYS) { [int]$env:DELAY_DAYS } else { 7 }
$now   = [int][double]::Parse((Get-Date -UFormat %s))

if ($Status) {
  if (Test-Path $Req) {
    $left = [int](Get-Content $Req) + $Days*86400 - $now
    if ($left -le 0) { 'Cooling-off complete. Re-run to remove.' }
    else { "Removal requested. $([int]($left/3600))h $([int](($left%3600)/60))m left." }
  } else { 'No removal requested. gamble-guard is active.' }
  exit 0
}
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
      ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Error 'Run from an Administrator PowerShell.'; exit 1
}

if (Test-Path $Part) {
  $p = Read-Host -AsSecureString 'Accountability passphrase'
  $b = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($p))
  $got = [BitConverter]::ToString(
    [Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($b))
  ).Replace('-','').ToLower()
  if ($got -ne (Get-Content $Part).Trim()) { Write-Error 'Wrong passphrase. Ask the person who holds it.'; exit 1 }
} elseif (-not (Test-Path $Req)) {
  Set-Content -Path $Req -Value $now
  Write-Host ''
  Write-Host "Removal requested. gamble-guard keeps working for $Days days."
  Write-Host 'Re-run this after that to finish.  Progress: .\uninstall.ps1 -Status'
  Write-Host ''
  Write-Host 'If this is a craving rather than a decision, it will pass.'
  exit 0
} else {
  $left = [int](Get-Content $Req) + $Days*86400 - $now
  if ($left -gt 0) { Write-Error "Still cooling off: $([int]($left/3600))h $([int](($left%3600)/60))m left."; exit 1 }
}

foreach ($t in 'gamble-guard','gamble-guard-watch') { Unregister-ScheduledTask -TaskName $t -Confirm:$false -EA SilentlyContinue }
$MarkA='# >>> gamble-guard >>>'; $MarkB='# <<< gamble-guard <<<'
$H = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
$keep=New-Object Collections.Generic.List[string]; $skip=$false
foreach ($l in [IO.File]::ReadAllLines($H)) {
  if ($l -eq $MarkA) { $skip=$true; continue }
  if ($l -eq $MarkB) { $skip=$false; continue }
  if (-not $skip) { $keep.Add($l) }
}
[IO.File]::WriteAllText($H, ($keep -join "`r`n") + "`r`n")
ipconfig /flushdns | Out-Null
Remove-Item -Recurse -Force $Share -EA SilentlyContinue
Write-Host 'gamble-guard removed.'
