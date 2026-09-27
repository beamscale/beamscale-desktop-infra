$ErrorActionPreference = "Stop"
$TaskName = "BeamScale Desktop Daemon"
$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($null -ne $task) {
  Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
  Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}
Write-Host "Removed BeamScale Desktop Daemon scheduled task; appliance state was preserved."
