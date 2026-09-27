$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$State = if ($env:BMSCL_DESKTOP_STATE) { $env:BMSCL_DESKTOP_STATE } else { Join-Path $RepoRoot ".desktop" }
$EnvFile = Join-Path $State "env.ps1"
if (-not (Test-Path $EnvFile)) { throw "not bootstrapped" }
. $EnvFile

$PidFile = Join-Path $State "daemon.pid"
$Running = $false
if (Test-Path $PidFile) {
  $pidValue = (Get-Content -Raw $PidFile).Trim()
  if ($pidValue) {
    $Running = $null -ne (Get-Process -Id ([int]$pidValue) -ErrorAction SilentlyContinue)
  }
}
if ($Running) { Write-Host ("daemon: running pid=" + $pidValue) } else { Write-Host "daemon: stopped" }

& $env:BMSCL_INTERNAL_CLI local status
exit $LASTEXITCODE
