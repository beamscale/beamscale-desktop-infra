#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/validate_manifest.py
for x in git python3 cargo erl rebar3 cloudflared; do command -v "$x" >/dev/null || { echo "missing required tool: $x" >&2; exit 1; }; done
if [ "$(uname -s)" = Darwin ]; then command -v caffeinate >/dev/null || { echo 'missing caffeinate' >&2; exit 1; }; fi
echo 'BeamScale desktop appliance prerequisites OK'
echo 'Candidate revisions remain promotion-gated by upstream CI.'
