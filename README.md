# BeamScale Desktop Infra

Single-host infrastructure for running BeamScale on a developer-owned laptop or desktop.

This repository is intentionally separate from `beamscale/bmscl-infra`, which remains the hosted/server infrastructure authority. Desktop self-hosting has different trust, lifecycle, power-management, update, and credential boundaries.

## Ownership

| Repository | Responsibility |
| --- | --- |
| `beamscale/beamscale-desktop-infra` | desired desktop topology, install/service definitions, host integration, tunnel templates, health/update policy, conformance fixtures |
| `beamscale/beamscale-desktop-daemon` | machine-local lifecycle authority; reconciles desired state and owns child processes, updates, suspend/resume, power inhibition, tunnel lifecycle, and local IPC |
| `beamscale/bmscl-cli` | Rust CLI client for daemon-backed local lifecycle operations |
| `beamscale/bmscl-cli-gleam` | Gleam/OTP CLI client with the same daemon protocol |
| `beamscale/bmscl-flutter` | desktop UI client for daemon status/actions/settings |
| `beamscale/bmscl-desktop-app.rs` | native Rust desktop UI client for daemon status/actions/settings |
| `beamscale/bmscl-infra` | hosted/server infrastructure; not authoritative for an end-user desktop |

The daemon is the **single writer** for desktop runtime state. CLIs and desktop apps must not independently spawn or kill the BeamScale runtime or `cloudflared` when the daemon is available.

## Desktop topology

```text
bmscl-cli / bmscl-cli-gleam / Flutter / Rust desktop app
                         |
                         v
              beamscale-desktop-daemon
                 |               |
                 v               v
        one long-lived       cloudflared
          Erlang VM          named tunnel
                 |
                 v
          Erlang actor workers
```

The one-VM model preserves BeamScale's P1/P2/P3 lifecycle and hot-upgrade behavior. Desktop infrastructure must not replace it with one VM per actor/worker.

## Public exposure

Public exposure is opt-in. The BeamScale origin stays loopback-only and `cloudflared` is an outbound connector.

Persistent installs use a named Cloudflare Tunnel and a credentials file outside repositories/worktrees. Tunnel credentials must never appear in argv, logs, service definitions, or crash reports. Short-lived development may inject a token through a protected environment/secret store, but the daemon must never copy it into argv.

The daemon validates local readiness before bringing a public route online and withdraws/stops the route when the runtime is intentionally drained or unhealthy.

## Lock-screen / power behavior

Both desktop apps expose one daemon-backed setting equivalent to:

```text
Keep BeamScale alive while this machine is locked/asleep
```

The daemon owns the platform-specific inhibitor. On macOS it may supervise `caffeinate` or use a native power-management API; clients do not launch competing keep-awake loops. Disabling the setting releases the inhibitor without stopping BeamScale. Explicit `stop` always wins.

## Runtime states

Clients render daemon-authoritative states from a shared vocabulary:

```text
stopped
starting
healthy
degraded
draining
updating
suspended
resuming
failed
```

Transitions include timestamps and machine-readable reason/error codes.

## Updates

Desktop updates are transactional: stage + verify, drain the replaceable runtime subtree, activate, verify readiness, commit the version marker only after success, and automatically roll back a failed activation. The daemon and the supervised Erlang runtime are separate update targets; an Erlang hot upgrade must not require replacing the daemon.

## Initial deliverables

This repo should contain the declarative artifacts consumed/tested by the daemon:

- macOS, Linux, and Windows service/install definitions;
- an `ores-compose` desktop development/test profile;
- Cloudflare Tunnel templates with secret material excluded;
- health/readiness probes;
- update/rollback policy and fixtures;
- daemon IPC conformance fixtures shared with both CLIs and both desktop apps;
- CI checks rejecting plaintext credentials and token-bearing `cloudflared` argv.

See `docs/desktop-contract.md` for the control and security contract.