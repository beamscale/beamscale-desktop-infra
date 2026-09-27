$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$State = if ($env:BMSCL_DESKTOP_STATE) { $env:BMSCL_DESKTOP_STATE } else { Join-Path $Root ".desktop" }
$Exe = Join-Path $State "bin\beamscale-desktop-daemon.exe"
if (-not (Test-Path $Exe)) { throw "Run bootstrap first; missing $Exe" }
$Action = New-ScheduledTaskAction -Execute $Exe
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Settings = New-ScheduledTaskSettingsSet -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
Register-ScheduledTask -TaskName "BeamScale Desktop Daemon" -Action $Action -Trigger $Trigger -Settings $Settings -Force | Out-Null
Write-Host "Installed BeamScale Desktop Daemon logon task"
