import json
import sys
from pathlib import Path

import pytest
from jsonschema import Draft202012Validator

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from champion_data import ChampionData, ChampionInfo  # noqa: E402
from mapper import map_comp, map_playstyle, slugify  # noqa: E402
from scrape import RawComp  # noqa: E402

SCHEMA_PATH = Path(__file__).resolve().parent.parent.parent / "docs" / "schema" / "comp.schema.json"


@pytest.fixture
def champion_data():
    return ChampionData(
        set_number=18,
        content_version="test-version",
        by_name={
            "Ashe": ChampionInfo(name="Ashe", cost=5, traits=["Blossom", "Hunter"]),
            "Sivir": ChampionInfo(name="Sivir", cost=4, traits=["Primal", "Hunter"]),
            "Cinderling": ChampionInfo(name="Cinderling", cost=1, traits=["Riftbeast", "Hunter"]),
            "Kha'Zix": ChampionInfo(name="Kha'Zix", cost=3, traits=["Rival"]),
        },
    )


@pytest.fixture
def validator():
    schema = json.loads(SCHEMA_PATH.read_text())
    return Draft202012Validator(schema)


def test_slugify_produces_schema_conformant_ids():
    # An apostrophe is dropped, not split on: ids are the key pins persist by,
    # so the shipped `hunters-ashe` / `rivals-khazix` must keep slugging to
    # themselves now that display names carry the apostrophe the set ships.
    assert slugify("Hunter's Ashe") == "hunters-ashe"
    assert slugify("Rivals Kha'Zix") == "rivals-khazix"
    assert slugify("Spellweaver  Defenders") == "spellweaver-defenders"


@pytest.mark.parametrize("text,expected", [
    ("Fast 8", "fast_8"),
    ("Fast 9", "fast_8"),
    ("Slow Roll (7)", "slow_roll"),
    ("Standard", "reroll"),
    (None, "reroll"),
])
def test_map_playstyle(text, expected):
    assert map_playstyle(text) == expected


def test_map_comp_produces_schema_valid_output(champion_data, validator):
    raw = RawComp(
        tier="S",
        name="Hunter's Ashe",
        playstyle_text="Fast 8",
        units=[
            {"name": "Cinderling", "items": []},
            {"name": "Sivir", "items": ["Guinsoo's Rageblade"]},
            {"name": "Ashe", "items": ["Infinity Edge", "Giant Slayer"]},
        ],
        hex_grid=[[None] * 7 for _ in range(4)],
        early_units=["Cinderling"],
        flex_options=[{"level": "9", "units": ["Sivir"]}],
        trait_counts=[{"name": "Hunter", "count": 3}],
    )
    warnings = []
    comp = map_comp(raw, champion_data, set_number=18, patch="18.1", warn=warnings.append)

    assert comp is not None
    errors = list(validator.iter_errors(comp))
    assert not errors, f"schema errors: {[e.message for e in errors]}"
    assert comp["id"] == "hunters-ashe"
    assert comp["source"] == "scraped-feed"
    assert {c["unit"] for c in comp["carries"]} == {"Sivir", "Ashe"}
    assert not warnings


def test_map_comp_drops_unresolvable_unit_with_warning(champion_data, validator):
    raw = RawComp(
        tier="A",
        name="Mystery Comp",
        playstyle_text="Slow Roll (7)",
        units=[
            {"name": "Ashe", "items": ["Infinity Edge"]},
            {"name": "Totally Not A Real Champion", "items": []},
        ],
    )
    warnings = []
    comp = map_comp(raw, champion_data, set_number=18, patch="18.1", warn=warnings.append)

    assert comp is not None
    assert len(comp["units"]) == 1
    assert comp["units"][0]["name"] == "Ashe"
    assert any("Totally Not A Real Champion" in w for w in warnings)
    assert not list(validator.iter_errors(comp))


def test_map_comp_returns_none_when_no_units_resolve(champion_data):
    raw = RawComp(tier="B", name="Empty Comp", playstyle_text=None, units=[{"name": "Nobody", "items": []}])
    warnings = []
    comp = map_comp(raw, champion_data, set_number=18, patch="18.1", warn=warnings.append)

    assert comp is None
    assert warnings


