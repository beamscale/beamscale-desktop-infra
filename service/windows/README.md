# Windows user-service integration

Install `beamscale-desktop-daemon` as a per-user background task/service with an absolute executable path and an absolute config path. Do not place Cloudflare credentials or bearer/session secrets in command-line arguments.

The daemon should expose its normal Windows local IPC endpoint through a current-user ACL'd named pipe. The installer must create state/config directories with current-user-only permissions where practical.

Service installation is intentionally templated until the daemon's Windows packaging target is available; do not use an elevated system-wide service merely to supervise a user-owned BeamScale desktop runtime.
