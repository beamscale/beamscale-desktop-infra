#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 "$ROOT/scripts/validate_manifest.py"

failed=0
for tool in git python3 cargo erl rebar3 gleam escript cloudflared curl; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf 'ok   %s\n' "$tool"
  else
    printf 'MISS %s\n' "$tool" >&2
    failed=1
  fi
done

if [[ "$(uname -s)" == Darwin ]]; then
  command -v caffeinate >/dev/null 2>&1 || {
    echo 'MISS caffeinate' >&2
    failed=1
  }
fi

STATE="${BMSCL_DESKTOP_STATE:-$ROOT/.desktop}"
if [[ -f "$STATE/env" ]]; then
  # shellcheck disable=SC1090
  source "$STATE/env"
  for cli in "$STATE/bin/bmscl" "${BMSCL_INTERNAL_CLI:-$STATE/bin/bmscl-internal}"; do
    if [[ -x "$cli" ]]; then
      printf 'ok   %s\n' "$cli"
    else
      printf 'MISS %s\n' "$cli" >&2
      failed=1
    fi
  done
fi

exit "$failed"
