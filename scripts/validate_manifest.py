#!/usr/bin/env python3
import json
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parents[1]
data = json.loads((root / "appliance.json").read_text())
errors = []

if data.get("schema") != "ores.desktop-appliance/v1":
    errors.append("unexpected schema")
if data.get("product") != "beamscale":
    errors.append("product must be beamscale")

host = data.get("host", {})
if host.get("daemon_listen") != "127.0.0.1:9587":
    errors.append("daemon must bind 127.0.0.1:9587")
if host.get("public_origin") != "http://127.0.0.1:8080":
    errors.append("public origin must be loopback :8080")
if host.get("default_reverse_proxy") != "none":
    errors.append("default reverse proxy must be none")

seen = set()
for section in ("components", "clients"):
    for component in data.get(section, []):
        name = component.get("name")
        rev = component.get("rev", "")
        key = (section, name)
        if not name or key in seen:
            errors.append(f"{section}: duplicate/missing component name")
        seen.add(key)
        if not re.fullmatch(r"[0-9a-f]{40}", rev):
            errors.append(f"{name}: rev must be exact SHA")
        if not str(component.get("repo", "")).startswith("beamscale/"):
            errors.append(f"{name}: repo must be beamscale/*")

required = {"desktop-daemon", "supervisor", "compiler", "cli"}
component_names = {c.get("name") for c in data.get("components", [])}
missing = required - component_names
if missing:
    errors.append("missing components: " + ",".join(sorted(missing)))

if data.get("cloudflare", {}).get("origin") != host.get("public_origin"):
    errors.append("Cloudflare origin must equal host public_origin")
if data.get("update", {}).get("allow_mutable_latest") is not False:
    errors.append("mutable latest must be forbidden")
if data.get("cloudflare", {}).get("credentials_in_repo") is not False:
    errors.append("Cloudflare credentials must stay out of repo")

service = data.get("service_authority", {})
if service.get("owner") != "desktop-daemon":
    errors.append("persistent service authority must belong to desktop-daemon")
if service.get("transport") != "operator-authenticated-loopback-rpc":
    errors.append("persistent service lifecycle must use operator-authenticated loopback RPC")
if service.get("operator_token_file") != "operator-token":
    errors.append("operator service authority must use the distinct private operator-token")
for field in (
    "client_helper_execution",
    "client_helper_selection",
    "client_service_argv",
):
    if service.get(field) is not False:
        errors.append(f"service authority field {field} must be false")
for field in (
    "mutation_idempotency",
    "mutation_maintenance_gate",
    "uninstall_preserves_current_daemon",
):
    if service.get(field) is not True:
        errors.append(f"service authority field {field} must be true")
if service.get("service_helper") != "daemon-packaged-sibling":
    errors.append("service helper must be selected only as the daemon-packaged sibling")
if service.get("install_mode") != "register-without-competing-start":
    errors.append("daemon-mediated service install must not launch a competing daemon")

logs = data.get("child_logs", {})
if logs.get("owner") != "desktop-daemon":
    errors.append("child log capture must be daemon-owned")
if logs.get("retention_hours") != 6:
    errors.append("child log retention must remain exactly six hours")
if logs.get("max_segment_bytes") != 4 * 1024 * 1024:
    errors.append("child log segment cap must remain 4 MiB")
if logs.get("max_parts_per_hour_per_stream") != 4:
    errors.append("child log hourly part cap must remain four")
if sorted(logs.get("components", [])) != ["runtime", "tunnel"]:
    errors.append("child logs must be limited to runtime and tunnel")
if sorted(logs.get("streams", [])) != ["stderr", "stdout"]:
    errors.append("child logs must capture stdout and stderr")
if logs.get("unix_directory_mode") != "0700" or logs.get("unix_file_mode") != "0600":
    errors.append("Unix child-log permissions must remain 0700 directories / 0600 files")
if logs.get("raw_log_api") is not False:
    errors.append("raw child logs must not be exposed through the daemon API")
