$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$State = if ($env:BMSCL_DESKTOP_STATE) { $env:BMSCL_DESKTOP_STATE } else { Join-Path $RepoRoot ".desktop" }
$EnvFile = Join-Path $State "env.ps1"
if (-not (Test-Path $EnvFile)) { throw "Run scripts\bootstrap.ps1 first" }
. $EnvFile

$Service = if ($env:BMSCL_SERVICE_BINARY) { $env:BMSCL_SERVICE_BINARY } else { Join-Path $State "bin\beamscale-service.exe" }
if (-not (Test-Path $Service)) { throw "Rust service manager missing: $Service" }

& $Service uninstall
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "BeamScale desktop daemon user service removed; appliance state was preserved."
