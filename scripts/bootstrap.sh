#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="${BMSCL_DESKTOP_STATE:-$ROOT/.desktop}"
SRC="$STATE/src"; BIN="$STATE/bin"
mkdir -p "$SRC" "$BIN" "$STATE/logs" "$STATE/runtime"
python3 "$ROOT/scripts/validate_manifest.py"
for tool in git python3 cargo erl rebar3; do command -v "$tool" >/dev/null || { echo "missing required tool: $tool" >&2; exit 1; }; done
python3 - "$ROOT/appliance.json" "$SRC" <<'PY'
import json,pathlib,subprocess,sys
m=json.loads(pathlib.Path(sys.argv[1]).read_text()); root=pathlib.Path(sys.argv[2])
for c in m['components']:
 d=root/c['name']; repo='https://github.com/'+c['repo']+'.git'; rev=c['rev']
 if not (d/'.git').exists(): subprocess.run(['git','clone','--filter=blob:none',repo,str(d)],check=True)
 subprocess.run(['git','-C',str(d),'fetch','--quiet','origin',rev],check=True)
 subprocess.run(['git','-C',str(d),'checkout','--quiet','--detach',rev],check=True)
 assert subprocess.check_output(['git','-C',str(d),'rev-parse','HEAD'],text=True).strip()==rev
PY
cargo build --release --manifest-path "$SRC/desktop-daemon/Cargo.toml"
cargo build --release --manifest-path "$SRC/compiler/Cargo.toml"
cargo build --release --manifest-path "$SRC/cli/Cargo.toml"
( cd "$SRC/supervisor" && rebar3 compile )
cp "$SRC/desktop-daemon/target/release/beamscale-desktop-daemon" "$BIN/"
cp "$SRC/compiler/target/release/bmscl-compiler" "$BIN/"
cp "$SRC/cli/target/release/bmscl" "$BIN/"
chmod 0755 "$BIN/"*
cat > "$STATE/env" <<EOF
export BMSCL_DESKTOP_HOME="$STATE/runtime"
export BMSCL_DAEMON_URL="http://127.0.0.1:9587"
export BMSCL_COMPILER="$BIN/bmscl-compiler"
export BMSCL_SUPERVISOR_ROOT="$SRC/supervisor"
export PATH="$BIN:\$PATH"
EOF
echo "BeamScale desktop appliance bootstrapped at $STATE"
