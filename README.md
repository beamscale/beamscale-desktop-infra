# BeamScale Desktop Infra

Single-host BeamScale appliance for developer-owned laptops and desktops.

This repo is intentionally separate from `beamscale/bmscl-infra`, which remains the production infrastructure authority.

## Topology

```text
Cloudflare edge -> cloudflared -> http://127.0.0.1:8080 -> one BEAM OS process / VM
                                                       -> P1 granddaddy supervisor
                                                       -> P2 replaceable runtime
                                                          -> router / deployment manager / budgets / invocation supervisor
```

`beamscale-desktop-daemon` is the machine lifecycle authority. CLI and desktop UIs are clients of its authenticated loopback API. There is no nginx/Caddy/HAProxy in the default path.

## CLI roles

The desktop appliance intentionally installs two different CLI surfaces:

- `bmscl` — Rust, external/end-user CLI for development, build, verification, deployment, and a small user-friendly local-hosting workflow.
- `bmscl-internal` — Gleam/OTP, internal/operator CLI for raw runtime/tunnel/update controls plus agent and infrastructure operations.

Automation in this repository must use `bmscl-internal` for daemon lifecycle operations. The end-user CLI must not become the transport for agent leasing, arbitrary infra dispatch, update-root changes, or custom daemon internals. The daemon reinforces the distinction with separate user and operator tokens.

## Quick start

```sh
./scripts/doctor.sh
./scripts/bootstrap.sh
```

The checked-in appliance manifest is the single desired-state authority. It pins exact source revisions; bootstrap materializes those exact SHAs and candidate revisions remain unpromoted until their upstream CI gates are green.

## Lifecycle

Unix/macOS:

```sh
./scripts/doctor.sh
./scripts/bootstrap.sh
./scripts/up.sh ./my-project
./scripts/status.sh
./scripts/install-service.sh   # optional: restore daemon at login
```

Windows PowerShell:

```powershell
.\scripts\doctor.ps1
.\scripts\bootstrap.ps1
.\scripts\up.ps1 -Project .\my-project
.\scripts\status.ps1
.\services\windows\install.ps1
```

The service installers point at the same appliance state directory used by bootstrap, including the daemon's `token`, `operator-token`, settings, and desired-state files. Uninstalling the service does not delete appliance state.

## ORES Compose local deployment

The audited local lifecycle is declared in `.ores-compose.yaml`:

```sh
ores-compose check .ores-compose.yaml
ores-compose plan .ores-compose.yaml
ores-compose up .ores-compose.yaml
```

Cloudflare/public ingress remains promotion-gated until the separate BEAM origin and dedicated remote-auth boundary are in the compose lifecycle.

The daemon source is exact-commit pinned, loopback-only, and executed from the built release binary. Stable promotion remains blocked until the daemon repository commits a Cargo lockfile and the build switches to `--locked`.

See [docs/local-deployment.md](docs/local-deployment.md) and [appliance.json](appliance.json) for the audited boundary and promotion gates.

## Shared desktop infra dependency

Generic desktop lifecycle/security behavior is moving to `ORESoftware/ores-common-desktop-infra`. This repo declares that dependency in its ORES appliance metadata and blocks stable promotion until an exact common-layer commit is pinned.

Current state is intentionally `awaiting-repository` with a null revision because GitHub does not yet expose that repository through the connected installation. Product-local behavior remains candidate-only until the common layer can be consumed by exact SHA.

