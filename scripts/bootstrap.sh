#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/doctor.sh
ROOT="$HOME/.beamscale/desktop-src"
if [ -n "${BMSCL_DESKTOP_SRC:-}" ]; then ROOT="$BMSCL_DESKTOP_SRC"; fi
mkdir -p "$ROOT"
python3 - "$ROOT" <<'PY'
import pathlib,subprocess,sys,tomllib
root=pathlib.Path(sys.argv[1]); m=tomllib.loads(pathlib.Path('appliance.toml').read_text())
for c in m['component']:
 d=root/c['name']
 if not d.exists(): subprocess.run(['git','clone','--filter=blob:none',c['repo'],str(d)],check=True)
 subprocess.run(['git','-C',str(d),'fetch','--depth=1','origin',c['rev']],check=True)
 subprocess.run(['git','-C',str(d),'checkout','--detach',c['rev']],check=True)
 print(c['name']+': '+c['rev'])
PY
echo "Exact source revisions materialized under $ROOT"
