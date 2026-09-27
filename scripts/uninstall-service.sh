#!/usr/bin/env bash
set -euo pipefail

case "$(uname -s)" in
  Darwin)
    launchctl bootout "gui/$(id -u)/com.beamscale.desktop-daemon" >/dev/null 2>&1 || true
    rm -f "$HOME/Library/LaunchAgents/com.beamscale.desktop-daemon.plist"
    ;;
  Linux)
    systemctl --user disable --now beamscale-desktop-daemon.service >/dev/null 2>&1 || true
    rm -f "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/beamscale-desktop-daemon.service"
    systemctl --user daemon-reload
    ;;
  *)
    echo "unsupported OS; remove the Windows scheduled task with services/windows/uninstall.ps1" >&2
    exit 1
    ;;
esac

echo "BeamScale desktop daemon user service removed; appliance state was preserved."
