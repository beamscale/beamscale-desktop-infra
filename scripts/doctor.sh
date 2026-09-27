#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 "$ROOT/scripts/validate_manifest.py"
failed=0
for tool in git python3 cargo erl rebar3 cloudflared curl; do
  if command -v "$tool" >/dev/null 2>&1; then printf 'ok   %s\n' "$tool"; else printf 'MISS %s\n' "$tool" >&2; failed=1; fi
done
if [[ "$(uname -s)" == Darwin ]]; then command -v caffeinate >/dev/null 2>&1 || { echo 'MISS caffeinate' >&2; failed=1; }; fi
exit "$failed"
