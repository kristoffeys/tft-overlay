#!/usr/bin/env python3
"""Validate every JSON file in data/comps/ against docs/schema/comp.schema.json.

Usage: python3 scripts/validate_comps.py
Exit code 0 if all comps validate, 1 otherwise. Intended for CI.
"""
import json
import sys
from pathlib import Path

try:
    import jsonschema
except ImportError:
    print("error: the 'jsonschema' package is required (pip install jsonschema)", file=sys.stderr)
    sys.exit(1)

ROOT = Path(__file__).resolve().parent.parent
SCHEMA_PATH = ROOT / "docs" / "schema" / "comp.schema.json"
COMPS_DIR = ROOT / "data" / "comps"


def main() -> int:
    if not SCHEMA_PATH.exists():
        print(f"error: schema not found at {SCHEMA_PATH}", file=sys.stderr)
        return 1

    schema = json.loads(SCHEMA_PATH.read_text())
    validator_cls = jsonschema.validators.validator_for(schema)
    validator_cls.check_schema(schema)
    validator = validator_cls(schema)

    comp_files = sorted(COMPS_DIR.glob("*.json"))
    if not comp_files:
        print(f"error: no comp files found in {COMPS_DIR}", file=sys.stderr)
        return 1

    failed = 0
    for comp_file in comp_files:
        try:
            data = json.loads(comp_file.read_text())
        except json.JSONDecodeError as e:
            print(f"FAIL {comp_file.relative_to(ROOT)}: invalid JSON: {e}")
            failed += 1
            continue

        errors = sorted(validator.iter_errors(data), key=lambda e: e.path)
        if errors:
            print(f"FAIL {comp_file.relative_to(ROOT)}:")
            for err in errors:
                loc = "/".join(str(p) for p in err.path) or "<root>"
                print(f"  - {loc}: {err.message}")
            failed += 1
            continue

        carry_names = {c["unit"] for c in data.get("carries", [])}
        unit_names = {u["name"] for u in data.get("units", [])}
        carry_role_names = {u["name"] for u in data.get("units", []) if u.get("role") == "carry"}
        missing = carry_names - unit_names
        if missing:
            print(f"FAIL {comp_file.relative_to(ROOT)}: carries reference unlisted units: {sorted(missing)}")
            failed += 1
            continue
        not_marked_carry = carry_names - carry_role_names
        if not_marked_carry:
            print(f"FAIL {comp_file.relative_to(ROOT)}: carries not marked role=\"carry\" in units[]: {sorted(not_marked_carry)}")
            failed += 1
            continue

        grid_names = {
            cell
            for row in data["boardPositioning"]["grid"]
            for cell in row
            if cell is not None
        }
        unknown_grid_units = grid_names - unit_names
        if unknown_grid_units:
            print(f"FAIL {comp_file.relative_to(ROOT)}: boardPositioning.grid references unlisted units: {sorted(unknown_grid_units)}")
            failed += 1
            continue

        print(f"OK   {comp_file.relative_to(ROOT)}")

    total = len(comp_files)
    print(f"\n{total - failed}/{total} comp(s) valid")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
