$ErrorActionPreference = "Stop"
$exe = Join-Path $HOME ".local\bin\beamscale-desktop-daemon.exe"
if (-not (Test-Path $exe)) { throw "Missing $exe" }
$action = New-ScheduledTaskAction -Execute $exe
$trigger = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet -RestartCount 5 -RestartInterval (New-TimeSpan -Minutes 1)
Register-ScheduledTask -TaskName "BeamScaleDesktopDaemon" -Action $action -Trigger $trigger -Settings $settings -Force
