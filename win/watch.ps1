# watch.ps1 - restores the main guard task if it is deleted. The two tasks cover each other.
$ErrorActionPreference = 'SilentlyContinue'
# never overlap: a slow run plus a 2-minute trigger otherwise piles up processes until the
# machine crawls (seen: 384 stuck PowerShell instances)
$mutex = New-Object Threading.Mutex($false, 'Global\gamble-guard-watch')
if (-not $mutex.WaitOne(0)) { exit 0 }
$Share = 'C:\ProgramData\gamble-guard'
if (-not (Get-ScheduledTask -TaskName 'gamble-guard' -EA SilentlyContinue)) {
  $cmd = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File $Share\gambleguard.ps1"
  schtasks.exe /Create /TN 'gamble-guard' /TR $cmd /SC MINUTE /MO 2 /RU SYSTEM /RL HIGHEST /F | Out-Null
}
& "$Share\gambleguard.ps1"
