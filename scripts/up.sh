#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="${BMSCL_DESKTOP_STATE:-$ROOT/.desktop}"
test -f "$STATE/env" || { echo "run scripts/bootstrap.sh first" >&2; exit 1; }
source "$STATE/env"
mkdir -p "$BMSCL_DESKTOP_HOME" "$STATE/logs"

if [[ ! -f "$STATE/daemon.pid" ]] || ! kill -0 "$(cat "$STATE/daemon.pid")" 2>/dev/null; then
  nohup "$STATE/bin/beamscale-desktop-daemon" >>"$STATE/logs/daemon.log" 2>&1 &
  echo $! > "$STATE/daemon.pid"
fi

for _ in {1..50}; do
  curl --fail --silent http://127.0.0.1:9587/health >/dev/null 2>&1 && break
  sleep 0.1
done
curl --fail --silent http://127.0.0.1:9587/health >/dev/null

if [[ $# -gt 0 ]]; then
  "$STATE/bin/bmscl" local start "$1"
fi

if [[ -n "${BMSCL_TUNNEL_NAME:-}" ]]; then
  args=(local tunnel start "$BMSCL_TUNNEL_NAME")
  [[ -n "${BMSCL_TUNNEL_HOSTNAME:-}" ]] && args+=(--hostname "$BMSCL_TUNNEL_HOSTNAME")
  [[ -n "${BMSCL_TUNNEL_CONFIG:-}" ]] && args+=(--config "$BMSCL_TUNNEL_CONFIG")
  "$STATE/bin/bmscl" "${args[@]}"
fi

"$STATE/bin/bmscl" local status
