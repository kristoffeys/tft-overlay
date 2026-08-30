# comps scraper

A maintainer-run tool that populates `../data/comps/*.json` from
[tftactics.gg](https://tftactics.gg)'s team-comps tier list, cross-referenced
against [Community Dragon](https://raw.communitydragon.org)'s live TFT set
data for champion cost/traits. **Not part of the shipped app** -- it is
never built, imported, or invoked by `TFTOverlay`. See
[`../docs/adr/0004-comps-scraping.md`](../docs/adr/0004-comps-scraping.md)
for why this exists and what it deliberately does not do.

## What it does

1. Fetches Community Dragon's current TFT set data (champion name -> cost,
   traits) -- the same public feed `Packages/TFTData` already uses, no ToS
   concern here.
2. Renders tftactics.gg's team-comps tier list with a headless browser (it's
   a client-rendered React app with no discoverable JSON API -- verified by
   inspecting its bundle and network behavior) and expands every comp's
   detail panel to read its roster, items, hex-grid positioning, "Early
   Comp" unit subset, level-based flex options, and active trait/origin
   counts.
3. Maps each into `../docs/schema/comp.schema.json`'s shape and validates it
   before writing. A comp that fails validation is skipped with a warning,
   never written partially-wrong.
4. Never overwrites a file whose existing `source` is `"hand-authored"` --
   the two comps a human wrote stay a human's.

The "Early Comp" subset is carried two ways: as the `earlyOpener` prose
sentence, and (since #99) as the structured `earlyUnits` array the Openers
panel ranks. `earlyUnits` names are resolved against live set data first,
because the source's icons carry plain-ASCII alt text (`"RekSai"`) while the
name champion art resolves by is the punctuated one (`"Rek'Sai"`); a name
that doesn't resolve is dropped with a warning rather than shipped.
`earlyUnits` is optional in the schema, so a comp whose early subset the
scraper couldn't read omits it instead of guessing.

To top up comps written before that field existed, run
`python3 ../scripts/backfill_early_units.py` from the repo root -- it
recovers `earlyUnits` from the `earlyOpener` prose offline, and reports any
comp it could not extract rather than inventing a roster.

Several schema fields tftactics.gg simply doesn't expose (exact star
targets, per-comp augment picks, a prose difficulty rating, a clean
`"18.1"`-style patch string) are filled with clearly-labeled heuristics/
defaults documented in `mapper.py` -- read that file's docstrings before
trusting those fields blindly. Positioning, items, roster, and the
early-game/flex-option data are read directly from the source, not guessed.

## Usage

```sh
cd scraper
python3 -m venv .venv
./.venv/bin/pip install -r requirements.txt
./.venv/bin/playwright install chromium   # one-time browser download

./.venv/bin/python main.py --patch 18.1 --dry-run   # see what it would do
./.venv/bin/python main.py --patch 18.1             # actually write files
```

`--patch` isn't derivable from either data source (Riot's own "18.1"
numbering isn't in Community Dragon's feed, and tftactics.gg doesn't print
it in a machine-readable spot) -- pass the patch you're scraping against by
hand.

After running, validate from the repo root:

```sh
python3 scripts/validate_comps.py
```

(CI does this on every push against whatever is committed to `data/comps/`
-- this scraper's job is to produce that input, not to run in CI itself.)

## Tests

```sh
./.venv/bin/python -m pytest tests/
```

Tests cover `mapper.py`'s pure transform logic (name resolution, slug
generation, playstyle mapping, schema-validity of the mapped output)
against fixture data -- no network or browser involved.

## Rate limiting / etiquette

The scraper renders one page once per run and paces its ~34 expand-clicks
with a small delay (`scrape_comps(click_delay_seconds=...)`, default 0.2s).
It identifies itself with a descriptive User-Agent rather than impersonating
a browser. `robots.txt` on tftactics.gg does not disallow this path (checked
2026-08-29). This is meant to be run by a maintainer occasionally (roughly:
once per patch), not on a schedule that hits the site repeatedly.

## Why this lives outside the Swift package graph

This is a standalone Python tool with its own venv, deliberately not wired
into `Package.swift`, any Xcode scheme, or CI's build/test jobs. The output
(`data/comps/*.json`) is the only thing that crosses into the app's world,
and it's validated the exact same way whether a human or this script wrote
it.
