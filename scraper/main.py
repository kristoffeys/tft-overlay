#!/usr/bin/env python3
"""Maintainer-run tool: scrapes tftactics.gg's team-comps tier list,
cross-references champion cost/traits against Community Dragon's live set
data, and writes one JSON file per comp into ../data/comps/, validated
against ../docs/schema/comp.schema.json.

Never invoked by the shipped app -- this is intentionally a separate,
un-packaged tool. See README.md and ../docs/adr/0004-comps-scraping.md.

Usage:
    ./.venv/bin/python main.py --patch 18.1
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from jsonschema import Draft202012Validator

from champion_data import fetch_champion_data
from mapper import map_comp
from scrape import scrape_comps

REPO_ROOT = Path(__file__).resolve().parent.parent
COMPS_DIR = REPO_ROOT / "data" / "comps"
SCHEMA_PATH = REPO_ROOT / "docs" / "schema" / "comp.schema.json"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--patch", required=True,
        help='Riot patch string, e.g. "18.1" -- not derivable from either data source, so it must be given by hand.'
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Scrape, map and validate, but don't write any files."
    )
    args = parser.parse_args()

    warnings: list[str] = []

    def warn(message: str) -> None:
        warnings.append(message)
        print(f"WARN: {message}", file=sys.stderr)

    print("Fetching live champion data from Community Dragon...")
    champion_data = fetch_champion_data()
    print(f"  set {champion_data.set_number}, content version {champion_data.content_version}, "
          f"{len(champion_data.by_name)} champions")

    print("Rendering tftactics.gg team-comps tier list (this takes a minute)...")
    raw_comps = scrape_comps()
    print(f"  found {len(raw_comps)} comps")

    schema = json.loads(SCHEMA_PATH.read_text())
    validator = Draft202012Validator(schema)

    written = 0
    skipped = 0
    for raw in raw_comps:
        comp = map_comp(raw, champion_data, set_number=champion_data.set_number, patch=args.patch, warn=warn)
        if comp is None:
            skipped += 1
            continue

        errors = sorted(validator.iter_errors(comp), key=lambda e: e.path)
        if errors:
            for error in errors:
                warn(f"{raw.name}: schema validation failed at {list(error.path)}: {error.message}")
            skipped += 1
            continue

        destination = COMPS_DIR / f"{comp['id']}.json"
        if destination.exists():
            existing = json.loads(destination.read_text())
            if existing.get("source", "hand-authored") == "hand-authored":
                warn(f"{raw.name}: {destination.name} already exists as hand-authored; not overwriting")
                skipped += 1
                continue

        if not args.dry_run:
            destination.write_text(json.dumps(comp, indent=2, ensure_ascii=False) + "\n")
        written += 1

    print(f"\n{written} comp(s) {'would be ' if args.dry_run else ''}written, {skipped} skipped, "
          f"{len(warnings)} warning(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