if logs.get("drain_after_storage_saturation") is not True:
    errors.append("child pipes must continue draining after the bounded log budget saturates")

profiles = data.get("cli_profiles", {})
end_user = profiles.get("end_user", {})
alternate = profiles.get("alternate_end_user", {})
if (
    end_user.get("command") != "bmscl"
    or end_user.get("implementation") != "rust"
    or end_user.get("audience") != "external"
    or end_user.get("canonical") is not True
):
    errors.append("end_user CLI profile must be canonical external Rust bmscl")
if (
    alternate.get("command") != "bmscl-gleam"
    or alternate.get("implementation") != "gleam"
    or alternate.get("audience") != "external"
    or alternate.get("canonical") is not False
    or alternate.get("install") != "optional"
):
    errors.append("alternate_end_user CLI profile must be optional external Gleam bmscl-gleam")

component_by_name = {c.get("name"): c for c in data.get("components", [])}
client_by_name = {c.get("name"): c for c in data.get("clients", [])}
if component_by_name.get("cli", {}).get("role") != "end-user-cli":
    errors.append("components/cli must be role=end-user-cli")
if client_by_name.get("cli-gleam", {}).get("role") != "alternate-end-user-cli":
    errors.append("clients/cli-gleam must be role=alternate-end-user-cli")
if end_user.get("source") != "components/cli":
    errors.append("end_user CLI must source components/cli")
if alternate.get("source") != "clients/cli-gleam":
    errors.append("alternate end-user CLI must source clients/cli-gleam")

compose = (root / ".ores-compose.yaml").read_text()
compose_commit = re.search(
    r"^\s*commit:\s*([0-9a-f]{40})\s*$",
    compose,
    re.MULTILINE,
)
daemon_component = component_by_name.get("desktop-daemon", {})
if not compose_commit:
    errors.append("ores-compose source commit must be an exact SHA")
elif compose_commit.group(1) != daemon_component.get("rev"):
    errors.append("ores-compose source commit must equal desktop-daemon appliance rev")
if "BMSCL_DESKTOP_ADDR:" in compose:
    errors.append("ores-compose must use canonical BMSCL_DAEMON_LISTEN, not compatibility alias")
if "BMSCL_START_BEAM:" in compose:
    errors.append("ores-compose must not declare obsolete BMSCL_START_BEAM")
if 'BMSCL_DAEMON_LISTEN: "127.0.0.1:9587"' not in compose:
    errors.append("ores-compose must bind canonical daemon listen address")

gates = data.get("promotion_gates", {})
if gates.get("daemon_lockfile_committed") is not True:
    errors.append("desktop daemon lockfile gate must be true")
for pending_gate in (
    "compiler_lockfile_committed",
    "cli_lockfile_committed",
    "operator_service_authority_wired",
    "bounded_child_logs_wired",
):
    if pending_gate not in gates:
        errors.append(f"missing promotion gate: {pending_gate}")

bootstrap_sh = (root / "scripts" / "bootstrap.sh").read_text()
bootstrap_ps1 = (root / "scripts" / "bootstrap.ps1").read_text()
if 'cargo build --release --locked --manifest-path "$SRC/desktop-daemon/Cargo.toml"' not in bootstrap_sh:
    errors.append("Unix bootstrap must build desktop daemon with --locked")
if 'cargo build --release --locked --manifest-path (Join-Path $Src "desktop-daemon\\Cargo.toml")' not in bootstrap_ps1:
    errors.append("Windows bootstrap must build desktop daemon with --locked")
if '["cargo", "build", "--release", "--locked"]' not in compose:
    errors.append("ores-compose daemon build must use --locked")

if data.get("channel") == "promoted" and not all(gates.values()):
    errors.append("promoted channel requires all gates")

if errors:
    for error in errors:
        print("ERROR: " + error, file=sys.stderr)
    raise SystemExit(1)

print("BeamScale appliance manifest OK; channel=" + str(data.get("channel")))
