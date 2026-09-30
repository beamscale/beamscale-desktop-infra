$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$State = if ($env:BMSCL_DESKTOP_STATE) { $env:BMSCL_DESKTOP_STATE } else { Join-Path $RepoRoot ".desktop" }
$Src = Join-Path $State "src"
$Bin = Join-Path $State "bin"
$ManifestPath = Join-Path $RepoRoot "appliance.json"

New-Item -ItemType Directory -Force -Path $Src,$Bin,(Join-Path $State "logs"),(Join-Path $State "runtime") | Out-Null

foreach ($tool in @("git","cargo","rebar3","python")) {
  if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
    throw "Missing required tool: $tool"
  }
}

python (Join-Path $RepoRoot "scripts\validate_manifest.py")
$Manifest = Get-Content -Raw $ManifestPath | ConvertFrom-Json

function Checkout-Exact([string]$Slug,[string]$Rev,[string]$Dest) {
  if (-not (Test-Path (Join-Path $Dest ".git"))) {
    git clone --filter=blob:none "https://github.com/$Slug.git" $Dest
    if ($LASTEXITCODE -ne 0) { throw "git clone failed for $Slug" }
  }
  git -C $Dest fetch --quiet origin $Rev
  if ($LASTEXITCODE -ne 0) { throw "git fetch failed for $Slug@$Rev" }
  git -C $Dest checkout --quiet --detach $Rev
  if ($LASTEXITCODE -ne 0) { throw "git checkout failed for $Slug@$Rev" }
  $head = (git -C $Dest rev-parse HEAD).Trim()
  if ($head -ne $Rev) { throw "$Slug resolved to $head, expected $Rev" }
}

foreach ($component in $Manifest.components) {
  Checkout-Exact $component.repo $component.rev (Join-Path $Src $component.name)
}

$InstallGleamClient = $env:BMSCL_INSTALL_GLEAM_CLIENT -eq "1"
$GleamClient = $Manifest.clients | Where-Object { $_.role -eq "alternate-end-user-cli" } | Select-Object -First 1
if ($InstallGleamClient) {
  if ($null -eq $GleamClient) { throw "Manifest has no alternate-end-user-cli client" }
  foreach ($tool in @("gleam","escript")) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { throw "Missing optional tool: $tool" }
  }
  Checkout-Exact $GleamClient.repo $GleamClient.rev (Join-Path $Src $GleamClient.name)
}

cargo build --release --locked --manifest-path (Join-Path $Src "desktop-daemon\Cargo.toml")
if ($LASTEXITCODE -ne 0) { throw "desktop daemon build failed" }
cargo build --release --manifest-path (Join-Path $Src "compiler\Cargo.toml")
if ($LASTEXITCODE -ne 0) { throw "compiler build failed" }
cargo build --release --manifest-path (Join-Path $Src "cli\Cargo.toml")
if ($LASTEXITCODE -ne 0) { throw "external CLI build failed" }

Push-Location (Join-Path $Src "supervisor")
try {
  rebar3 compile
  if ($LASTEXITCODE -ne 0) { throw "supervisor build failed" }
} finally {
  Pop-Location
}

Copy-Item (Join-Path $Src "desktop-daemon\target\release\beamscale-desktop-daemon.exe") $Bin -Force
Copy-Item (Join-Path $Src "desktop-daemon\target\release\beamscale-service.exe") $Bin -Force
Copy-Item (Join-Path $Src "compiler\target\release\bmscl-compiler.exe") $Bin -Force
Copy-Item (Join-Path $Src "cli\target\release\bmscl.exe") $Bin -Force

$GleamWrapper = $null
if ($InstallGleamClient) {
  Push-Location (Join-Path $Src $GleamClient.name)
  try {
    gleam export escript
    if ($LASTEXITCODE -ne 0) { throw "alternate Gleam CLI export failed" }
  } finally {
    Pop-Location
  }
  Copy-Item (Join-Path $Src "$($GleamClient.name)\bmscl_cli") (Join-Path $Bin "bmscl-gleam.escript") -Force
  $GleamWrapper = Join-Path $Bin "bmscl-gleam.cmd"
  @"
@echo off
escript "%~dp0bmscl-gleam.escript" %*
"@ | Set-Content -NoNewline -Encoding ascii $GleamWrapper
}

function Quote-PowerShellLiteral([string]$Value) {
  return "'" + $Value.Replace("'", "''") + "'"
}

$EnvFile = Join-Path $State "env.ps1"
$EnvLines = @(
  ('$env:BMSCL_DESKTOP_HOME = ' + (Quote-PowerShellLiteral (Join-Path $State "runtime"))),
  ('$env:BMSCL_DAEMON_URL = ' + (Quote-PowerShellLiteral "http://127.0.0.1:9587")),
  ('$env:BMSCL_COMPILER = ' + (Quote-PowerShellLiteral (Join-Path $Bin "bmscl-compiler.exe"))),
  ('$env:BMSCL_SUPERVISOR_ROOT = ' + (Quote-PowerShellLiteral (Join-Path $Src "supervisor"))),
  ('$env:BMSCL_CLI = ' + (Quote-PowerShellLiteral (Join-Path $Bin "bmscl.exe"))),
  ('$env:PATH = ' + (Quote-PowerShellLiteral ($Bin + ';')) + ' + $env:PATH')
)
$EnvLines | Set-Content -Encoding utf8 $EnvFile

Write-Host "BeamScale desktop appliance bootstrapped at $State"
Write-Host "  canonical CLI: $(Join-Path $Bin "bmscl.exe")"
if ($GleamWrapper) { Write-Host "  alternate Gleam CLI: $GleamWrapper" }
