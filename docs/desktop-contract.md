# BeamScale desktop self-host contract v1

This document defines the contract between desktop infrastructure, `beamscale-desktop-daemon`, both BeamScale CLIs, and both desktop applications.

## 1. Authority

`beamscale-desktop-daemon` is the only component allowed to mutate machine-local BeamScale lifecycle state once installed. The CLI and desktop apps are clients. `beamscale-desktop-infra` owns declarative topology, platform integration, security policy, and conformance fixtures.

Direct CLI-only `bmscl dev` remains useful when no daemon is installed, but when the daemon is reachable local lifecycle commands must route through it instead of creating a second Erlang VM.

## 2. IPC

Preferred transports:

- macOS/Linux: Unix domain socket owned by the current user;
- Windows: named pipe restricted to the current user;
- test/debug fallback: loopback-only HTTP on `127.0.0.1`/`::1`.

Every request and response carries a protocol version. Unknown major versions fail closed with an actionable compatibility error.

Minimum operation family:

```text
status
doctor
start
stop
restart
drain
suspend
resume
upgrade.plan
upgrade.apply
upgrade.rollback
tunnel.status
tunnel.start
tunnel.stop
tunnel.configure
keep_alive.get
keep_alive.set
logs.follow
events.follow
```

Mutating operations return an operation ID so clients can follow progress without guessing from process state.

## 3. Runtime identity

The daemon records more than a PID before signaling a child process. Runtime ownership evidence includes the PID plus stable identity such as process start time, executable identity, and activated build/version. PID reuse must never allow BeamScale to signal an unrelated process.

## 4. Erlang lifecycle

Desktop self-hosting preserves one long-lived Erlang VM with BeamScale's P1/P2/P3 model:

```text
P1: long-lived Erlang VM + outer supervisor
P2: replaceable routing/middleware/runtime subtree
P3: actor/Lambda generations
```

A user-code generation update should activate the new generation without replacing P1. Runtime-shape updates drain/replace P2 while preserving P1 when compatible. Rejected updates leave the last-known-good generation active.

## 5. Suspend/resume

Suspend is an explicit state transition, not an untracked OS signal. The daemon:

1. acquires the local lifecycle lease;
2. marks intent as `suspending`/`suspended` in durable local state;
3. prevents new work from being routed;
4. waits for the configured drain deadline or applies the selected force policy;
5. suspends eligible processes;
6. records enough identity to resume safely.

Resume verifies process identity and runtime compatibility before accepting new work.

## 6. Cloudflare Tunnel

The public edge is optional and outbound-only.

Persistent installs use a **named tunnel with a credentials file** kept outside repositories and worktrees. The daemon never emits a tunnel token into argv. Token/environment mode is development-only and secrets are redacted from logs, events, diagnostics, crash reports, and UI state.

A tunnel may become externally healthy only after the local BeamScale readiness probe succeeds. Tunnel health and runtime health are distinct fields so clients can show cases such as `runtime=healthy, tunnel=down`.

## 7. Power inhibition

`keep_alive=true` is a daemon setting shared by all clients. Platform implementations may use native APIs or supervised helpers (`caffeinate` on macOS), but helper lifecycle belongs to the daemon. No UI or CLI launches its own loop.

The inhibitor is released on:

- explicit setting disable;
- daemon shutdown;
- explicit BeamScale stop when policy requests it;
- failed ownership validation.

## 8. Updates and rollback

Update workflow:

```text
resolve -> download -> verify -> stage -> preflight -> drain -> activate -> ready -> commit
                                                        \-> failure -> rollback
```

Artifacts are verified before activation. The last-known-good version remains addressable until the new version passes readiness. Daemon updates and BeamScale runtime hot updates are separate operations.

## 9. Client behavior

All four clients must converge on the same machine state:

- `bmscl-cli`
- `bmscl-cli-gleam`
- `beamscale-flutter`
- `beamscale-desktop-app.rs`

No client invents its own status model. UI toggles issue daemon operations and then render daemon-observed state. The same status includes `host_kind`, advertised host capabilities, and manifest-backed infra component state so a CLI action is visible immediately in both desktop UIs.

The shared contract intentionally includes `host_kind=mobile` and mobile-safe capability advertisement. A mobile host is **not** implemented by exposing the desktop daemon on a LAN with a bearer token. Android/iOS hosting agents must implement the same typed task/capability semantics behind an authenticated device transport suitable for mobile background execution. This keeps the desktop daemon loopback-only while allowing the Flutter app to grow into a constrained hosting agent.

CLI examples targeted by the contract:

```text
bmscl desktop status
bmscl desktop start
bmscl desktop stop
bmscl desktop suspend
bmscl desktop resume
bmscl desktop tunnel status
bmscl desktop tunnel up
bmscl desktop infra list
bmscl desktop infra restart beam-runtime
bmscl desktop keep-alive on
bmscl desktop upgrade --check
```

The Gleam CLI exposes equivalent semantics.

## 10. Locks

Single-machine exclusion starts with a local lock/lease owned by the daemon. Cross-machine/distributed coordination must use `oresoftware/ores-locks-and-leases` with the currently approved durable backend; desktop infra does not define another lock protocol.

## 11. Conformance requirements

CI in this repo will ultimately provide fixtures proving:

- daemon/CLI/app protocol version compatibility;
- state-machine transitions;
- stale PID protection;
- update rollback;
- tunnel token redaction and argv rejection;
- loopback-only origin defaults;
- keep-alive ownership/release;
- one-VM invariant during normal BeamScale updates.
