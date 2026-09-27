#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="${BMSCL_DESKTOP_STATE:-$ROOT/.desktop}"
python3 "$ROOT/scripts/validate_manifest.py"
failed=0
for tool in git python3 cargo rebar3 cloudflared curl; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf 'ok   %s\n' "$tool"
  else
    printf 'MISS %s\n' "$tool" >&2
    failed=1
  fi
done
for binary in beamscale-desktop-daemon bmscl bmscl-compiler; do
  if [[ -x "$STATE/bin/$binary" ]]; then
    printf 'ok   %s\n' "$STATE/bin/$binary"
  else
    printf 'MISS %s (run scripts/bootstrap.sh)\n' "$STATE/bin/$binary" >&2
    failed=1
  fi
done
if [[ -f "$STATE/daemon.pid" ]] && kill -0 "$(cat "$STATE/daemon.pid")" 2>/dev/null; then
  echo "ok   daemon pid $(cat "$STATE/daemon.pid")"
else
  echo "info daemon not running"
fi
exit "$failed"
