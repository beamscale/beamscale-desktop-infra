# BeamScale Desktop Infra

Single-host BeamScale appliance for developer-owned laptops and desktops.

This repo is intentionally separate from `beamscale/bmscl-infra`, which remains the production infrastructure authority.

## Topology

```text
Cloudflare edge -> cloudflared -> 127.0.0.1:8081 -> one BEAM OS process / VM
                                                -> P1 granddaddy supervisor
                                                -> P2 replaceable runtime
                                                   -> router / deployment manager / budgets / invocation supervisor
```

`beamscale-desktop-daemon` is the machine lifecycle authority. CLI and desktop UIs are clients of its authenticated loopback API. There is no nginx/Caddy/HAProxy in the default path.

## Quick start

```sh
./scripts/doctor.sh
./scripts/bootstrap.sh
```

The checked-in appliance manifest pins exact source revisions. Candidate revisions are explicit; promotion requires green upstream CI.
