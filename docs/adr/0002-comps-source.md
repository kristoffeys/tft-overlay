# 0002 — Comps data source for Phase 1

## Status

Accepted

## Context

The overlay's headline feature is showing TFT comps: what to build, what to itemize, how to position, when to pivot. Phase 1 cannot start UI work (comp list, comp detail view) until the shape of that data is fixed, and this is the highest-risk unknown going into the phase.

There is no legitimate public API for community comp data:

- **tactics.tools**, **MetaTFT**, and **TFT Academy** all publish comp tier lists, but none expose a public API for third-party consumption. Their data is a product, not a service.
- Scraping their sites is both fragile (their markup, tier logic, and URLs change every patch, and each patch fully invalidates last patch's comps anyway) and a terms-of-service problem — none of the three permit automated scraping in their ToS, and this project has already committed (see the project README's policy boundaries) to staying inside Riot's and third parties' rules rather than finding the edge of them.
- Riot's own APIs (`TFT-MATCH-V1`, `TFT-LEAGUE-V1`) expose raw match data, not curated comps. Turning that into comps is a data pipeline, not a fetch.

So "where do comps come from" is a build-or-partner decision, not an integration decision, and it has to be made before the comp detail view's data model is designed.

## Options considered

### (a) Hand-author comps in-repo as versioned JSON, per patch

Comps are written by hand (informed by public tier lists, patch notes, and normal play — not scraped) and committed to `data/comps/`, one JSON file per comp, validated against a JSON Schema in CI.

- **Legitimate.** No ToS exposure: nothing is scraped or automated against a third party.
- **Zero external dependencies.** No API key, no partner, no network call at runtime — comps ship inside the app bundle or a static file the overlay reads.
- **Real editorial cost.** Every patch invalidates most comps (new units, reworked traits, item pool changes). Someone — initially the maintainer — has to read patch notes and rewrite the file set each patch, indefinitely. This does not scale past a small number of comps or a single active maintainer without help.
- **Fast to ship.** Nothing to wait on; Phase 1 UI work can start as soon as the schema exists.

### (b) Derive comps from Riot TFT-MATCH-V1 by harvesting high-elo matches and clustering final boards

Pull match data for high-elo players, cluster final boards into comp archetypes, and compute win rates / pick rates / itemization statistics directly.

- **Legitimate and self-sustaining.** Uses Riot's own public API within its rate limits and terms; once running, it re-derives comps every patch automatically with no editorial hand.
- **Wrong phase.** This is Phase 3 machinery ("Recommendations & Data Platform") in this project's own roadmap: a harvesting pipeline, a clustering step, and a statistics store are a multi-week backend build, not a Phase 1 task.
- **Needs a production Riot API key.** Development keys are rate-limited to a level that cannot harvest enough high-elo matches to cluster anything meaningful; a production key requires a registered, reviewed application. That registration is already planned for Phase 4 (Riot registration and policy audit) — Phase 1 does not have it and should not block on getting it early.
- **Cold-start problem.** Set 18 (Enchanted Wilds) went live 2026-08-26, three days before this decision. Even with a production key today, there is not yet enough high-elo match volume on the new set to cluster a sane comp list.

### (c) Licensed/permitted third-party feed

Approach tactics.tools, MetaTFT, or TFT Academy for an explicit data-sharing agreement (API access, data license, or syndication deal).

- **Legitimate and potentially high-quality** — these sites already do the statistical work option (b) would have to build.
- **Not this project's call to make on a schedule.** It requires a business conversation with a third party (terms, pricing, attribution, liability) that has not started and has no committed timeline. Phase 1 cannot be blocked on a negotiation with an external party who owes this project nothing.
- **Reversible risk, not a technical one.** If a deal is ever struck, it's an ingestion-layer swap behind the same schema (see Decision below), not a rearchitecture.

## Decision

Ship Phase 1 on **(a) hand-authored, versioned JSON comps**, with the schema (`docs/schema/comp.schema.json`) deliberately shaped so that (b) can populate it later without touching the UI:

- `source` is an explicit field (`"hand-authored" | "match-derived" | "licensed-feed"`) from day one, not added later as a migration.
- `patch` and `schemaVersion` are separate: `patch` is per-comp content versioning (what this ADR calls "maintained per patch" for option a); `schemaVersion` is the file *shape*, which a harvester must also honor.
- Every field a harvester could plausibly compute (`tier`, `units[].starTarget`, `carries[].itemPriority`, augment preferences) is represented as plain data, not prose, so a Phase 3 clustering job can write these files directly instead of a human writing prose a machine can't produce.
- Nothing in the comp detail view's contract should ever need to know whether a comp came from a human or a harvester — it reads the same schema either way.

This means the Phase 3 pivot to (b) is a data-source swap behind an already-stable schema, not a redesign, and the editorial cost of (a) is bounded to Phase 1 and Phase 2 (roughly two set cycles) rather than indefinitely.

(c) is not rejected outright — if a comps site approaches this project, or the maintainer wants to reach out once the app has users worth showing, that conversation can happen in parallel without blocking anything, since it plugs into the same schema as a third `source` value.

## Consequences

- Phase 1 ships with a small, hand-picked set of comps (see `data/comps/`), not comprehensive tier-list coverage. That is an accepted scope cut, not an oversight.
- The maintainer owns re-authoring comps each patch until Phase 3 ships. This is real, recurring work and should be tracked as such, not treated as a one-time cost.
- CI must run the schema validator (`scripts/validate_comps.py`) on every change to `data/comps/`, so a malformed hand-authored comp fails fast instead of shipping broken data to the overlay.
- Phase 3 planning should treat "does the harvester's output validate against `comp.schema.json` unmodified" as an explicit acceptance criterion, not an afterthought — that is the check that this decision actually paid off.
