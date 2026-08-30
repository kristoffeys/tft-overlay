"""Renders tftactics.gg's team-comps tier list with Playwright (it's a
client-rendered React app; there is no discoverable JSON API behind it --
verified by inspecting its bundle and network behavior) and extracts one
raw record per comp.

Maintainer-run only. Never invoked by the shipped app. See README.md in
this directory for why, and docs/adr/0004-comps-scraping.md for the
decision this implements.
"""
from __future__ import annotations

import time
from dataclasses import dataclass, field

from playwright.sync_api import sync_playwright

TIER_LIST_URL = "https://tftactics.gg/tierlist/team-comps/"
USER_AGENT = "tft-overlay-comps-scraper/0.1 (maintainer-run, contact: kristof@weareantenna.be)"

# One JS pass over the fully-expanded DOM, run in-page via page.evaluate.
# The tier list renders several <div class="characters-list"> containers
# (one per tier group), so we query .team-portrait globally rather than
# scoping to any one of them. Each .team-portrait is the whole per-comp
# unit: team-name (rank/name/playstyle), team-characters (roster + shown
# items), and -- after the name is clicked -- team-expanded (positioning,
# early-comp subset, trait/origin counts, flex options). Verified by hand
# against the live rendered page on 2026-08-29.
_EXTRACT_JS = """
() => {
  return Array.from(document.querySelectorAll('.team-portrait')).map(portrait => {
    const rankEl = portrait.querySelector('.team-rank');
    const nameEl = portrait.querySelector('.team-name-elipsis');
    const playstyleEl = portrait.querySelector('.team-playstyle');
    let name = '';
    if (nameEl) {
      for (const node of nameEl.childNodes) {
        if (node.nodeType === Node.TEXT_NODE) name += node.textContent;
      }
    }

    const charactersEl = portrait.querySelector(':scope > .team-characters');
    const units = charactersEl
      ? Array.from(charactersEl.querySelectorAll(':scope > a.characters-item')).map(a => {
          const unitNameEl = a.querySelector('.team-character-name');
          const itemEls = Array.from(a.querySelectorAll('.character-items .character-wrapper[name]'));
          return {
            name: unitNameEl ? unitNameEl.textContent.trim() : (a.querySelector('img') ? a.querySelector('img').alt : null),
            items: itemEls.map(el => el.getAttribute('name')),
          };
        })
      : [];

    let hex_grid = null;
    let early_units = [];
    let flex_options = [];
    let trait_counts = [];
    const expanded = portrait.querySelector(':scope > .team-expanded');
    if (expanded) {
      const midGroup = expanded.querySelector('.team-expanded-group.mid');
      if (midGroup) {
        early_units = Array.from(midGroup.querySelectorAll('img')).map(img => img.alt).filter(Boolean);
      }
      trait_counts = Array.from(expanded.querySelectorAll('.builder-bonus-item')).map(el => {
        const icon = el.querySelector('.builder-bonus-icon');
        const count = el.querySelector('.builder-bonus-counter span');
        return {
          name: icon ? icon.getAttribute('search') : null,
          count: count ? parseInt(count.textContent, 10) : null,
        };
      });
      // An "option" is one of two different things, and conflating them is
      // what previously produced "at level None": either a LEVEL GATE
      // (`.option-out` holds a `Lv.N` chip, meaning "at level N you can add
      // the units in `.option-in`") or a SWAP (`.option-out` holds champion
      // icons, meaning "play the `.option-in` units instead of these").
      flex_options = Array.from(expanded.querySelectorAll('.team-option')).map(el => {
        const out = el.querySelector('.option-out');
        const lvlEl = out ? out.querySelector('[class^="lv"]') : null;
        const digits = lvlEl ? lvlEl.textContent.replace(/[^0-9]/g, '') : '';
        const outUnits = out
          ? Array.from(out.querySelectorAll('img')).map(img => img.alt).filter(Boolean)
          : [];
        const inUnits = Array.from(el.querySelectorAll('.option-in img'))
          .map(img => img.alt).filter(Boolean);
        return {
          kind: digits ? 'level' : (outUnits.length ? 'swap' : 'unknown'),
          level: digits || null,
          out_units: outUnits,
          units: inUnits,
        };
      });
      const hexEls = Array.from(expanded.querySelectorAll('#hexGrid li.hex'));
      if (hexEls.length === 28) {
        hex_grid = [];
        for (let r = 0; r < 4; r++) {
          const row = [];
          for (let c = 0; c < 7; c++) {
            const img = hexEls[r * 7 + c].querySelector('img');
            row.push(img ? img.alt : null);
          }
          hex_grid.push(row);
        }
      }
    }

    return {
      tier: rankEl ? rankEl.textContent.trim() : null,
      name: name.trim(),
      playstyle_text: playstyleEl ? playstyleEl.textContent.trim() : null,
      units,
      hex_grid,
      early_units,
      flex_options,
      trait_counts,
    };
  });
}
"""


@dataclass
class RawComp:
    tier: str | None
    name: str
    playstyle_text: str | None
    units: list[dict] = field(default_factory=list)
    hex_grid: list[list[str | None]] | None = None
    early_units: list[str] = field(default_factory=list)
    flex_options: list[dict] = field(default_factory=list)
    trait_counts: list[dict] = field(default_factory=list)


def scrape_comps(*, click_delay_seconds: float = 0.2) -> list[RawComp]:
    """Opens every comp's expanded detail panel, then extracts all of them
    in one JS pass. `click_delay_seconds` paces the expand-clicks -- a
    courtesy against hammering the page, not a measured requirement."""
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch()
        page = browser.new_page(user_agent=USER_AGENT)
        page.goto(TIER_LIST_URL, wait_until="networkidle", timeout=30000)
        page.wait_for_timeout(1500)

        consent_button = page.query_selector("button:has-text('Consent')")
        if consent_button:
            consent_button.click()
            page.wait_for_timeout(1000)

        names = page.query_selector_all(".team-name-elipsis")
        count = len(names)
        for index in range(count):
            # Re-query each time: expanding a panel shifts element handles.
            current = page.query_selector_all(".team-name-elipsis")[index]
            current.click(timeout=5000)
            time.sleep(click_delay_seconds)

        raw_records = page.evaluate(_EXTRACT_JS)
        browser.close()

    return [
        RawComp(
            tier=r.get("tier"),
            name=r.get("name", ""),
            playstyle_text=r.get("playstyle_text"),
            units=r.get("units", []),
            hex_grid=r.get("hex_grid"),
            early_units=r.get("early_units", []),
            flex_options=r.get("flex_options", []),
            trait_counts=r.get("trait_counts", []),
        )
        for r in raw_records
    ]
