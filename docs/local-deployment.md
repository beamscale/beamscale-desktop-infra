# BeamScale local desktop deployment

This repository uses `ORESoftware/ores-compose` for the declared laptop/desktop lifecycle.

## Local orchestration

```sh
ores-compose check .ores-compose.yaml
ores-compose plan .ores-compose.yaml
ores-compose up .ores-compose.yaml
```

Stop it from another terminal with:

```sh
ores-compose down .ores-compose.yaml
```

The manifest pins an exact 40-hex desktop-daemon commit under `tmp/dev`, builds it before startup, executes the built release binary directly, and binds the daemon only to the loopback address recorded in `appliance.json`.

The compose graph starts the machine-local BeamScale daemon only. It explicitly disables the daemon's default bare-Erlang auto-start because the pinned supervisor/runtime is a separate repository and is not yet part of this compose dependency graph. Full BEAM runtime and public ingress remain promotion-gated.

## Cloudflare boundary

A dedicated/static/public IP is not required. Cloudflare account/API credentials must never be copied to an end-user machine or committed here.

For appliances marked `cloudflare.mode = "gated"`, `appliance.json` records the intended loopback origin and hostname/token metadata, but this repository intentionally does **not** ship a runnable `.ores-compose.public.yaml`. Promotion requires both:

1. the real public origin to be started by the declared local lifecycle; and
2. a remote authentication boundary distinct from the daemon's privileged local-control bearer.

For `cloudflare.mode = "not-required"`, the product uses an outbound authenticated agent path and does not need inbound tunneling.

## Reproducibility gate

The daemon source is commit-pinned, but the pinned daemon repository does not currently commit a `Cargo.lock`. Therefore `promotion_gates.daemon_lockfile_committed` remains false and this candidate must not be described as fully transitive-dependency reproducible.

Before stable promotion, commit the daemon lockfile, change the build to `cargo build --locked --release`, and make CI enforce it.

## Upgrade model

Upgrades change the immutable daemon source commit only after upstream review/CI. Mutable `latest` refs are forbidden.

## Common desktop implementation layer

Generic host/security/lifecycle behavior is owned by `ORESoftware/ores-common-desktop-infra`.

The appliance pins the shared implementation at:

```text
repository = ORESoftware/ores-common-desktop-infra
revision   = c98aee842535429bc07b5e4437a2fb84d8f00d25
checkout   = tmp/dev/ores-common-desktop-infra
status     = pinned
```

`promotion_gates.common_layer_pinned` is true because the exact source identity is recorded. `promotion_gates.common_layer_ci_verified` remains false until the authenticated certification workflow executes the shared Rust consumer checker successfully.

The certification workflow fails closed when its approved read-only fleet credential is unavailable, verifies the checked-out commit before execution, and does not persist checkout credentials. Stable promotion remains blocked while common-layer CI evidence is false.

Mutable branches or tags are not acceptable release dependencies.
