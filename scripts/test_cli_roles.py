#!/usr/bin/env python3
import json
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parents[1]
manifest = json.loads((root / "appliance.json").read_text())
errors = []

profiles = manifest.get("cli_profiles", {})
canonical = profiles.get("end_user", {})
alternate = profiles.get("alternate_end_user", {})

if canonical != {
    "command": "bmscl",
    "implementation": "rust",
    "source": "components/cli",
    "audience": "external",
    "canonical": True,
}:
    errors.append("canonical end-user CLI profile drifted")

if alternate != {
    "command": "bmscl-gleam",
    "implementation": "gleam",
    "source": "clients/cli-gleam",
    "audience": "external",
    "canonical": False,
    "install": "optional",
}:
    errors.append("alternate Gleam CLI profile drifted")

component_by_name = {item.get("name"): item for item in manifest.get("components", [])}
client_by_name = {item.get("name"): item for item in manifest.get("clients", [])}
if component_by_name.get("cli", {}).get("repo") != "beamscale/bmscl-cli":
    errors.append("canonical CLI component must source beamscale/bmscl-cli")
if client_by_name.get("cli-gleam", {}).get("repo") != "beamscale/bmscl-cli-gleam":
    errors.append("alternate CLI client must source beamscale/bmscl-cli-gleam")
if client_by_name.get("cli-gleam", {}).get("role") != "alternate-end-user-cli":
    errors.append("Gleam CLI must be an alternate end-user client")

shell_scripts = [
    root / "scripts" / "up.sh",
    root / "scripts" / "down.sh",
    root / "scripts" / "status.sh",
]
for path in shell_scripts:
    text = path.read_text()
    if "BMSCL_CLI" not in text:
        errors.append(f"{path.name}: must route lifecycle through canonical BMSCL_CLI")
    if "BMSCL_INTERNAL_CLI" in text or "bmscl-internal" in text:
        errors.append(f"{path.name}: stale internal CLI boundary leaked")
    for stale in ("local runtime", "local tunnel"):
        if stale in text:
            errors.append(f"{path.name}: stale raw local command {stale!r}")

powershell_scripts = [
    root / "scripts" / "up.ps1",
    root / "scripts" / "down.ps1",
    root / "scripts" / "status.ps1",
]
for path in powershell_scripts:
    text = path.read_text()
    if "BMSCL_CLI" not in text:
        errors.append(f"{path.name}: must route lifecycle through canonical BMSCL_CLI")
    if "BMSCL_INTERNAL_CLI" in text or "bmscl-internal" in text:
        errors.append(f"{path.name}: stale internal CLI boundary leaked")
    if re.search(r"\blocal\s+(runtime|tunnel)\b", text, re.IGNORECASE):
        errors.append(f"{path.name}: stale raw local command leaked")

bootstrap = (root / "scripts" / "bootstrap.sh").read_text()
if "BMSCL_INSTALL_GLEAM_CLIENT" not in bootstrap:
    errors.append("Unix bootstrap must make the Gleam client explicitly optional")
if "BMSCL_CLI" not in bootstrap:
    errors.append("Unix bootstrap must export canonical BMSCL_CLI")

for path in [root / "scripts" / "install-service.sh", root / "scripts" / "uninstall-service.sh"]:
    text = path.read_text()
    if "BMSCL_SERVICE_BINARY" not in text:
        errors.append(f"{path.name}: must delegate to Rust beamscale-service")
    for forbidden in ("systemctl ", "launchctl ", "schtasks", "sed "):
        if forbidden in text:
            errors.append(f"{path.name}: must not own service-manager implementation: {forbidden!r}")

for path in [root / "scripts" / "install-service.ps1", root / "scripts" / "uninstall-service.ps1"]:
    text = path.read_text()
    if "BMSCL_SERVICE_BINARY" not in text:
        errors.append(f"{path.name}: must delegate to Rust beamscale-service")
    if re.search(r"\b(schtasks|Register-ScheduledTask|New-ScheduledTask)\b", text, re.IGNORECASE):
        errors.append(f"{path.name}: must not own Windows service-manager implementation")

bootstrap_ps1 = (root / "scripts" / "bootstrap.ps1").read_text()
if "BMSCL_INSTALL_GLEAM_CLIENT" not in bootstrap_ps1:
    errors.append("Windows bootstrap must make the Gleam client explicitly optional")
if "BMSCL_CLI" not in bootstrap_ps1:
    errors.append("Windows bootstrap must export canonical BMSCL_CLI")
if "$EnvLines" not in bootstrap_ps1:
    errors.append("Windows bootstrap must generate env.ps1 from literal assignment lines")

if errors:
    for error in errors:
        print("ERROR:", error, file=sys.stderr)
    raise SystemExit(1)

print("BeamScale canonical/alternate CLI boundary OK")
