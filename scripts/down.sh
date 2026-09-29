#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="${BMSCL_DESKTOP_STATE:-$ROOT/.desktop}"

if [[ -f "$STATE/env" ]]; then
  source "$STATE/env"
  CLI="${BMSCL_CLI:-$STATE/bin/bmscl}"
  if [[ -x "$CLI" ]]; then
    "$CLI" local unexpose >/dev/null 2>&1 || true
    "$CLI" local stop >/dev/null 2>&1 || true
  fi
fi

if [[ -f "$STATE/daemon.pid" ]]; then
  pid="$(cat "$STATE/daemon.pid")"
  kill "$pid" 2>/dev/null || true
  for _ in {1..30}; do
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.1
  done
  kill -9 "$pid" 2>/dev/null || true
  rm -f "$STATE/daemon.pid"
fi

echo "BeamScale desktop appliance stopped"
