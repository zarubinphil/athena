#!/usr/bin/env python3
"""Validate registry.jsonl: required keys, parity↔harness consistency, dup ids,
score range, orphan overrides. Exit 1 on hard errors. Run after each rebuild."""
import json, sys, os

HOME = os.path.expanduser("~")
REG = f"{HOME}/.agents/registry"
DB = f"{REG}/registry.jsonl"
REQUIRED = ["id", "type", "purpose", "domains", "harness", "parity",
            "usage_count", "score", "rating", "status"]

recs, errors, warns = [], [], []
ids = set()
for n, line in enumerate(open(DB, encoding="utf-8"), 1):
    line = line.strip()
    if not line:
        continue
    try:
        r = json.loads(line)
    except Exception as e:
        errors.append(f"line {n}: bad json: {e}")
        continue
    recs.append(r)
    for k in REQUIRED:
        if k not in r:
            errors.append(f"{r.get('id','?')}: missing key '{k}'")
    if r["id"] in ids:
        errors.append(f"duplicate id: {r['id']}")
    ids.add(r["id"])
    if not (0 <= r.get("score", -1) <= 100):
        warns.append(f"{r['id']}: score out of range ({r.get('score')})")
    h = r.get("harness", {})
    both = h.get("claude") == "installed" and h.get("codex") == "installed"
    if both and r.get("parity") not in ("synced",):
        warns.append(f"{r['id']}: both installed but parity={r.get('parity')}")
    if not both and r.get("parity") == "synced":
        errors.append(f"{r['id']}: parity=synced but harness={h}")

# orphan overrides (id not in registry)
ovp = f"{REG}/overrides.jsonl"
if os.path.exists(ovp):
    for line in open(ovp, encoding="utf-8"):
        line = line.strip()
        if line:
            oid = json.loads(line).get("id")
            if oid not in ids:
                warns.append(f"override for unknown id: {oid}")

print(f"validated {len(recs)} records | {len(errors)} errors | {len(warns)} warnings")
for e in errors[:20]:
    print("  ERROR:", e)
for w in warns[:20]:
    print("  warn:", w)
if len(warns) > 20:
    print(f"  ... +{len(warns)-20} more warnings")
sys.exit(1 if errors else 0)
