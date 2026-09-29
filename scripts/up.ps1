param(
  [Parameter(Mandatory=$false)]
  [string]$Project = ""
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$State = if ($env:BMSCL_DESKTOP_STATE) { $env:BMSCL_DESKTOP_STATE } else { Join-Path $RepoRoot ".desktop" }
$EnvFile = Join-Path $State "env.ps1"
if (-not (Test-Path $EnvFile)) { throw "Run scripts\bootstrap.ps1 first" }
. $EnvFile

$Cli = $env:BMSCL_CLI
if (-not $Cli -or -not (Test-Path $Cli)) { throw "Canonical CLI missing: $Cli" }

$PidFile = Join-Path $State "daemon.pid"
$LogFile = Join-Path $State "logs\daemon.log"
$Daemon = Join-Path $State "bin\beamscale-desktop-daemon.exe"
$Running = $false
if (Test-Path $PidFile) {
  $pidValue = (Get-Content -Raw $PidFile).Trim()
  if ($pidValue) {
    $Running = $null -ne (Get-Process -Id ([int]$pidValue) -ErrorAction SilentlyContinue)
  }
}

if (-not $Running) {
  $process = Start-Process -FilePath $Daemon -PassThru -WindowStyle Hidden -RedirectStandardOutput $LogFile -RedirectStandardError (Join-Path $State "logs\daemon.err.log")
  Set-Content -NoNewline $PidFile $process.Id
}

$healthy = $false
for ($i=0; $i -lt 50; $i++) {
  try {
    Invoke-WebRequest -UseBasicParsing "http://127.0.0.1:9587/health" | Out-Null
    $healthy = $true
    break
  } catch {
    Start-Sleep -Milliseconds 100
  }
}
if (-not $healthy) { throw "BeamScale desktop daemon did not become healthy" }

if ($Project) { & $Cli local start $Project; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE } }

if ($env:BMSCL_TUNNEL_NAME) {
  $args = @("local","expose",$env:BMSCL_TUNNEL_NAME)
  if ($env:BMSCL_TUNNEL_HOSTNAME) { $args += @("--hostname",$env:BMSCL_TUNNEL_HOSTNAME) }
  & $Cli @args
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

& $Cli local status
exit $LASTEXITCODE
