#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 "$ROOT/scripts/validate_manifest.py"

failed=0
for tool in git python3 cargo erl rebar3 curl; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf 'ok   %s\n' "$tool"
  else
    printf 'MISS %s\n' "$tool" >&2
    failed=1
  fi
done

if [[ "${BMSCL_INSTALL_GLEAM_CLIENT:-0}" == "1" ]]; then
  for tool in gleam escript; do
    if command -v "$tool" >/dev/null 2>&1; then
      printf 'ok   %s\n' "$tool"
    else
      printf 'MISS optional Gleam dependency %s\n' "$tool" >&2
      failed=1
    fi
  done
fi

if [[ -n "${BMSCL_TUNNEL_NAME:-}" || "${BMSCL_REQUIRE_CLOUDFLARED:-0}" == "1" ]]; then
  if command -v cloudflared >/dev/null 2>&1; then
    printf 'ok   cloudflared\n'
  else
    printf 'MISS cloudflared (required for configured public exposure)\n' >&2
    failed=1
  fi
elif command -v cloudflared >/dev/null 2>&1; then
  printf 'ok   cloudflared (optional)\n'
else
  printf 'skip cloudflared (optional until local expose)\n'
fi

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
  for binary in     "$STATE/bin/beamscale-desktop-daemon"     "${BMSCL_SERVICE_BINARY:-$STATE/bin/beamscale-service}"     "${BMSCL_CLI:-$STATE/bin/bmscl}"     "$STATE/bin/bmscl-compiler"; do
    if [[ -x "$binary" ]]; then
      printf 'ok   %s\n' "$binary"
    else
      printf 'MISS %s\n' "$binary" >&2
      failed=1
    fi
  done
  if [[ "${BMSCL_INSTALL_GLEAM_CLIENT:-0}" == "1" ]]; then
    gleam_cli="$STATE/bin/bmscl-gleam"
    if [[ -x "$gleam_cli" ]]; then
      printf 'ok   %s\n' "$gleam_cli"
    else
      printf 'MISS %s\n' "$gleam_cli" >&2
      failed=1
    fi
  fi
fi

exit "$failed"
