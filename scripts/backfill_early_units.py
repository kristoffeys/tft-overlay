#!/usr/bin/env python3
"""Backfill `earlyUnits` into comps that only carry the `earlyOpener` prose.

The schema gained a structured early roster (`earlyUnits`) in #99, but the
36 comps already in `data/comps/` predate it. Re-running `scraper/` would
produce the field, but that needs network access and a headless browser and
its output changes with the source site, so it is not a reproducible way to
migrate a corpus that is already committed. The prose the scraper wrote is
itself machine-parseable -- it templates the early subset as
`"Prioritize A, B, C early; ..."` -- so this recovers the structure from the
text instead, deterministically and offline.

This is committed rather than run once and deleted because the corpus is
regenerated whenever the maintainer re-runs the scraper: a comp written by
an older scraper, or written before this field existed, can be topped up
again by re-running this. It is idempotent -- a comp whose `earlyUnits`
already matches what would be derived is left byte-identical.

Two things this deliberately refuses to do:

* **Guess.** A comp whose `earlyOpener` does not match a known shape, or
  that names a champion not in the set catalog, is reported and left with no
  `earlyUnits` at all. The schema makes the field optional exactly so that
  is a legal outcome: an absent field is honest, a wrong one silently loses
  a champion's portrait in the app (#81).
* **Reformat.** The insertion is textual, so `elderwood-bloom.json`'s
  hand-formatting survives instead of being flattened into the scraper's
  canonical serialization.

Usage:
    python3 scripts/backfill_early_units.py            # write both corpus copies
    python3 scripts/backfill_early_units.py --check    # report only, exit 1 if stale
    python3 scripts/backfill_early_units.py --stats    # also print cost distribution
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
# Both corpus copies are kept byte-identical (a test asserts it): the app
# bundle cannot read `data/` at runtime, so TFTUI ships its own copy.
CORPUS_DIRS = [
    ROOT / "data" / "comps",
    ROOT / "Packages" / "TFTUI" / "Sources" / "TFTUI" / "Resources" / "Comps",
]
SET_DATA_PATH = ROOT / "Packages" / "TFTData" / "Sources" / "TFTData" / "Resources" / "fallback-set-data.json"

# The shape `scraper/mapper.py` templates the source's "Early Comp" subset
# into. Anchored and specific on purpose: a looser pattern would happily
# scrape champion names out of prose that was never an early-roster claim.
_SCRAPED_OPENER_RE = re.compile(
    r"^Prioritize (?P<names>.+?) early; these carry the comp online before its full identity is committed\.$"
)

# The two hand-authored comps' openers are human prose, not a template, but
# they do name their early units explicitly. Transcribing that by hand is
# not the same as guessing -- so each entry records the exact prose it was
# read from, and is only applied while that prose still matches. If a human
# rewrites the opener, this stops applying and says so, rather than carrying
# a stale roster forward under the new text.
_HAND_AUTHORED_TRANSCRIPTIONS = {
    "elderwood-bloom": {
        # "...any cheap Elderwood or Fae unit you see (Ornn, Xayah, Alistar, LeBlanc)..."
        "opener": (
            "Fast to level 4 by 2-1. Greedily pick up any cheap Elderwood or Fae unit you see "
            "(Ornn, Xayah, Alistar, LeBlanc) without spending gold to 2-star them yet; play a generic strong "
            "early frontline in the meantime and take a neutral econ augment at 2-1 to preserve gold for the "
            "slow roll."
        ),
        "names": ["Ornn", "Xayah", "Alistar", "LeBlanc"],
    },
    "hunters-ashe": {
        # "...cheap Riftbeast/Hunter 1-costs like Cinderling as an econ-friendly early frontline..."
        "opener": (
            "Play fast: take every augment and unit that helps hit level 4 by 2-1 and level 6 by 3-2. Use cheap "
            "Riftbeast/Hunter 1-costs like Cinderling as an econ-friendly early frontline, but do not spend gold "
            "2-starring them."
        ),
        "names": ["Cinderling"],
    },
}


def _letters_only(name: str) -> str:
    """Community Dragon punctuates inconsistently ("Rek'Sai" vs "RekSai",
    "Hand Of Justice" vs "Hand of Justice"), so compare on letters and
    digits only -- then ship the catalog's spelling, never the input's."""
    return re.sub(r"[^a-z0-9]", "", name.lower())


def load_champion_index() -> dict[str, str]:
    """letters-only key -> the champion's canonical name in the set data."""
    champions = json.loads(SET_DATA_PATH.read_text())["champions"]
    index: dict[str, str] = {}
    for champion in champions:
        index.setdefault(_letters_only(champion["name"]), champion["name"])
    return index


def derive_early_units(comp: dict, champion_index: dict[str, str]) -> tuple[list[str], str | None]:
    """Returns (names, reason-it-failed). Exactly one of the two is truthy."""
    opener = comp.get("earlyOpener", "")
    comp_id = comp.get("id", "<no id>")

    transcription = _HAND_AUTHORED_TRANSCRIPTIONS.get(comp_id)
    if transcription is not None:
        if opener != transcription["opener"]:
            return [], "hand-authored opener has been rewritten since it was transcribed; not carrying the old roster forward"
        raw_names = list(transcription["names"])
    else:
        match = _SCRAPED_OPENER_RE.match(opener)
        if match is None:
            return [], "earlyOpener does not match a known early-roster shape"
        raw_names = [part.strip() for part in match.group("names").split(",")]

    resolved: list[str] = []
    for raw_name in raw_names:
        if not raw_name:
            return [], "early-roster text contained an empty name"
        canonical = champion_index.get(_letters_only(raw_name))
        if canonical is None:
            return [], f"{raw_name!r} does not resolve to a champion in the set catalog"
        if canonical not in resolved:
            resolved.append(canonical)
    return resolved, None


