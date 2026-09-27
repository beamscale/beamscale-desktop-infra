$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$State = if ($env:BMSCL_DESKTOP_STATE) { $env:BMSCL_DESKTOP_STATE } else { Join-Path $RepoRoot ".desktop" }
$EnvFile = Join-Path $State "env.ps1"

if (Test-Path $EnvFile) {
  . $EnvFile
  if ($env:BMSCL_INTERNAL_CLI -and (Test-Path $env:BMSCL_INTERNAL_CLI)) {
    & $env:BMSCL_INTERNAL_CLI local tunnel stop 2>$null
    & $env:BMSCL_INTERNAL_CLI local runtime stop 2>$null
  }
}

$PidFile = Join-Path $State "daemon.pid"
if (Test-Path $PidFile) {
  $pidValue = (Get-Content -Raw $PidFile).Trim()
  if ($pidValue) {
    Stop-Process -Id ([int]$pidValue) -ErrorAction SilentlyContinue
  }
  Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
}

Write-Host "BeamScale desktop appliance stopped"
