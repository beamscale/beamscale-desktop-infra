#!/usr/bin/env python3
import json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
manifest = json.loads((ROOT / "appliance.json").read_text())
errors = []

if manifest.get("schema") != "ores.desktop-appliance/v1":
    errors.append("unexpected schema")
host = manifest.get("host", {})
listen = host.get("daemon_listen", "")
if not (listen.startswith("127.0.0.1:") or listen.startswith("[::1]:")):
    errors.append("daemon must bind to loopback")
if host.get("default_reverse_proxy") != "none":
    errors.append("default reverse proxy must remain none")
if manifest.get("cloudflare", {}).get("credentials_in_repo") is not False:
    errors.append("Cloudflare credentials must never be committed")
if manifest.get("update", {}).get("allow_mutable_latest") is not False:
    errors.append("mutable latest updates are forbidden")

seen = set()
for component in manifest.get("components", []):
    name = component.get("name")
    rev = component.get("rev", "")
    repo = component.get("repo", "")
    if not name or name in seen:
        errors.append(f"duplicate or empty component name: {name!r}")
    seen.add(name)
    if not re.fullmatch(r"[0-9a-f]{40}", rev):
        errors.append(f"{name}: rev must be a full 40-char lowercase commit SHA")
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repo):
        errors.append(f"{name}: invalid GitHub repo slug")

if errors:
    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)
    raise SystemExit(1)
print("appliance manifest OK")
