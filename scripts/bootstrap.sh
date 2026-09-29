#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="${BMSCL_DESKTOP_STATE:-$ROOT/.desktop}"
SRC="$STATE/src"
BIN="$STATE/bin"

mkdir -p "$SRC" "$BIN" "$STATE/logs" "$STATE/runtime"
python3 "$ROOT/scripts/validate_manifest.py"

for tool in git python3 cargo erl rebar3; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "missing required tool: $tool" >&2
    exit 1
  }
done

python3 - "$ROOT/appliance.json" "$SRC" <<'PY'
import json
import pathlib
import subprocess
import sys

manifest = json.loads(pathlib.Path(sys.argv[1]).read_text())
root = pathlib.Path(sys.argv[2])

wanted = list(manifest["components"])
if __import__("os").environ.get("BMSCL_INSTALL_GLEAM_CLIENT") == "1":
    wanted.extend(
        client for client in manifest.get("clients", [])
        if client.get("role") == "alternate-end-user-cli"
    )

for component in wanted:
    dest = root / component["name"]
    repo = "https://github.com/" + component["repo"] + ".git"
    rev = component["rev"]
    if not (dest / ".git").exists():
        subprocess.run(
            ["git", "clone", "--filter=blob:none", repo, str(dest)],
            check=True,
        )
    subprocess.run(["git", "-C", str(dest), "fetch", "--quiet", "origin", rev], check=True)
    subprocess.run(["git", "-C", str(dest), "checkout", "--quiet", "--detach", rev], check=True)
    head = subprocess.check_output(
        ["git", "-C", str(dest), "rev-parse", "HEAD"],
        text=True,
    ).strip()
    if head != rev:
        raise SystemExit(f"{component['repo']} resolved to {head}, expected {rev}")
PY

cargo build --release --manifest-path "$SRC/desktop-daemon/Cargo.toml"
cargo build --release --manifest-path "$SRC/compiler/Cargo.toml"
cargo build --release --manifest-path "$SRC/cli/Cargo.toml"
( cd "$SRC/supervisor" && rebar3 compile )
cp "$SRC/desktop-daemon/target/release/beamscale-desktop-daemon" "$BIN/"
cp "$SRC/desktop-daemon/target/release/beamscale-service" "$BIN/"
cp "$SRC/compiler/target/release/bmscl-compiler" "$BIN/"
cp "$SRC/cli/target/release/bmscl" "$BIN/"
chmod 0755 "$BIN/beamscale-desktop-daemon" "$BIN/beamscale-service" "$BIN/bmscl-compiler" "$BIN/bmscl"

if [[ "${BMSCL_INSTALL_GLEAM_CLIENT:-0}" == "1" ]]; then
  command -v gleam >/dev/null 2>&1 || { echo "missing optional tool: gleam" >&2; exit 1; }
  command -v escript >/dev/null 2>&1 || { echo "missing optional tool: escript" >&2; exit 1; }
  ( cd "$SRC/cli-gleam" && gleam export escript )
  cp "$SRC/cli-gleam/bmscl_cli" "$BIN/bmscl-gleam.escript"
  cat > "$BIN/bmscl-gleam" <<EOF
#!/usr/bin/env sh
exec escript "$BIN/bmscl-gleam.escript" "\$@"
EOF
  chmod 0755 "$BIN/bmscl-gleam" "$BIN/bmscl-gleam.escript"
fi

cat > "$STATE/env" <<EOF
export BMSCL_DESKTOP_HOME="$STATE/runtime"
export BMSCL_DAEMON_URL="http://127.0.0.1:9587"
export BMSCL_COMPILER="$BIN/bmscl-compiler"
export BMSCL_SUPERVISOR_ROOT="$SRC/supervisor"
export BMSCL_CLI="$BIN/bmscl"
export BMSCL_SERVICE_BINARY="$BIN/beamscale-service"
export PATH="$BIN:\$PATH"
EOF

echo "BeamScale desktop appliance bootstrapped at $STATE"
echo "  canonical CLI: $BIN/bmscl"
if [[ -x "$BIN/bmscl-gleam" ]]; then
  echo "  alternate Gleam CLI: $BIN/bmscl-gleam"
fi
