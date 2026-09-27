#!/usr/bin/env python3
import json
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parents[1]
manifest = json.loads((root / "appliance.json").read_text())
errors = []

profiles = manifest.get("cli_profiles", {})
external = profiles.get("end_user", {})
internal = profiles.get("internal_operator", {})

if external != {
    "command": "bmscl",
    "implementation": "rust",
    "source": "components/cli",
    "audience": "external",
}:
    errors.append("external CLI profile drifted")

if internal != {
    "command": "bmscl-internal",
    "implementation": "gleam",
    "source": "clients/cli-gleam",
    "audience": "internal",
}:
    errors.append("internal CLI profile drifted")

shell_scripts = [
    root / "scripts" / "up.sh",
    root / "scripts" / "down.sh",
    root / "scripts" / "status.sh",
]
for path in shell_scripts:
    text = path.read_text()
    if "BMSCL_INTERNAL_CLI" not in text:
        errors.append(f"{path.name}: must route operator actions through BMSCL_INTERNAL_CLI")
    if re.search(r'\$STATE/bin/bmscl[" ]+local', text):
        errors.append(f"{path.name}: public bmscl must not drive operator lifecycle")

powershell_scripts = [
    root / "scripts" / "up.ps1",
    root / "scripts" / "down.ps1",
    root / "scripts" / "status.ps1",
]
for path in powershell_scripts:
    text = path.read_text()
    if "BMSCL_INTERNAL_CLI" not in text:
        errors.append(f"{path.name}: must route operator actions through BMSCL_INTERNAL_CLI")
    if re.search(r'bin\\bmscl\.exe.*\blocal\b', text, re.IGNORECASE):
        errors.append(f"{path.name}: public bmscl must not drive operator lifecycle")

bootstrap = (root / "scripts" / "bootstrap.sh").read_text()
if "bmscl-internal.escript" not in bootstrap or "gleam export escript" not in bootstrap:
    errors.append("Unix bootstrap must install the Gleam internal CLI")

bootstrap_ps1 = (root / "scripts" / "bootstrap.ps1").read_text()
if "bmscl-internal.escript" not in bootstrap_ps1 or "gleam export escript" not in bootstrap_ps1:
    errors.append("Windows bootstrap must install the Gleam internal CLI")

if errors:
    for error in errors:
        print("ERROR:", error, file=sys.stderr)
    raise SystemExit(1)

print("BeamScale CLI role boundary OK")
