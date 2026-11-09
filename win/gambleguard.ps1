# gambleguard.ps1 - re-applies the gambling block and the browser DNS policies.
# A scheduled task runs this as SYSTEM every 2 minutes; that is what makes it self-healing.
$ErrorActionPreference = 'SilentlyContinue'
# never overlap: a slow run plus a 2-minute trigger otherwise piles up processes until the
# machine crawls (seen: 384 stuck PowerShell instances)
$mutex = New-Object Threading.Mutex($false, 'Global\gamble-guard')
if (-not $mutex.WaitOne(0)) { exit 0 }
$MarkA = '# >>> gamble-guard >>>'
$MarkB = '# <<< gamble-guard <<<'
$Share = 'C:\ProgramData\gamble-guard'
$List  = Join-Path $Share 'blocklist.txt'
$Hosts = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'

# --- 0. weekly list refresh ---------------------------------------------------
# A GitHub Action rebuilds lists/ every Monday from four upstream blocklists. Windows gets
# the compact list: its DNS client stalls above ~50k hosts lines (measured: >25 s/lookup).
$Stamp = Join-Path $Share '.refreshed'
if (-not (Test-Path $Stamp) -or (Get-Item $Stamp).LastWriteTime -lt (Get-Date).AddDays(-6)) {
  try {
    $tmp = Join-Path $env:TEMP 'gg-list.txt'
    Invoke-WebRequest -UseBasicParsing -TimeoutSec 120 -OutFile $tmp `
      -Uri 'https://raw.githubusercontent.com/prime-server/gamble-guard/main/lists/compact.txt'
    $n = ([IO.File]::ReadAllLines($tmp) | Where-Object { $_ -match '^0\.0\.0\.0 ' }).Count
    if ($n -ge 5000 -and $n -le 60000) { Copy-Item $tmp $List -Force; Set-Content $Stamp (Get-Date) }   # size gate: never a broken or oversized list
    Remove-Item $tmp -Force
  } catch {}
}

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
  # allow.txt: a false positive (a work site) is unblocked here, one exact domain per line
  $allow = @{}; $af = Join-Path $Share 'allow.txt'
  if (Test-Path $af) { foreach ($d in Get-Content $af) { $d=$d.Trim().ToLower(); if ($d -and -not $d.StartsWith('#')) { $allow[$d]=1 } } }
  $block = [IO.File]::ReadAllLines($List)
  $vf = Join-Path $Share 'vpn.txt'; if ((Test-Path (Join-Path $Share 'vpn-block')) -and (Test-Path $vf)) { $block += [IO.File]::ReadAllLines($vf) }
  foreach ($l in $block) { if ($l -match '^0\.0\.0\.0 (\S+)$' -and -not $allow.ContainsKey($Matches[1])) { $new.Add($l) } }
  $new.Add($MarkB)
  $joined = ($new -join "`r`n") + "`r`n"
  $old = if (Test-Path $Hosts) { [IO.File]::ReadAllText($Hosts) } else { '' }
  if ($joined -ne $old) {
    attrib -R $Hosts 2>$null
    [IO.File]::WriteAllText($Hosts, $joined)
    ipconfig /flushdns | Out-Null
  }
}

# --- 2. upstream filtering resolver --------------------------------------------
# Mullvad's free family DNS refuses gambling domains; it covers everything the compact
# hosts list cannot. Never replace a resolver that is already blocking: a lapsed blocker
# often leaves working filter servers behind - probe them and keep them in front.
$Mullvad = '194.242.2.6'
function Test-Blocks($srv) {
  # a filtering resolver answers the control domain and either refuses, blanks, or simply
  # drops the gambling one - some blockers' servers never answer at all, so a timeout on
  # bet365 with github resolving counts as blocking
  try { $c = Resolve-DnsName github.com -Server $srv -Type A -DnsOnly -QuickTimeout -EA Stop | Where-Object { $_.IPAddress } } catch { return $false }
  if (-not $c) { return $false }
  try { $g = Resolve-DnsName bet365.com -Server $srv -Type A -DnsOnly -QuickTimeout -EA Stop | Where-Object { $_.IPAddress } } catch { return $true }
  return (-not $g -or $g[0].IPAddress -eq '0.0.0.0')
}
# a server that blocked once keeps its place without re-probing every 2 minutes
$KeepFile = Join-Path $Share 'keep-dns.txt'
$Keep = @(); if (Test-Path $KeepFile) { $Keep = Get-Content $KeepFile | Where-Object { $_ } }
Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -notmatch 'Tailscale|Loopback|VPN|TAP|WireGuard' } | ForEach-Object {
  $cur = @((Get-DnsClientServerAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4 -EA SilentlyContinue).ServerAddresses)
  $front = @()
  foreach ($ip in $cur) {
    if ($ip -eq $Mullvad) { continue }
    if ($Keep -contains $ip) { $front += $ip; continue }
    if (Test-Blocks $ip) { $front += $ip; $Keep += $ip; Add-Content $KeepFile $ip }
  }
  # Mullvad over IPv6 too, so AAAA lookups are filtered on dual-stack networks
  $want = @($front + $Mullvad + '2a07:e340::6' | Select-Object -Unique)
  if (($cur -join ',') -ne ($want -join ',')) {
    Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ServerAddresses $want -EA SilentlyContinue
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
