#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="${BMSCL_DESKTOP_STATE:-$ROOT/.desktop}"
test -f "$STATE/env" || { echo 'not bootstrapped' >&2; exit 1; }
source "$STATE/env"

INTERNAL_CLI="${BMSCL_INTERNAL_CLI:-$STATE/bin/bmscl-internal}"
if [[ -f "$STATE/daemon.pid" ]] && kill -0 "$(cat "$STATE/daemon.pid")" 2>/dev/null; then
  echo "daemon: running pid=$(cat "$STATE/daemon.pid")"
else
  echo 'daemon: stopped'
fi

"$INTERNAL_CLI" local status
