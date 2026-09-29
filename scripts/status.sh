#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="${BMSCL_DESKTOP_STATE:-$ROOT/.desktop}"
test -f "$STATE/env" || { echo 'not bootstrapped' >&2; exit 1; }
source "$STATE/env"

CLI="${BMSCL_CLI:-$STATE/bin/bmscl}"
test -x "$CLI" || { echo "canonical CLI missing: $CLI" >&2; exit 1; }

if [[ -f "$STATE/daemon.pid" ]] && kill -0 "$(cat "$STATE/daemon.pid")" 2>/dev/null; then
  echo "daemon: running pid=$(cat "$STATE/daemon.pid")"
else
  echo 'daemon: stopped'
fi

"$CLI" local status
