"""Fetches and parses Community Dragon's TFT set-data feed for champion
cost/traits lookups, mirroring Packages/TFTData/Sources/TFTData/Ingestion/SetDataParser.swift
(same source, same field names) so the scraper doesn't need tftactics.gg to
tell us anything Riot's own data already answers more reliably.
"""
from __future__ import annotations

import json
import urllib.request
from dataclasses import dataclass

CONTENT_VERSION_URL = "https://raw.communitydragon.org/latest/content-metadata.json"
SET_DATA_URL = "https://raw.communitydragon.org/latest/cdragon/tft/en_us.json"
USER_AGENT = "tft-overlay-comps-scraper/0.1 (maintainer-run, contact: kristof@weareantenna.be)"


@dataclass(frozen=True)
class ChampionInfo:
    name: str
    cost: int
    traits: list[str]


@dataclass(frozen=True)
class ChampionData:
    set_number: int
    content_version: str
    by_name: dict[str, ChampionInfo]


def _fetch_json(url: str) -> dict:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.loads(response.read())


def fetch_champion_data() -> ChampionData:
    """Live champion cost/traits for the current set, keyed by display name.

    A champion with an empty trait list is a PvE-only encounter unit (jungle
    camps, training dummy) and is dropped -- same discriminator SetDataParser
    uses, verified against the same live payload.
    """
    content_version = _fetch_json(CONTENT_VERSION_URL)["version"]
    document = _fetch_json(SET_DATA_URL)

    set_number, raw_set = max(
        ((int(key), value) for key, value in document.get("sets", {}).items() if key.isdigit()),
        key=lambda pair: pair[0],
    )

    by_name: dict[str, ChampionInfo] = {}
    for raw in raw_set.get("champions", []):
        traits = raw.get("traits") or []
        if not traits:
            continue
        name = raw.get("name")
        if not name:
            continue
        by_name[name] = ChampionInfo(name=name, cost=raw.get("cost", 0), traits=traits)

    return ChampionData(set_number=set_number, content_version=content_version, by_name=by_name)
