$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$State = if ($env:BMSCL_DESKTOP_STATE) { $env:BMSCL_DESKTOP_STATE } else { Join-Path $Root ".desktop" }
$Runtime = Join-Path $State "runtime"
$Exe = Join-Path $State "bin\beamscale-desktop-daemon.exe"
$TaskName = "BeamScale Desktop Daemon"

if (-not (Test-Path $Exe)) { throw "Run bootstrap first; missing $Exe" }
New-Item -ItemType Directory -Force -Path $Runtime | Out-Null

function Quote-PowerShellLiteral([string]$Value) {
  return "'" + $Value.Replace("'", "''") + "'"
}

$runtimeLiteral = Quote-PowerShellLiteral $Runtime
$exeLiteral = Quote-PowerShellLiteral $Exe
$command = @(
  '$ErrorActionPreference = "Stop"',
  ("$env:BMSCL_DESKTOP_HOME = " + $runtimeLiteral),
  '$env:BMSCL_DAEMON_LISTEN = "127.0.0.1:9587"',
  ("& " + $exeLiteral)
) -join "; "

$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument ("-NoProfile -NonInteractive -WindowStyle Hidden -Command \"" + $command + "\"")
$Trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$Settings = New-ScheduledTaskSettingsSet -RestartCount 5 -RestartInterval (New-TimeSpan -Minutes 1) -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew

Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Description "BeamScale desktop daemon for the bootstrapped local appliance" -Force | Out-Null
Start-ScheduledTask -TaskName $TaskName
Write-Host "Installed and started BeamScale Desktop Daemon logon task for state: $State"
