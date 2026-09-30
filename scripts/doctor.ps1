$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
python (Join-Path $RepoRoot "scripts\validate_manifest.py")
if ($LASTEXITCODE -ne 0) { throw "appliance manifest validation failed" }

$Missing = @()
foreach ($tool in @("git","python","cargo","erl","rebar3","curl")) {
  if (Get-Command $tool -ErrorAction SilentlyContinue) {
    Write-Host ("ok   " + $tool)
  } else {
    Write-Error ("MISS " + $tool)
    $Missing += $tool
  }
}

if ($env:BMSCL_INSTALL_GLEAM_CLIENT -eq "1") {
  foreach ($tool in @("gleam","escript")) {
    if (Get-Command $tool -ErrorAction SilentlyContinue) {
      Write-Host ("ok   " + $tool)
    } else {
      Write-Error ("MISS optional Gleam dependency " + $tool)
      $Missing += $tool
    }
  }
}

$CloudflaredRequired = ($env:BMSCL_REQUIRE_CLOUDFLARED -eq "1") -or -not [string]::IsNullOrWhiteSpace($env:BMSCL_TUNNEL_NAME)
if (Get-Command "cloudflared" -ErrorAction SilentlyContinue) {
  Write-Host "ok   cloudflared"
} elseif ($CloudflaredRequired) {
  Write-Error "MISS cloudflared (required for configured public exposure)"
  $Missing += "cloudflared"
} else {
  Write-Host "skip cloudflared (optional until local expose)"
}

$State = if ($env:BMSCL_DESKTOP_STATE) { $env:BMSCL_DESKTOP_STATE } else { Join-Path $RepoRoot ".desktop" }
$EnvFile = Join-Path $State "env.ps1"
if (Test-Path $EnvFile) {
  . $EnvFile
  $Binaries = @(
    (Join-Path $State "bin\beamscale-desktop-daemon.exe"),
    (Join-Path $State "bin\beamscale-service.exe"),
    $env:BMSCL_CLI,
    (Join-Path $State "bin\bmscl-compiler.exe")
  )
  foreach ($binary in $Binaries) {
    if ($binary -and (Test-Path $binary)) { Write-Host ("ok   " + $binary) }
    else { Write-Error ("MISS " + $binary); $Missing += $binary }
  }
  $DaemonHealthy = $false
  try {
    Invoke-WebRequest -UseBasicParsing "http://127.0.0.1:9587/health" | Out-Null
    $DaemonHealthy = $true
  } catch {
    Write-Host "skip daemon RPC checks (daemon not running)"
  }
  if ($DaemonHealthy) {
    & $env:BMSCL_CLI local doctor | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Error "FAIL daemon local doctor"; $Missing += "daemon-doctor" }
    else { Write-Host "ok   daemon local doctor" }
    & $env:BMSCL_CLI local service status | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Error "FAIL daemon operator service status"; $Missing += "daemon-service-status" }
    else { Write-Host "ok   daemon operator service status" }
  }

  if ($env:BMSCL_INSTALL_GLEAM_CLIENT -eq "1") {
    $GleamCli = Join-Path $State "bin\bmscl-gleam.cmd"
    if (Test-Path $GleamCli) { Write-Host ("ok   " + $GleamCli) }
    else { Write-Error ("MISS " + $GleamCli); $Missing += $GleamCli }
  }
}

if ($Missing.Count -gt 0) { exit 1 }
