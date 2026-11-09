# watch.ps1 - restores the main guard task if it is deleted. The two tasks cover each other.
$ErrorActionPreference = 'SilentlyContinue'
$Share = 'C:\Program Files\gamble-guard'
if (-not (Get-ScheduledTask -TaskName 'gamble-guard' -EA SilentlyContinue)) {
  $a = New-ScheduledTaskAction -Execute 'powershell.exe' `
       -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$Share\gambleguard.ps1`""
  $t = New-ScheduledTaskTrigger -Once -At (Get-Date) `
       -RepetitionInterval (New-TimeSpan -Minutes 2) -RepetitionDuration ([TimeSpan]::MaxValue)
  $p = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
  Register-ScheduledTask -TaskName 'gamble-guard' -Action $a -Trigger $t -Principal $p -Force | Out-Null
}
& "$Share\gambleguard.ps1"
