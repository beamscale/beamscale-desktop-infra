#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="${BMSCL_DESKTOP_STATE:-$ROOT/.desktop}"
BINARY="$STATE/bin/beamscale-desktop-daemon"
RUNTIME="$STATE/runtime"
LOGS="$STATE/logs"

test -x "$BINARY" || { echo "run scripts/bootstrap.sh first; missing $BINARY" >&2; exit 1; }
mkdir -p "$RUNTIME" "$LOGS"

escape_sed() {
  printf '%s' "$1" | sed -e 's/[&|]/\\&/g'
}

case "$(uname -s)" in
  Darwin)
    target="$HOME/Library/LaunchAgents/com.beamscale.desktop-daemon.plist"
    mkdir -p "$(dirname "$target")"
    sed       -e "s|__BINARY__|$(escape_sed "$BINARY")|g"       -e "s|__RUNTIME_DIR__|$(escape_sed "$RUNTIME")|g"       -e "s|__LOG_DIR__|$(escape_sed "$LOGS")|g"       "$ROOT/services/macos/com.beamscale.desktop-daemon.plist" > "$target"
    chmod 600 "$target"
    launchctl bootout "gui/$(id -u)/com.beamscale.desktop-daemon" >/dev/null 2>&1 || true
    launchctl bootstrap "gui/$(id -u)" "$target"
    launchctl enable "gui/$(id -u)/com.beamscale.desktop-daemon"
    launchctl kickstart -k "gui/$(id -u)/com.beamscale.desktop-daemon"
    ;;
  Linux)
    command -v systemctl >/dev/null 2>&1 || {
      echo "systemctl is required to install the Linux user service" >&2
      exit 1
    }
    unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
    target="$unit_dir/beamscale-desktop-daemon.service"
    mkdir -p "$unit_dir"
    sed       -e "s|__BINARY__|$(escape_sed "$BINARY")|g"       -e "s|__RUNTIME_DIR__|$(escape_sed "$RUNTIME")|g"       -e "s|__STATE_DIR__|$(escape_sed "$STATE")|g"       "$ROOT/services/linux/beamscale-desktop-daemon.service" > "$target"
    chmod 600 "$target"
    systemctl --user daemon-reload
    systemctl --user enable --now beamscale-desktop-daemon.service
    ;;
  *)
    echo "unsupported OS; use services/windows/install.ps1 on Windows" >&2
    exit 1
    ;;
esac

echo "BeamScale desktop daemon user service installed for state: $STATE"
