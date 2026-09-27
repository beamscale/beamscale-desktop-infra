# BeamScale local/desktop agent control plane

`beamscale-desktop-daemon` is the coordinator for a machine-local BeamScale deployment. The CLI and UI clients do not independently mutate runtime state when the daemon is available.

The shared wire contract is `bmscl.local-control/v1` from `beamscale/bmscl-interfaces`.

## Agent topology

```text
                         bmscl-cli
                             |
                             v
                  beamscale-desktop-daemon
                    /        |         \
                   /         |          \
          Rust desktop   Flutter UI   infra agents
                                   beam-runtime / tunnel / ...

remote/mobile Flutter hosting agent
            |
            | outbound authenticated poll/lease
            v
      scoped agent gateway
            |
            v
   beamscale-desktop-daemon/control plane
```

The daemon remains the single lifecycle writer for processes on its host. Desktop UIs may register as agents for UI/device-specific capabilities, but they must not race the daemon for ownership of the BEAM runtime or `cloudflared`.

## Agent classes

- `daemon`: coordinator and machine-local lifecycle authority.
- `rust_desktop`: native Rust/Slint desktop application.
- `flutter_desktop`: Flutter application on macOS/Windows/Linux.
- `flutter_mobile`: Android/iOS device agent. Capabilities are advertised dynamically and must reflect what the OS/runtime can actually execute.
- `infra_process`: a supervised process or logical infra component from this repository.

An agent advertises only named capabilities. There is deliberately no arbitrary shell command capability.

## Command flow

1. Agent registers identity, kind, platform, labels, and capabilities.
2. Agent heartbeats while available.
3. `bmscl-cli` creates a command targeted to an `agent_id` through the coordinator.
4. A local agent may receive it immediately; a remote/mobile agent polls and leases work outbound.
5. The lease is time bounded and includes an opaque lease token.
6. The agent posts a terminal result using that lease token.
7. Idempotency keys prevent retries from turning one local deploy into multiple concurrent deploys.

The queue/lease shape is intentional for phones, laptops behind NAT, and intermittently connected devices. The control plane never requires an inbound listener on a phone.

## CLI surface

Target shape:

```text
+bmscl local agents list
+bmscl local agents get <agent-id>
+bmscl local dispatch <agent-id> <operation> [--payload file.json]
+bmscl local deploy --target <agent-id> <artifact-dir>
```

Existing `bmscl local runtime ...`, tunnel, keep-awake, and update commands remain convenience commands for the default local daemon/runtime target.

## Desktop-infra processes

Each managed component has a stable control-plane identity. Initial examples are declared in `manifests/control-plane-agents.example.json`:

- `infra:beam-runtime`
- `infra:cloudflare-tunnel`

Additional local services should add stable IDs and the minimum required capabilities. Process definitions remain declarative in this repository; the daemon performs the actual lifecycle mutation.

## Remote/mobile security boundary

The existing daemon admin API and admin bearer token remain loopback/OS-IPC only. Do not expose that token through Cloudflare Tunnel or a LAN listener.

Remote/mobile agents use a separate scoped credential obtained through an explicit pairing/enrollment flow. The remote surface exposes only agent registration/heartbeat, command lease, and result submission needed by that agent. It must enforce agent identity and advertised capabilities server side.

Tunnel credentials, daemon admin tokens, agent credentials, and lease tokens must not be logged or placed in argv.

## Mobile hosting

`bmscl-flutter` can participate as `flutter_mobile`, but hosting is capability gated rather than assumed. Android/iOS background-execution restrictions differ, so an app reports only operations it can actually perform on that device. A command requiring an unavailable capability is rejected with a typed result instead of attempting a best-effort shell action.

Suitable mobile work includes bounded hosting tasks, actor/work execution that the mobile runtime supports, health/status work, or jobs explicitly designed for intermittent devices. Critical always-on ingress should continue to target a host that can satisfy the required availability contract.
