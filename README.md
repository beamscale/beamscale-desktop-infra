# BeamScale Desktop Infra

Single-host infrastructure for self-hosting BeamScale on a trusted developer laptop or desktop.

This repository is intentionally separate from `beamscale/bmscl-infra`. Production Kubernetes, multi-host fleet, regional placement, and hostile-tenant host isolation stay there.

## Desktop topology

```
Cloudflare edge
      |
 cloudflared
      |
127.0.0.1:8081
      |
one BEAM OS process / VM
      |
 bmscl_sup (P1 / granddaddy)
      |
 bmscl_runtime_sup (P2)
      |
 fresh Erlang invocation processes (P3)
```

There is no nginx/Caddy/HAProxy in the default path. Cloudflare Tunnel terminates directly at the loopback BEAM ingress.

"One Erlang process" means one BEAM **OS process**. Inside it, normal supervised OTP processes still exist. P1 stays intentionally small; routing, deployment generations, budgets, and invocation supervision belong below it.

## Lifecycle authority

`beamscale-desktop-daemon` is the machine authority. CLI and desktop UIs are clients of its authenticated loopback API; they do not independently own a runtime or tunnel.

The checked-in `appliance.json` pins every source component by a full commit SHA. Candidate components are deliberately marked `promoted: false` until their upstream CI is green.

## Bootstrap

Prerequisites: Git, Python 3, Rust/Cargo, Erlang/OTP + rebar3, and Cloudflare's `cloudflared`. Private component repositories require normal GitHub read credentials.

```sh
./scripts/bootstrap.sh
./scripts/doctor.sh
./scripts/up.sh /path/to/beamscale-project
```

To publish through an already-created named Cloudflare Tunnel:

```sh
export BMSCL_TUNNEL_NAME=beamscale-local
export BMSCL_TUNNEL_HOSTNAME=dev.example.com
export BMSCL_TUNNEL_CONFIG="$HOME/.cloudflared/config.yml"
./scripts/up.sh /path/to/project
```

Stop the runtime, tunnel, and daemon with:

```sh
./scripts/down.sh
```

## Update and rollback

Desktop updates are manifest-driven and exact-revision only. This repo does not activate mutable `latest` state. A release promotion changes reviewed SHAs in `appliance.json`; rollback means restoring the previous known-good manifest and rebuilding/restarting through the daemon.

Tenant Lambda/Gleam code continues to use BeamScale's generation/slot hot-load path inside the existing BEAM VM. P2 runtime replacement drains and swaps the inner tree. P1/VM restart is reserved for incompatible OTP/runtime or critical updates.

## OS service integration

Templates live under `services/` for systemd user services, launchd, and Windows Task Scheduler. They intentionally bind the daemon only to loopback.

The desktop UI's **Keep BeamScale alive during lock-screen** setting is implemented by the daemon. macOS should use `caffeinate -i -w <daemon-pid>`, preventing idle system sleep without forcing the display awake.

## Security invariants

- no production `bmscl-infra` dependency;
- daemon API is loopback-only and bearer authenticated;
- Cloudflare credentials/tokens are never committed;
- no arbitrary shell execution endpoint;
- child processes are argv-based and lifecycle-owned by the daemon;
- all appliance component revisions are immutable full Git SHAs;
- public ingress points only at a loopback origin.
