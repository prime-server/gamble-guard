# gamble-guard is permanent. This only removes it with the accountability partner's passphrase
# (set at install with -Partner) or after an opt-in -LockDays period has ended.
#   .\uninstall.ps1 -Status
param([switch]$Status)
$ErrorActionPreference = 'Stop'
$Share = 'C:\ProgramData\gamble-guard'
$Part  = Join-Path $Share 'partner.sha256'
$now   = [int][double]::Parse((Get-Date -UFormat %s))
$Lock  = Join-Path $Share 'locked-until'
$lockLeft = if (Test-Path $Lock) { [int](Get-Content $Lock) - $now } else { 0 }

if ($Status) {
  'Permanent: there is no uninstall.'
  "Partner passphrase: $(if (Test-Path $Part) {'set'} else {'not set'})"
  "Lock: $(if ($lockLeft -gt 0) { 'until ' + (Get-Date).AddSeconds($lockLeft).ToString('yyyy-MM-dd') } elseif (Test-Path $Lock) { 'expired' } else { 'forever' })"
  exit 0
}
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
      ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Error 'Run from an Administrator PowerShell.'; exit 1
}
$expired = (Test-Path $Lock) -and ($lockLeft -le 0)   # an opt-in finite lock that has run out
if (-not $expired) {
  if (Test-Path $Part) {
    $p = Read-Host -AsSecureString 'Accountability passphrase'
    $b = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($p))
    $got = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($b))).Replace('-','').ToLower()
    if ($got -ne (Get-Content $Part).Trim()) { Write-Error 'Wrong passphrase. Ask the person who holds it.'; exit 1 }
  } else {
    Write-Host 'gamble-guard has no uninstall. It is permanent by design.'; exit 1
  }
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
# remove only OUR resolver entry; anything else (e.g. another blocker's still-working filter) stays
Get-NetAdapter | ForEach-Object {
  $cur = @((Get-DnsClientServerAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4 -EA SilentlyContinue).ServerAddresses)
  if ($cur -contains '194.242.2.6') {
    $rest = @($cur | Where-Object { $_ -ne '194.242.2.6' })
    if ($rest.Count) { Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ServerAddresses $rest -EA SilentlyContinue }
    else { Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ResetServerAddresses -EA SilentlyContinue }
  }
}
Remove-Item -Recurse -Force $Share -EA SilentlyContinue
Write-Host 'gamble-guard removed.'
