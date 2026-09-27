$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$State = if ($env:BMSCL_DESKTOP_STATE) { $env:BMSCL_DESKTOP_STATE } else { Join-Path $RepoRoot ".desktop" }
$Src = Join-Path $State "src"
$Bin = Join-Path $State "bin"
New-Item -ItemType Directory -Force -Path $Src,$Bin,(Join-Path $State "logs"),(Join-Path $State "runtime") | Out-Null

foreach ($tool in @("git","cargo","rebar3","python")) {
  if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { throw "Missing required tool: $tool" }
}
python (Join-Path $RepoRoot "scripts\validate_manifest.py")

function Checkout-Exact([string]$Slug,[string]$Rev,[string]$Dest) {
  if (-not (Test-Path (Join-Path $Dest ".git"))) {
    git clone --filter=blob:none "https://github.com/$Slug.git" $Dest
  }
  git -C $Dest fetch --quiet origin $Rev
  git -C $Dest checkout --quiet --detach $Rev
  $head = (git -C $Dest rev-parse HEAD).Trim()
  if ($head -ne $Rev) { throw "$Slug resolved to $head, expected $Rev" }
}

Checkout-Exact "beamscale/beamscale-desktop-daemon" "3a42807da31b772016968776c0ff68a9b15f6da4" (Join-Path $Src "desktop-daemon")
Checkout-Exact "beamscale/bmscl-supervisor" "17956df9b0bbde7d0bb8832a842f8e2cf0ebc504" (Join-Path $Src "supervisor")
Checkout-Exact "beamscale/bmscl-compiler" "b539cc31d814d78a0c34604762c5060c9ad27e34" (Join-Path $Src "compiler")
Checkout-Exact "beamscale/bmscl-cli" "eb8405939ecd54f3ccf27c18da0c6ef04807030d" (Join-Path $Src "cli")

cargo build --locked --release --manifest-path (Join-Path $Src "desktop-daemon\Cargo.toml")
cargo build --locked --release --manifest-path (Join-Path $Src "compiler\Cargo.toml")
cargo build --locked --release --manifest-path (Join-Path $Src "cli\Cargo.toml")
Push-Location (Join-Path $Src "supervisor"); try { rebar3 as prod release } finally { Pop-Location }

Copy-Item (Join-Path $Src "desktop-daemon\target\release\beamscale-desktop-daemon.exe") $Bin -Force
Copy-Item (Join-Path $Src "compiler\target\release\bmscl-compiler.exe") $Bin -Force
Copy-Item (Join-Path $Src "cli\target\release\bmscl.exe") $Bin -Force

"BeamScale desktop appliance bootstrapped at $State"
