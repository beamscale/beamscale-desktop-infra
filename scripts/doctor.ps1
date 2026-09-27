$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
python (Join-Path $RepoRoot "scripts\validate_manifest.py")
if ($LASTEXITCODE -ne 0) { throw "appliance manifest validation failed" }

$Missing = @()
foreach ($tool in @("git","python","cargo","erl","rebar3","gleam","escript","cloudflared","curl")) {
  if (Get-Command $tool -ErrorAction SilentlyContinue) {
    Write-Host ("ok   " + $tool)
  } else {
    Write-Error ("MISS " + $tool)
    $Missing += $tool
  }
}

$State = if ($env:BMSCL_DESKTOP_STATE) { $env:BMSCL_DESKTOP_STATE } else { Join-Path $RepoRoot ".desktop" }
$EnvFile = Join-Path $State "env.ps1"
if (Test-Path $EnvFile) {
  . $EnvFile
  foreach ($cli in @((Join-Path $State "bin\bmscl.exe"), $env:BMSCL_INTERNAL_CLI)) {
    if ($cli -and (Test-Path $cli)) { Write-Host ("ok   " + $cli) }
    else { Write-Error ("MISS " + $cli); $Missing += $cli }
  }
}

if ($Missing.Count -gt 0) { exit 1 }
