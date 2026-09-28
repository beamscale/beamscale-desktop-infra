# Desktop CLI repository boundary

Status: accepted for the current BeamScale desktop-control-plane work.

## Decision

`beamscale/bmscl-cli` is the canonical Rust CLI for both hosted BeamScale operations and machine-local desktop operations. The desktop command family lives under its typed `bmscl local ...` surface.

Do **not** create a second `bmscl-desktop-cli` repository merely to mirror the names of `beamscale-desktop-infra` and `beamscale-desktop-daemon`. A second Rust CLI would create two public argv contracts, two release streams, and a risk that client-side lifecycle behavior diverges.

`beamscale/bmscl-cli-gleam` is an intentionally separate language-parity client. It may expose the same local operations, but it is not a machine-lifecycle owner and must not become an independent supervisor.

## Ownership

- `beamscale-desktop-infra`: declarative desired state, service packaging, local topology, and non-secret Cloudflare/tunnel configuration.
- `beamscale-desktop-daemon`: the sole machine-local lifecycle writer for the Beam runtime, workers/actors, tunnel, keep-awake behavior, updates, recovery, and local state.
- `bmscl-cli`: canonical Rust operator CLI and desktop/local client.
- `bmscl-cli-gleam`: optional parity client for the same daemon contract.
- `bmscl-desktop-app.rs` and `bmscl-flutter`: peer UI clients of the daemon contract.

No CLI or UI client may directly supervise the Beam runtime, cloudflared, updater, or keep-awake process when the daemon is present.

## Runtime semantics

This repo-boundary decision does not change BeamScale runtime semantics. The local system must still preserve the one-long-lived-BEAM topology, flagship one-shot actor behavior, supported long-lived Phoenix/WebSocket actors, and the durable queue/lock semantics implemented by BeamScale. Client commands request typed state transitions; the daemon and runtime remain authoritative.

## Contract and release gates

The local control protocol is versioned independently of CLI packaging. CLI releases must remain compatible with the supported daemon protocol window and fail closed on unsupported protocol versions. Exact-head CI, package provenance, and end-to-end desktop evidence are required before calling the family complete.
