# watch.ps1 - restores the main guard task if it is deleted. The two tasks cover each other.
$ErrorActionPreference = 'SilentlyContinue'
$Share = 'C:\Program Files\gamble-guard'
if (-not (Get-ScheduledTask -TaskName 'gamble-guard' -EA SilentlyContinue)) {
  $cmd = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$Share\gambleguard.ps1`""
  schtasks.exe /Create /TN 'gamble-guard' /TR $cmd /SC MINUTE /MO 2 /RU SYSTEM /RL HIGHEST /F | Out-Null
}
& "$Share\gambleguard.ps1"
