#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="${BMSCL_DESKTOP_STATE:-$ROOT/.desktop}"
SRC="$STATE/src"
BIN="$STATE/bin"
mkdir -p "$SRC" "$BIN" "$STATE/logs"
python3 "$ROOT/scripts/validate_manifest.py"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing required tool: $1" >&2; exit 1; }; }
for tool in git python3 cargo rebar3; do need "$tool"; done

checkout() {
  local slug="$1" rev="$2" dest="$3"
  if [[ ! -d "$dest/.git" ]]; then
    git clone --filter=blob:none "https://github.com/$slug.git" "$dest"
  fi
  git -C "$dest" fetch --quiet origin "$rev"
  git -C "$dest" checkout --quiet --detach "$rev"
  test "$(git -C "$dest" rev-parse HEAD)" = "$rev"
}

checkout beamscale/beamscale-desktop-daemon 3a42807da31b772016968776c0ff68a9b15f6da4 "$SRC/desktop-daemon"
checkout beamscale/bmscl-supervisor 17956df9b0bbde7d0bb8832a842f8e2cf0ebc504 "$SRC/supervisor"
checkout beamscale/bmscl-compiler b539cc31d814d78a0c34604762c5060c9ad27e34 "$SRC/compiler"
checkout beamscale/bmscl-cli eb8405939ecd54f3ccf27c18da0c6ef04807030d "$SRC/cli"

cargo build --locked --release --manifest-path "$SRC/desktop-daemon/Cargo.toml"
cargo build --locked --release --manifest-path "$SRC/compiler/Cargo.toml"
cargo build --locked --release --manifest-path "$SRC/cli/Cargo.toml"
( cd "$SRC/supervisor" && rebar3 as prod release )

cp "$SRC/desktop-daemon/target/release/beamscale-desktop-daemon" "$BIN/"
cp "$SRC/compiler/target/release/bmscl-compiler" "$BIN/"
cp "$SRC/cli/target/release/bmscl" "$BIN/"
chmod 0755 "$BIN/"*

mkdir -p "$STATE/runtime"
cat > "$STATE/env" <<EOF
export BMSCL_DESKTOP_HOME="$STATE/runtime"
export PATH="$BIN:\$PATH"
EOF

echo "BeamScale desktop appliance bootstrapped at $STATE"
echo "Candidate components stay pinned exactly until upstream CI is green."
