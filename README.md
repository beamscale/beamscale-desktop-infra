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

The desktop appliance has one canonical lifecycle surface:

- `bmscl` — Rust, canonical end-user CLI for development, build, verification, deployment, service management, and local hosting.
- `bmscl-gleam` — optional Gleam/OTP peer client. Install it with `BMSCL_INSTALL_GLEAM_CLIENT=1`; it talks to the same daemon contract and is not a second lifecycle authority.

Automation in this repository uses the canonical Rust `bmscl local start|stop|restart|expose|unexpose|status` surface. Raw daemon implementation details are not a public appliance contract. Machine/operator authority remains protected by the daemon's separate operator credential and internal endpoints.

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
./scripts/install-service.sh   # optional: Rust-managed restore at login
```

Windows PowerShell:

```powershell
.\scripts\doctor.ps1
.\scripts\bootstrap.ps1
.\scripts\up.ps1 -Project .\my-project
.\scripts\status.ps1
.\scripts\install-service.ps1
```

The service wrappers delegate to the daemon repository's Rust `beamscale-service` manager. That manager owns typed launchd/systemd/Scheduled-Task rendering, validation, transactional upgrade rollback, and state-preserving uninstall. The appliance does not maintain a second shell-based service-manager implementation.

All service registrations point at the same appliance state directory used by bootstrap, including the daemon's `token`, `operator-token`, settings, replay journal, DNS ownership, and desired-state files. Uninstalling the service does not delete appliance state.

## Optional Gleam client

The core appliance does not require Gleam or `escript`. To materialize the alternate Gleam client during bootstrap:

```sh
BMSCL_INSTALL_GLEAM_CLIENT=1 ./scripts/bootstrap.sh
```

Both clients use the same authenticated loopback daemon and should observe the same desired/runtime/tunnel state.

## ORES Compose local deployment

The audited local lifecycle is declared in `.ores-compose.yaml`:

```sh
ores-compose check .ores-compose.yaml
ores-compose plan .ores-compose.yaml
ores-compose up .ores-compose.yaml
```

Cloudflare/public ingress remains promotion-gated until the separate BEAM origin and dedicated remote-auth boundary are in the compose lifecycle.

The daemon source is exact-commit pinned, loopback-only, and executed from the built release binary. The compose file uses the canonical `BMSCL_DAEMON_LISTEN` variable; obsolete compatibility aliases are not part of the appliance contract. The desktop daemon is now exact-revision and lockfile pinned, and daemon builds use `--locked`. Stable promotion still requires committed lockfiles for the compiler and canonical Rust CLI, plus executed exact-head CI/release evidence.

See [docs/local-deployment.md](docs/local-deployment.md) and [appliance.json](appliance.json) for the audited boundary and promotion gates.

## Shared desktop infra dependency

Generic desktop lifecycle/security behavior is owned by `ORESoftware/ores-common-desktop-infra`. This repo consumes that dependency through an exact immutable revision recorded in its ORES appliance metadata.

The common platform is pinned at `c98aee842535429bc07b5e4437a2fb84d8f00d25` in `appliance.json`. Candidate promotion must keep that exact revision aligned with the shared Rust consumer checker; updates are explicit revision bumps, never mutable branch dependencies. `.github/workflows/common-layer-certification.yml` performs an authenticated exact-SHA checkout and executes that checker without persisting credentials.


## Hot-reload routing and middleware

This product consumes the shared ORES generation model with **BEAM route ownership + OTP hot-code/release upgrades** as its default. Routing/middleware is a separate lifecycle and memory/failure boundary from standalone servers and lambda/actor workers, so route or middleware updates do not restart unrelated compute.

`hot-reload-policy.json` declares the product policy. The edge may optionally use nginx, HAProxy, or Caddy. nginx uses validated worker-generation reloads; HAProxy prefers Runtime API changes and falls back to master-worker reload for structural changes; Caddy uses its transactional Admin API. Proxy-managed application routes are opt-in and limited to declarative routing/middleware. Arbitrary middleware code stays in BEAM, Wasm, or a separately supervised process generation.

Long-lived WebSockets/streams are bounded by a hard generation drain timeout so repeated reloads cannot accumulate old generations indefinitely.
