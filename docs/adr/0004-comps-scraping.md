# ADR 0004: Scraping tftactics.gg for comps data

## Status

Accepted. Supersedes the "hand-authored only for Phase 1/2" part of
[ADR 0002](0002-comps-source.md).

## Context

ADR 0002 chose hand-authored JSON in `data/comps/` for Phase 1, explicitly
rejecting scraping any comps meta-tracking site (tactics.tools, MetaTFT, TFT
Academy) as fragile and a ToS violation, and deferring an automatic,
legitimate pipeline (harvesting Riot's own match data and clustering boards)
to Phase 3.

That framing hasn't changed technically, but the maintainer is not willing
to hand-author and re-author comps every patch indefinitely, and Phase 3's
Riot-match pipeline has a real gate that wasn't fully appreciated when ADR
0002 was written: TFT match data requires its own product registration with
Riot, separate from a generic API key -- "only products that have been
granted access" per Riot's developer relations policy, with rate limits and
a selective approval process on top of the normal production-key
application. That is weeks of lead time at best, not a way to remove
manual maintenance this week.

Investigated and rejected before landing here:

- **Paid scraper-resale APIs** (found via a marketplace called parse.bot,
  wrapping MetaTFT and metabot.gg as REST APIs). These are the same
  fundamental act -- an unauthorized scraper -- with a subscription fee and
  a middleman on top, no license or SLA from either site, and a
  single point of failure if the source site notices and the reseller pulls
  the listing. Rejected: no advantage over scraping ourselves except who
  writes the scraper code, and it adds a paid, unlicensed vendor dependency
  for a core feature.
- **Kaggle / other static match datasets**: all stale snapshots of old sets
  (2019-2024). Doesn't remove the maintenance burden, just relocates a
  one-time version of it, and would already be wrong for the current patch.
- **Prior art** ([jacksonpan0/TFT-Tool](https://github.com/jacksonpan0/TFT-Tool),
  an open-source match-clustering tier-list generator): confirms the
  match-derived design ADR 0002 already anticipated is sound, but the
  project itself is dead (last commit January 2024, pre-Set-18) and
  unlicensed, so nothing here to build on directly.

## Decision

Scrape [tftactics.gg](https://tftactics.gg)'s team-comps tier list directly,
via a maintainer-run tool in [`../scraper/`](../scraper/), on the same
`comp.schema.json` ADR 0002 already designed for exactly this kind of
pivot ("Nothing in the comp detail view's contract should ever need to know
whether a comp came from a human or a harvester"). A new `source` value,
`"scraped-feed"`, was added to the schema's enum to distinguish this from
hand-authored, Riot-match-derived, or an eventual licensed feed.

Specifics that make this a materially different risk than what ADR 0002
rejected:

- **Maintainer-run, not shipped.** The scraper is a separate, un-packaged
  Python tool (its own venv, no SwiftPM target, not built or referenced by
  `TFTOverlay`). The shipped app never talks to tftactics.gg; only the
  maintainer's own machine does, occasionally (roughly once per patch).
  End users' installs never make a request to a third-party site this
  project doesn't control.
- **Static output, same as before.** The only thing that changes is *how*
  `data/comps/*.json` gets written -- the files themselves are the same
  static, versioned, schema-validated JSON ADR 0002 already committed to.
  A user's app behavior is identical either way.
- **No resale, no redistribution of the source site's presentation** -- just
  extracted facts (roster, items, tier, positioning) reshaped into this
  project's own schema and its own prose/templated text, not a copy of
  their page.
- **Reversible.** If this stops being viable (site blocks it, structure
  changes enough to break the scraper, or a cleaner path opens up), the
  static output files are unaffected and nothing about the app or the
  schema needs to change -- only `scraper/` gets rewritten or retired, same
  as ADR 0002's original "swap the source behind the schema" design intent.
- **`robots.txt` allows it** (checked 2026-08-29: `User-agent: * /
  Disallow:` -- empty). Not a substitute for a terms-of-service reading, but
  a genuine signal the site isn't trying to keep crawlers out generally.

What this does NOT change: this is still not a licensed relationship with
tftactics.gg, and their ToS may still prohibit automated access regardless
of `robots.txt`. That risk is accepted here as proportionate for a
maintainer-run, non-monetized hobby project producing static files, not
dismissed -- if tftactics.gg objects, the right response is to stop running
the scraper, not to route around a block.

### What the scraper can't get from this source

tftactics.gg's tier list doesn't expose exact star targets, per-comp augment
picks, a prose difficulty rating, or a Riot patch-number string. Rather than
relax the schema's requiredness (which would let the comp detail view fall
back to "some comps have fields, some don't" and reintroduce exactly the
UI-side special-casing ADR 0002 was designed to avoid), `scraper/mapper.py`
fills these with documented, clearly-labeled heuristics or templated text
generated from data the site *does* provide (e.g. its "Early Comp" unit
subset becomes the early-opener prose; its level-based flex-option data
becomes pivot notes and an extra level-plan entry). These are weaker than a
human's hand-written strategy notes and are expected to read that way; they
are not fabricated claims about the comp's win rate or matchup performance,
which this source also doesn't provide and the scraper doesn't invent.

## Consequences

- `data/comps/` now mixes `"hand-authored"` (the original 2) and
  `"scraped-feed"` (34, as of this ADR) comps. The scraper never overwrites
  a hand-authored file at the same slug.
- CI gained a `comps` job running `scripts/validate_comps.py` against
  whatever is committed (this was written but never wired into CI when ADR
  0002 shipped -- fixed alongside this change).
- Re-running the scraper each patch is now the maintenance model, replacing
  hand re-authoring. The maintainer should still spot-check output after a
  major set/patch change, since tftactics.gg's own markup/class names could
  change without notice and silently degrade extraction quality (the
  scraper validates against the schema either way, so a broken scrape fails
  loudly rather than shipping malformed data -- but a *successful*
  extraction of the wrong thing, e.g. after a site redesign reuses old class
  names for different content, wouldn't be caught by schema validation
  alone).
- If Riot's TFT product registration is ever obtained (Phase 3/4), the
  match-derived pipeline can be built and phased in per-comp without
  touching this scraper or the schema again -- exactly the swap ADR 0002
  designed for.
