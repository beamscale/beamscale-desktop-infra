$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$State = if ($env:BMSCL_DESKTOP_STATE) { $env:BMSCL_DESKTOP_STATE } else { Join-Path $RepoRoot ".desktop" }
$EnvFile = Join-Path $State "env.ps1"
if (-not (Test-Path $EnvFile)) { throw "Run scripts\bootstrap.ps1 first" }
. $EnvFile

$Cli = $env:BMSCL_CLI
if (-not $Cli -or -not (Test-Path $Cli)) { throw "Canonical CLI missing: $Cli" }

try {
  Invoke-WebRequest -UseBasicParsing "http://127.0.0.1:9587/health" | Out-Null
} catch {
  throw "BeamScale desktop daemon must already be running; run scripts\up.ps1 first"
}

$Args = @("local","service","install")
if ($env:BMSCL_SUPERVISOR_ROOT) {
  $Args += @("--supervisor-root",$env:BMSCL_SUPERVISOR_ROOT)
}
& $Cli @Args
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $Cli local service status
exit $LASTEXITCODE
