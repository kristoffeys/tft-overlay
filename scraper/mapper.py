"""Pure mapping from a scraped `RawComp` (+ live champion data) to a dict
matching docs/schema/comp.schema.json. No network, no browser -- fully
unit-testable against fixture data. See tests/test_mapper.py.

tftactics.gg's tier list does not expose several fields the schema wants
(exact star targets, per-comp augment picks, prose difficulty rating, a
clean "18.1"-style patch string). Those are filled with clearly-labeled,
documented defaults/heuristics below rather than left invalid or invented
as if they were real editorial judgment -- see each function's docstring.
"""
from __future__ import annotations

import re

from champion_data import ChampionData

# The standard natural-XP leveling curve (no reroll/refresh spend), stable
# across sets bar minor season tuning -- a game constant, not comp-specific
# data. Used only to give scraped flex-option levels a round-stage label
# the schema's `stage` pattern (`^[0-9]+-[0-9]+$`) requires.
_LEVEL_TO_STAGE = {
    4: "2-1",
    5: "2-5",
    6: "3-2",
    7: "4-1",
    8: "4-5",
    9: "5-2",
    10: "6-1",
}
_DEFAULT_EARLY_STAGE = "3-2"
_DEFAULT_LATE_STAGE = "5-2"


def _parse_level(raw_level):
    """The source's level chip as an int, or None when it did not name one.

    Never guesses: an unknown level means the entry is not a level gate, and
    the caller drops it rather than inventing a stage for it."""
    try:
        level = int(raw_level) if raw_level else None
    except (TypeError, ValueError):
        return None
    return level if level is not None and 1 <= level <= 10 else None


class MappingWarning(Exception):
    """Raised (and caught by the caller) for a per-comp problem that should
    skip just that comp/unit, not abort the whole run."""


def slugify(name: str) -> str:
    """Comp id. Apostrophes are dropped, not turned into a separator, because
    the id is a stable key: pins persist by it, so "Hunter's Ashe" has to keep
    slugging to `hunters-ashe` (and "Rivals Kha'Zix" to `rivals-khazix`) even
    though the display name it comes from now carries the apostrophe the set
    ships. Splitting on it would rename shipped comps and drop those pins."""
    slug = re.sub(r"[^a-z0-9]+", "-", name.lower().replace("'", "").replace("’", "")).strip("-")
    return slug


def map_playstyle(text: str | None) -> str:
    """tftactics' playstyle text is free-form ("Slow Roll (7)", "Fast 8",
    "Fast 9", or nothing for its "Standard"/"Emblem"/"Augment" tabs). Our
    schema only has three buckets; anything that isn't clearly fast/slow
    falls into "reroll" as the catch-all, which is an approximation, not a
    verified fact about the comp."""
    if not text:
        return "reroll"
    lowered = text.lower()
    if "fast" in lowered:
        return "fast_8"
    if "slow roll" in lowered:
        return "slow_roll"
    return "reroll"


def _resolve_champion(name: str, champion_data: ChampionData):
    if name in champion_data.by_name:
        return champion_data.by_name[name]
    normalized = re.sub(r"[^a-z0-9]", "", name.lower())
    for candidate_name, info in champion_data.by_name.items():
        if re.sub(r"[^a-z0-9]", "", candidate_name.lower()) == normalized:
            return info
    return None


def _display_name(name: str, champion_data: ChampionData) -> str:
    """`name` respelled the way the live set data spells it, when it names a
    champion at all; unchanged otherwise.

    tftactics' champion icons carry plain-ASCII alt text ("Khazix", "Kogmaw",
    "RekSai", "Leblanc") while the set ships "Kha'Zix", "Kog'Maw", "Rek'Sai",
    "LeBlanc". Unit entries already came out right because they are built from
    the resolved `ChampionInfo`; every *other* place a scraped champion name is
    written -- the comp title, the early-game priority list, the swap notes --
    used to pass the alt text straight through, which is how `rivals-khazix`
    shipped a title reading "Rivals Khazix" directly above its own unit list
    reading "Kha'Zix" (#98)."""
    info = _resolve_champion(name, champion_data)
    return info.name if info else name


def _display_names(names, champion_data: ChampionData) -> list:
    return [_display_name(name, champion_data) for name in names]


