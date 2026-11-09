# gambleguard.ps1 - re-applies the gambling block and the browser DNS policies.
# A scheduled task runs this as SYSTEM every 2 minutes; that is what makes it self-healing.
$ErrorActionPreference = 'SilentlyContinue'
$MarkA = '# >>> gamble-guard >>>'
$MarkB = '# <<< gamble-guard <<<'
$Share = 'C:\ProgramData\gamble-guard'
$List  = Join-Path $Share 'blocklist.txt'
$Hosts = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'

# --- 1. the hosts block ---------------------------------------------------
if (Test-Path $List) {
  $cur = @(); if (Test-Path $Hosts) { $cur = [IO.File]::ReadAllLines($Hosts) }
  $keep = New-Object Collections.Generic.List[string]
  $skip = $false
  foreach ($l in $cur) {
    if ($l -eq $MarkA) { $skip = $true; continue }
    if ($l -eq $MarkB) { $skip = $false; continue }
    if (-not $skip) { $keep.Add($l) }
  }
  $new = New-Object Collections.Generic.List[string]
  $new.AddRange($keep); $new.Add($MarkA)
  $new.AddRange([string[]][IO.File]::ReadAllLines($List)); $new.Add($MarkB)
  $joined = ($new -join "`r`n") + "`r`n"
  $old = if (Test-Path $Hosts) { [IO.File]::ReadAllText($Hosts) } else { '' }
  if ($joined -ne $old) {
    attrib -R $Hosts 2>$null
    [IO.File]::WriteAllText($Hosts, $joined)
    ipconfig /flushdns | Out-Null
  }
}

# --- 2. browser DNS -------------------------------------------------------
# A browser doing DNS-over-HTTPS resolves names itself and never reads the hosts
# file, which silently defeats everything above.
function Set-Pol($path, $name, $value, $type) {
  if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
  New-ItemProperty -Path $path -Name $name -Value $value -PropertyType $type -Force | Out-Null
}
foreach ($b in @('Google\Chrome', 'Microsoft\Edge', 'BraveSoftware\Brave')) {
  $p = "HKLM:\SOFTWARE\Policies\$b"
  Set-Pol $p 'DnsOverHttpsMode' 'off' 'String'
  Set-Pol $p 'BuiltInDnsClientEnabled' 0 'DWord'
  Remove-ItemProperty -Path $p -Name 'DnsOverHttpsTemplates' -Force 2>$null
}
Set-Pol 'HKLM:\SOFTWARE\Policies\Mozilla\Firefox\DNSOverHTTPS' 'Enabled' 0 'DWord'
Set-Pol 'HKLM:\SOFTWARE\Policies\Mozilla\Firefox\DNSOverHTTPS' 'Locked'  1 'DWord'

# --- 3. keep the peer task alive -----------------------------------------
if (-not (Get-ScheduledTask -TaskName 'gamble-guard-watch' -EA SilentlyContinue)) {
  $cmd = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File $Share\watch.ps1"
  schtasks.exe /Create /TN 'gamble-guard-watch' /TR $cmd /SC MINUTE /MO 2 /RU SYSTEM /RL HIGHEST /F | Out-Null
}
