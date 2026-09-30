#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="${BMSCL_DESKTOP_STATE:-$ROOT/.desktop}"
test -f "$STATE/env" || { echo "run scripts/bootstrap.sh first" >&2; exit 1; }
source "$STATE/env"

CLI="${BMSCL_CLI:-$STATE/bin/bmscl}"
test -x "$CLI" || { echo "canonical CLI missing: $CLI" >&2; exit 1; }

curl --fail --silent http://127.0.0.1:9587/health >/dev/null 2>&1 || {
  echo "BeamScale desktop daemon must be running to remove persistent service registration" >&2
  exit 1
}

"$CLI" local service uninstall
echo "BeamScale desktop daemon user service registration removed; current daemon and appliance state were preserved."
