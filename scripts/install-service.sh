#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="${BMSCL_DESKTOP_STATE:-$ROOT/.desktop}"
test -f "$STATE/env" || { echo "run scripts/bootstrap.sh first" >&2; exit 1; }
source "$STATE/env"

SERVICE="${BMSCL_SERVICE_BINARY:-$STATE/bin/beamscale-service}"
DAEMON="$STATE/bin/beamscale-desktop-daemon"
test -x "$SERVICE" || { echo "Rust service manager missing: $SERVICE" >&2; exit 1; }
test -x "$DAEMON" || { echo "daemon binary missing: $DAEMON" >&2; exit 1; }

"$SERVICE" install --binary "$DAEMON" --data-root "$BMSCL_DESKTOP_HOME"
"$SERVICE" status
