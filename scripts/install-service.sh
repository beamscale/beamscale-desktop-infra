#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="${BMSCL_DESKTOP_STATE:-$ROOT/.desktop}"
test -f "$STATE/env" || { echo "run scripts/bootstrap.sh first" >&2; exit 1; }
source "$STATE/env"

CLI="${BMSCL_CLI:-$STATE/bin/bmscl}"
test -x "$CLI" || { echo "canonical CLI missing: $CLI" >&2; exit 1; }

curl --fail --silent http://127.0.0.1:9587/health >/dev/null 2>&1 || {
  echo "BeamScale desktop daemon must already be running; run scripts/up.sh first" >&2
  exit 1
}

args=(local service install)
if [[ -n "${BMSCL_SUPERVISOR_ROOT:-}" ]]; then
  args+=(--supervisor-root "$BMSCL_SUPERVISOR_ROOT")
fi
"$CLI" "${args[@]}"
"$CLI" local service status