def test_map_comp_defaults_positioning_when_source_has_none(champion_data, validator):
    raw = RawComp(
        tier="B",
        name="No Position Data",
        playstyle_text="Slow Roll (6)",
        units=[{"name": "Ashe", "items": ["Infinity Edge"]}],
        hex_grid=None,
    )
    comp = map_comp(raw, champion_data, set_number=18, patch="18.1", warn=lambda _msg: None)

    assert comp is not None
    assert comp["boardPositioning"]["grid"] == [[None] * 7 for _ in range(4)]
    assert "notes" in comp["boardPositioning"]
    assert not list(validator.iter_errors(comp))


def test_swap_options_become_pivot_notes_not_fake_levels(champion_data, validator):
    """A swap entry has no level. Treating it as one previously wrote
    'at level None, consider X' into 27 shipped comps."""
    raw = RawComp(
        tier="A", name="Swap Comp", playstyle_text="Fast 8",
        units=[{"name": "Ashe", "items": ["Infinity Edge"]}],
        flex_options=[
            {"kind": "swap", "level": None, "out_units": ["Sivir"], "units": ["Cinderling"]},
            {"kind": "level", "level": "9", "out_units": [], "units": ["Ashe"]},
        ],
    )
    comp = map_comp(raw, champion_data, set_number=18, patch="18.1", warn=lambda _m: None)
    assert comp is not None
    blob = json.dumps(comp)
    assert "None" not in blob, "literal Python None leaked into shipped text"
    assert "level ?" not in blob
    assert "Sivir → Cinderling" in comp["pivotNotes"]
    # Only the real level gate reaches the level plan.
    assert any("At level 9" in (e.get("notes") or "") for e in comp["levelPlan"])
    assert not list(validator.iter_errors(comp))


def test_apostrophised_champion_names_reach_every_display_field(champion_data, validator):
    """The source's champion icons carry plain-ASCII alt text ("Khazix",
    "Kogmaw", "RekSai") while the set ships "Kha'Zix", "Kog'Maw", "Rek'Sai".
    Unit entries were always built from the resolved champion, but the title,
    the early-game priority list and the swap notes passed the alt text
    straight through -- which is how `rivals-khazix` shipped a title reading
    "Rivals Khazix" one line above its own unit list reading "Kha'Zix" (#98).
    """
    raw = RawComp(
        tier="A",
        name="Rivals Khazix",
        playstyle_text="Slow Roll (7)",
        units=[
            {"name": "Khazix", "items": ["Jeweled Gauntlet"]},
            {"name": "Cinderling", "items": []},
        ],
        early_units=["Khazix", "Cinderling"],
        flex_options=[
            {"kind": "level", "level": "9", "out_units": [], "units": ["Khazix"]},
            {"kind": "swap", "level": None, "out_units": ["Khazix"], "units": ["Sivir"]},
        ],
    )
    comp = map_comp(raw, champion_data, set_number=18, patch="18.1", warn=lambda _m: None)

    assert comp is not None
    assert comp["name"] == "Rivals Kha'Zix"
    # Pins persist by id, so the display fix must not rename the comp.
    assert comp["id"] == "rivals-khazix"
    assert comp["units"][0]["name"] == "Kha'Zix"
    assert comp["carries"][0]["unit"] == "Kha'Zix"
    assert "Kha'Zix" in comp["earlyOpener"]
    assert any("Kha'Zix" in (entry.get("notes") or "") for entry in comp["levelPlan"])
    assert "Kha'Zix → Sivir" in comp["pivotNotes"]
    # Nothing anywhere still spells it the source's way (the lowercase id is
    # unaffected by this case-sensitive check).
    assert "Khazix" not in json.dumps(comp)
    assert not list(validator.iter_errors(comp))


def test_option_with_unknown_level_and_no_swap_is_dropped_entirely(champion_data, validator):
    raw = RawComp(
        tier="B", name="Junk Option", playstyle_text=None,
        units=[{"name": "Ashe", "items": ["Infinity Edge"]}],
        flex_options=[{"kind": "unknown", "level": None, "out_units": [], "units": ["Sivir"]}],
    )
    comp = map_comp(raw, champion_data, set_number=18, patch="18.1", warn=lambda _m: None)
    assert comp is not None
    assert "None" not in json.dumps(comp)
    assert not list(validator.iter_errors(comp))