def render_insertion(comp_text: str, names: list[str]) -> str:
    """Insert `earlyUnits` immediately before the top-level `earlyOpener`
    line, matching the file's own style: the scraper's canonical
    `json.dumps(indent=2)` files get the expanded form it would write, and a
    hand-formatted file keeps its compact one-line arrays."""
    marker = '\n  "earlyOpener":'
    if comp_text.count(marker) != 1:
        raise ValueError('expected exactly one top-level "earlyOpener" line')

    canonical = json.dumps(json.loads(comp_text), indent=2, ensure_ascii=False) + "\n" == comp_text
    if canonical:
        block = json.dumps({"earlyUnits": names}, indent=2, ensure_ascii=False)
        # Strip the wrapping braces, keep the two-space-indented body.
        body = "\n".join(block.splitlines()[1:-1])
    else:
        body = "  " + json.dumps({"earlyUnits": names}, ensure_ascii=False)[1:-1]
    return comp_text.replace(marker, "\n" + body + "," + marker)


def strip_existing(comp_text: str) -> str:
    """Remove an existing `earlyUnits` block so a rewrite is a replacement,
    not a duplicate key. Textual, for the same reason the insertion is; the
    block always sits directly before `earlyOpener`, so that is the bound."""
    return re.sub(
        r'\n  "earlyUnits":.*?(?=\n  "earlyOpener":)',
        "",
        comp_text,
        flags=re.DOTALL,
    )


def cost_distribution(comps: list[dict], champion_index: dict[str, str]) -> None:
    costs = {c["name"]: c["cost"] for c in json.loads(SET_DATA_PATH.read_text())["champions"]}
    slots: Counter[int] = Counter()
    distinct: dict[int, set[str]] = {c: set() for c in range(1, 6)}
    sizes: Counter[int] = Counter()
    for comp in comps:
        roster = comp.get("earlyUnits") or []
        if roster:
            sizes[len(roster)] += 1
        for name in roster:
            cost = costs.get(name)
            if cost is None:
                continue
            slots[cost] += 1
            distinct[cost].add(name)
    total = sum(slots.values())
    print("\nearlyUnits cost distribution across the corpus:")
    print("  cost  slots   share  distinct units")
    for cost in range(1, 6):
        share = f"{100 * slots[cost] / total:5.1f}%" if total else "    -"
        print(f"  {cost}     {slots[cost]:5d}  {share}  {len(distinct[cost]):3d}")
    print(f"  total {total:5d}")
    print("  roster sizes: " + ", ".join(f"{size} units x{count}" for size, count in sorted(sizes.items())))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Do not write; exit 1 if any file would change.")
    parser.add_argument("--stats", action="store_true", help="Print the corpus cost distribution when done.")
    args = parser.parse_args()

    champion_index = load_champion_index()
    primary, *mirrors = CORPUS_DIRS
    comp_files = sorted(primary.glob("*.json"))
    if not comp_files:
        print(f"error: no comp files found in {primary}", file=sys.stderr)
        return 1

    changed: list[str] = []
    skipped: list[tuple[str, str]] = []
    resulting_comps: list[dict] = []

    for comp_file in comp_files:
        original = comp_file.read_text()
        comp = json.loads(original)
        names, reason = derive_early_units(comp, champion_index)

        if reason is not None:
            skipped.append((comp_file.name, reason))
            updated = strip_existing(original) if "earlyUnits" in comp else original
        else:
            updated = render_insertion(strip_existing(original), names)

        # Parse back, so a bad textual edit fails here rather than shipping.
        # A surgical edit must change exactly one key and nothing else.
        reparsed = json.loads(updated)
        resulting_comps.append(reparsed)
        rest = {k: v for k, v in reparsed.items() if k != "earlyUnits"}
        baseline = {k: v for k, v in comp.items() if k != "earlyUnits"}
        if reparsed.get("earlyUnits", []) != names or rest != baseline:
            print(f"error: {comp_file.name}: edit did not round-trip cleanly; refusing to write", file=sys.stderr)
            return 1

        targets = [comp_file] + [mirror / comp_file.name for mirror in mirrors]
        for target in targets:
            if target.read_text() == updated:
                continue
            changed.append(str(target.relative_to(ROOT)))
            if not args.check:
                target.write_text(updated)

    with_field = sum(1 for c in resulting_comps if c.get("earlyUnits"))
    verb = "would change" if args.check else "updated"
    print(f"{with_field}/{len(comp_files)} comp(s) now carry earlyUnits; {len(changed)} file(s) {verb}")
    for name, reason in skipped:
        print(f"  SKIP {name}: {reason}")

    if args.stats:
        cost_distribution(resulting_comps, champion_index)

    if args.check and changed:
        for path in changed:
            print(f"  STALE {path}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