_TITLE_WORD_RE = re.compile(r"[A-Za-z][A-Za-z0-9'’]*")


def resolve_champion_names_in_text(text: str, champion_data: ChampionData) -> str:
    """`text` with each word that names a champion respelled as the set spells
    it. Used for the comp title, which is a phrase ("Rivals Khazix"), not a
    bare name.

    Word at a time, so it only ever fixes single-word champion names. A
    multi-word name ("Mama Beak") or a parenthesised variant ("Lux (Inferno)")
    is left alone rather than guessed at from one word -- and the alt-text
    mangling this exists for only hits single-word names anyway. Words that
    resolve to no champion (traits, "Rivals", the possessive "Hunter's") come
    back untouched."""
    if not text:
        return text
    return _TITLE_WORD_RE.sub(lambda m: _display_name(m.group(0), champion_data), text)


def _star_target(cost: int, is_carry: bool) -> int:
    """Star level this comp is played to reach, which the source does not
    state -- this is a heuristic, and the schema field is documented as
    "usually final board".

    Carries: cheap units are reroll targets (3-star), expensive ones are
    played at 2-star. Everything else is assumed 2-star, because that is
    what a guide targets on a final board, *except* five-costs: two-starring
    a five-cost is a win-more accident, not a plan. Four-costs were
    previously lumped in with five-costs and marked 1-star, which made a
    third of every roster carry a "1 star" badge whose whole purpose is
    flagging the unusual case.
    """
    if is_carry:
        return 3 if cost <= 2 else 2
    return 1 if cost >= 5 else 2


def _role(cost: int, is_carry: bool) -> str:
    if is_carry:
        return "carry"
    return "utility" if cost >= 4 else "frontline"


def map_comp(raw, champion_data: ChampionData, *, set_number: int, patch: str, warn) -> dict | None:
    """Returns None (after calling `warn`) if the comp has no resolvable
    units at all -- nothing to ship. Individual unresolvable units are
    dropped with a warning rather than failing the whole comp, since a
    schema-valid comp missing one obscure unit beats no comp at all."""
    display_name = resolve_champion_names_in_text(raw.name, champion_data)
    early_units = _display_names(raw.early_units, champion_data)
    units = []
    carry_units_raw = []
    for raw_unit in raw.units:
        name = raw_unit.get("name")
        if not name:
            continue
        info = _resolve_champion(name, champion_data)
        if info is None:
            warn(f"{raw.name}: could not resolve champion {name!r} against live set data; dropping unit")
            continue
        is_carry = bool(raw_unit.get("items"))
        units.append({
            "name": info.name,
            "cost": info.cost,
            "starTarget": _star_target(info.cost, is_carry),
            "role": _role(info.cost, is_carry),
            "traits": info.traits,
        })
        if is_carry:
            carry_units_raw.append((info.name, raw_unit["items"]))

    if not units:
        warn(f"{raw.name}: no resolvable units; skipping comp entirely")
        return None

    carries = [
        {"unit": unit_name, "itemPriority": items}
        for unit_name, items in carry_units_raw
        if items
    ]
    if not carries:
        # Schema requires carries to be non-empty; fall back to the
        # highest-cost unit so the file still validates, flagged clearly.
        warn(f"{raw.name}: no itemized carry found in source; defaulting to highest-cost unit with no items")
        top = max(units, key=lambda u: u["cost"])
        carries = [{"unit": top["name"], "itemPriority": ["(unknown -- source had no item data)"]}]

    unit_names = {u["name"] for u in units}

    def _resolve_grid_cell(cell_name: str | None):
        # The positioning grid's champion icons use plain-ASCII alt text
        # (e.g. "RekSai", "Kogmaw") while the roster list's icons use the
        # proper display name (e.g. "Rek'Sai", "Kog'Maw") -- same
        # normalization used for unit resolution fixes the mismatch.
        if cell_name is None:
            return None
        info = _resolve_champion(cell_name, champion_data)
        resolved_name = info.name if info else cell_name
        if resolved_name not in unit_names:
            warn(f"{raw.name}: positioning grid references {cell_name!r}, not in this comp's unit list; clearing cell")
            return None
        return resolved_name

    if raw.hex_grid:
        grid = [[_resolve_grid_cell(cell) for cell in row] for row in raw.hex_grid]
        positioning_notes = None
    else:
        grid = [[None] * 7 for _ in range(4)]
        positioning_notes = "Positioning not available from source for this comp."

    level_plan = []
    if early_units:
        level_plan.append({
            "stage": _DEFAULT_EARLY_STAGE,
            "level": 6,
            "notes": "Prioritize: " + ", ".join(early_units),
        })
    # Only *level-gated* options belong in the level plan, and only when the
    # source actually names a level. A swap ("play Vi instead of Gnar") has
    # no level attached, and inventing one for it is what previously wrote
    # "Flex options at level ?" into 27 comps and defaulted them all to a
    # made-up level 9. Swaps are pivot information instead — see below.
    for option in raw.flex_options:
        if not option.get("units"):
            continue
        level = _parse_level(option.get("level"))
        if level is None:
            continue
        level_plan.append({
            "stage": _LEVEL_TO_STAGE.get(level, _DEFAULT_LATE_STAGE),
            "level": level,
            "notes": (
                f"At level {level} you can add: "
                f"{', '.join(_display_names(option['units'], champion_data))}."
            ),
        })
    if not level_plan:
        level_plan.append({
            "stage": _DEFAULT_EARLY_STAGE,
            "level": 6,
            "notes": "Level plan not available from source; play the comp's core units into your first real board.",
        })

    # The source's "Early Comp" subset, resolved to canonical set-data names
    # and carried as structure rather than only flattened into prose below.
    # The alt text these come from is plain ASCII ("RekSai", "Kogmaw"), so
    # the same normalization unit resolution uses is what keeps the shipped
    # name the one champion art resolves by -- see #81. A name that does not
    # resolve is dropped with a warning, not passed through: a wrong name
    # silently loses a portrait, a missing one is merely a shorter roster.
    early_units = []
    for early_name in raw.early_units:
        info = _resolve_champion(early_name, champion_data)
        if info is None:
            warn(f"{raw.name}: could not resolve early-comp champion {early_name!r} against live set data; dropping from earlyUnits")
            continue
        if info.name not in early_units:
            early_units.append(info.name)

    top_traits = [t["name"] for t in raw.trait_counts if t.get("name")][:2]
    early_opener = (
        ("Prioritize " + ", ".join(early_units) + " early; these carry the comp online before its "
         "full identity is committed.")
        if early_units
        else ("Play for economy and take units/augments supporting " + " and ".join(top_traits) + " until your "
              "board commits." if top_traits else "Early-game plan not available from source.")
    )
    # Swaps are the pivot information: "play these units instead of those".
    # Anything without both sides is dropped rather than described with a
    # placeholder — a comp that says nothing beats a comp that says "None".
    swaps = [
        f"{', '.join(_display_names(opt['out_units'], champion_data))} → "
        f"{', '.join(_display_names(opt['units'], champion_data))}"
        for opt in raw.flex_options
        if opt.get("kind") == "swap" and opt.get("out_units") and opt.get("units")
    ]
    if swaps:
        pivot_notes = "Swaps this comp commonly runs: " + "; ".join(swaps) + "."
    else:
        pivot_notes = (
            "No specific pivot data available from source; if contested, look for an adjacent trait pairing that "
            "shares your itemized carries' items."
        )

    description = f"{raw.tier or '?'}-tier {map_playstyle(raw.playstyle_text).replace('_', ' ')} comp"
    if top_traits:
        description += " built around " + " and ".join(top_traits) + "."
    else:
        description += "."

    return {
        "schemaVersion": "1.0.0",
        "id": slugify(display_name),
        "name": display_name,
        "set": set_number,
        "patch": patch,
        "source": "scraped-feed",
        "tier": raw.tier or "B",
        "playstyle": map_playstyle(raw.playstyle_text),
        "difficulty": "medium",
        "description": description[:500],
        "units": units,
        "carries": carries,
        "boardPositioning": {"grid": grid, **({"notes": positioning_notes} if positioning_notes else {})},
        "augmentPreferences": {"tier1": [], "tier2": [], "tier3": []},
        "levelPlan": level_plan,
        # Omitted entirely when the source had no usable early subset: the
        # schema makes it optional precisely so a thin scrape stays honest.
        **({"earlyUnits": early_units} if early_units else {}),
        "earlyOpener": early_opener[:500],
        "pivotNotes": pivot_notes[:500],
    }
