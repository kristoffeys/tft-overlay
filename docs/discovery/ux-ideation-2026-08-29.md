# UX/UI ideation — tft-overlay

**Date:** 2026-08-29
**Objective:** Improve UX/UI of the Phase 1 overlay
**Segment:** macOS TFT players running the game under Mactician
**Desired outcome:** Open-ended — surface candidate improvements worth building
**Method:** Product trio ideation (PM / Designer / Engineer), then prioritisation

---

## 1. Where the product actually is

Grounded in the `verify-main` worktree (`/Users/kristof/orca/workspaces/tft-overlay/bream`), not from the README's aspirations.

### Shipped and committed

| Surface | State |
|---|---|
| App shell | `LSUIElement` menu bar app, no Dock icon, single-instance guard, launch-at-login |
| Overlay panel | Transparent, click-through `NSPanel`; interactive mode adds drag header + resize grip + accent border |
| Layout modes | `compact` (pinned build roster) / `expanded` (full panels), per-display geometry persisted |
| Panels | 4 — Comps list, Comp detail, Item cheat sheet, Unit/trait reference |
| Navigation | Ring cycling only, via `Option+C` / `Option+Shift+C` |
| Hotkeys | 5 rebindable actions, conflict detection, all `Option`-based |
| Preferences | 3 tabs — General (login, hotkeys, diagnostics), Overlay (opacity, scale, anchor, idle timeout), Data (patch, auto-refresh) |
| Data | Community Dragon ingestion, versioned disk cache, bundled offline fallback |

### In flight, uncommitted in this worktree (124 changed/untracked files)

Do **not** re-propose these — they are being solved right now:

- **Real art pipeline** — `ImageAssetCache`, `CDragonAssetURL`, `AssetImage`, `TFTAssetCatalog`
- **Comp library at scale** — 36 comps on disk, up from the 2 currently bundled
- **`Option`+drag to move the panel** without entering interactive mode (`OverlayModifierDragController`)
- `CompRosterGrid`, `UnitItemTooltip`, `SelectedBuildRosterView`

### Designed but not built

**`GameHost` / `MacticianHost` has zero Swift code.** ADR 0003 is Accepted and unusually well-evidenced — measured chrome insets, bundle IDs, adb port/serial, SCK-vs-adb benchmarks — but `git grep GameHost -- '*.swift'` returns nothing. Every host-aware idea below is a build-from-zero, not a wiring-up.

### The constraint that shapes everything

`TFTTheme` states its own design goal in a comment: panels meant to be read

> in peripheral vision, in half a second, over a moving game background

That is the bar. Most of the findings below are places the current UI does not meet the bar it set for itself.

---

## 2. Ideation — three perspectives

### Product Manager — business value, strategic alignment, customer impact

**PM1 · Zero-prompt first run that ends in a pinned comp**
A background-only app with no Dock icon launches to near-invisibility. The activation moment is "overlay is over my game showing the comp I'm going for" — today that requires discovering a menu bar item, an undocumented hotkey, and a pin star. ADR 0003 establishes Phase 1 needs *no* system permission prompts, so a genuinely frictionless first run is available and unclaimed. Activation metric: time-to-first-pin.

**PM2 · Patch-freshness as a first-class trust signal**
`Comp` carries `set` and `patch`; `CompDetailView` renders them as flat secondary grey. With hand-authored comps against a ~2-week patch cadence, "is this still true?" is the primary trust risk of the whole product. Show currency explicitly, let the list sort and filter on it, and let a stale comp say so.

**PM3 · Stage companion in compact mode**
`levelPlan` entries are already stage-keyed (`2-1`, `3-2`, …). In-game the only question is *what do I do right now*, and answering it currently means entering interactive mode and scrolling a 7-section detail view. A stage stepper — manual or hotkey-advanced — surfaces exactly the current entry. Ships with no CV and no Phase 2 dependency.

**PM4 · Visible policy and trust surface**
The README's bright lines are a real differentiator: no opponent tracking, no input automation, pixels-only. Surfacing them in-app builds trust with a player base that reasonably worries about bannable overlays, and doubles as Phase 4 Riot-registration groundwork.

**PM5 · Named overlay presets ("Study" / "In-Game")**
Opacity, scale, layout mode and active panel are four independent controls split across a modal Preferences window and two hotkeys. Two named presets collapse that to one choice, and give onboarding something concrete to hand a new user.

---

### Product Designer — user experience, usability, delight

**D1 · Persistent panel tab bar**
`OverlayAppState.Panel` has four cases cycled in a ring with no on-screen indicator. The user cannot see where they are or what else exists — the app's entire information architecture is invisible. A segmented control in the expanded header, full-strength in interactive mode and dimmed otherwise, makes the IA legible at a glance.

**D2 · An affordance for interactive mode**
The in-flight `Option`+drag solves *moving* the panel. It does not solve *using* it: scrolling, the search field, filter chips, pin stars and hex tooltips all still require interactive mode, and nothing on screen indicates that mode exists. A user who clicks the panel and gets no response has hit a silent dead end. Needs a persistent lock/unlock glyph and a first-run coach mark.

**D3 · Progressive disclosure in comp detail**
`CompDetailView` is ~292 lines rendering seven stacked sections into one scroll: header, board, carries, level plan, opener, pivot notes, augments, roster, trait breakdown. That is a study document, not something readable in half a second. Split it: a glance layer (board + carry items + current level-plan row) with everything else collapsed behind disclosure.

**D4 · In-place appearance controls**
Opacity and scale are sliders inside a 440×360 modal Preferences window — a window that covers the very overlay being adjusted. Feedback and control are in different places. Move them inline into interactive mode, or bind them to modifier+scroll on the panel itself.

**D5 · Peripheral-vision readability pass**
`TFTTheme.textSecondary` is white at 0.68 opacity on a panel at 0.92 opacity, itself rendered at a default overlay opacity of 0.9 — over a moving game background. That stack carries level-plan notes, pivot notes, board notes and augment column labels at 10–12pt. Separately, `TraitTagRow` collapses overflow to "+3", hiding exactly the information a player scans a comp row for. Both work against the theme's stated goal.

---

### Software Engineer — technical possibility, data leverage, scale

**E1 · Dock the overlay to the game window**
ADR 0003's `Viewport` already models everything needed: measured (never hardcoded) chrome insets, backing scale, `renderToContentScale`, and an opaque window token. Docking the panel to the Mactician window edge and following its moves and resizes converts the overlay from "a floating window the user manages" into "part of the game". Requires no TCC prompt. Requires writing `GameHost` from zero.

**E2 · Auto show/hide on game presence**
Same ADR, explicitly costed: `detect()` and `stateSignal()` are adb calls at 15–40ms, needing no Screen Recording grant. The overlay appears when TFT foregrounds and hides when it doesn't. This is the highest-leverage "it just works" behaviour reachable before Phase 2, and the ADR already argues it can ship prompt-free.

**E3 · Golden-image snapshot harness**
CLAUDE.md records that layout defects have already shipped past `swift test` in this repo, and prescribes a manual ritual — launch the binary, enumerate via `CGWindowListCopyWindowInfo`, `screencapture -l<windowid>`, look at it. Automating that (render each panel at fixed sizes, diff against committed PNGs) turns every idea on this list from "hope it looks right" into a reviewable diff.

**E4 · Contextual item cheat sheet**
`ItemDemandIndex` and `RecipeMatrix` both exist and are unit-tested. `ItemCheatSheetView` currently renders a generic recipe matrix — a between-games artifact. Keyed to the pinned comp it answers the in-game question instead: *I just got a Bow and a Rod; who on my board wants that, and is it a best-in-slot or a filler?*

**E5 · Expose the snap presets that already exist**
`OverlaySnapPreset` (`leftRail`, `rightRail`, `bottomStrip`) and per-display `OverlayGeometry` are modelled in OverlayKit today. Preferences exposes only a four-corner `anchor`. Wiring the existing presets and per-display persistence into the UI is close to free, and rail/strip shapes suit a mobile-layout game window far better than corner-anchored rectangles.

---

## 3. Prioritised top 5

Ranked on alignment with the UX/UI objective, impact, feasibility, and differentiation.

---

### 1 · Dock to Game — `E1 + E2`

**Auto-anchor the overlay to the Mactician window and show/hide it with game presence, so the user never positions or toggles it manually.**

**Why selected.** Every other idea improves a panel; this one removes the window-management burden that sits underneath all of them. It is the largest single UX change available, it is uniquely unavailable to competitors (there are none on macOS — Overwolf is Windows-only), and ADR 0003 already did the measurement work and proved it needs no permission prompt. It is also the highest effort here: `GameHost` is designed but entirely unwritten.

**Assumptions to validate**
- Players find a self-positioning overlay better than one they place once and forget — pinned-manually may be *good enough* that this is polish, not activation.
- `detect()` at 15–40ms can be polled often enough to feel instant without being noticed as CPU cost.
- Auto-hide never fires wrongly mid-game; a vanishing overlay is worse than one that never moves.
- Mactician's bundle ID, adb port and serial hold across their releases — ADR 0003 flags this as a live third-party dependency risk.

---

### 2 · Unlock — `D2`

**Give click-through mode a visible, discoverable way in and out, so a user who clicks the panel is never met with silence.**

**Why selected.** This is the product's clearest dead end. Everything interactive — search, filters, scroll, pins, tooltips — is unreachable until the user discovers `Option+O`, and nothing in the UI mentions it. Cheapest fix on this list relative to impact, and it is a precondition for D1, D3 and D4 being discovered at all. The in-flight `Option`+drag work solves an adjacent problem and makes this gap more visible, not less.

**Assumptions to validate**
- A persistent glyph is legible without becoming visual noise over a game.
- Users read a hover state on a click-through window as "this is interactive" rather than a rendering artifact.
- A one-time coach mark is retained — if not, the affordance must be permanent.

---

### 3 · Panel Tab Bar — `D1`

**Replace invisible ring-cycling with a persistent segmented control, so the user always knows which panel they are on and what else exists.**

**Why selected.** Four panels reachable only by blind cycling means the product's information architecture is unobservable. Low effort, no new data or host dependency, and it pays off immediately once the comp library grows from 2 to 36 and the panels start carrying real weight.

**Assumptions to validate**
- Four tabs fit legibly at compact width without crowding the content.
- Users prefer direct selection to cycling once cycling is muscle memory — worth checking rather than assuming.
- A dimmed tab bar in click-through mode reads as informative, not as broken/disabled UI.

---

### 4 · Glance Layer — `D3 + PM3`

**Collapse comp detail to what matters at the current stage — board, carry items, current level-plan row — with the rest behind disclosure.**

**Why selected.** This is the in-game core loop. A seven-section scroll is a study document; the theme file's own stated goal is half-a-second peripheral reading, and the detail view is the furthest thing in the app from meeting it. Merging PM3's stage stepper gives the glance layer its selection rule, so the two ideas are one feature. Needs no CV — the stage is a manual or hotkey-advanced value until Phase 2 can read it.

**Assumptions to validate**
- Players will advance a manual stage stepper mid-game rather than ignoring it and letting it go stale — the riskiest assumption on this list.
- Board + carry items + current level row is genuinely sufficient in-game; if players still open the full detail every round, the split adds a step instead of removing one.
- The collapsed sections stay findable between games, when the study document *is* the right artifact.

---

### 5 · Readability Pass — `D5`

**Raise contrast, weight and sizing on secondary text, and stop collapsing trait tags, so panels survive being read over a moving game background.**

**Why selected.** Concrete, cheap, and measurable against a target the codebase already set for itself. The compounding-opacity stack (0.68 text on 0.92 panel on 0.9 overlay) is a defect that can be quantified before and after rather than argued about. Rank 5 only because it improves what is already there instead of unlocking something new.

**Assumptions to validate**
- The compounding stack actually falls below usable contrast in play — measure it before redesigning.
- Higher contrast does not make the overlay more visually intrusive over the game, which is the reason the opacity is low in the first place.
- Full trait lists fit at realistic panel widths — `TraitTagLayout` has a fit budget and tests, so this is measurable, not speculative.

---

### Cross-cutting enabler

**E3 · Golden-image snapshot harness** should ride along with whichever of these is built first. Every idea above is a visual change, CLAUDE.md documents that visual defects have already shipped past `swift test` here, and the prescribed alternative is a manual screenshot ritual per change. Not a top-5 UX idea in its own right — it is what makes the other five verifiable.

### Runners-up

- **E5 · Expose snap presets** — near-free, since `OverlaySnapPreset` and per-display geometry are already modelled. Strong candidate to fold into idea 1.
- **E4 · Contextual item cheat sheet** — high in-game value; `ItemDemandIndex` and `RecipeMatrix` already exist and are tested.
- **PM2 · Patch freshness** — becomes urgent the moment the 36-comp library lands.

---

## 4. What to do next

1. **Measure before redesigning.** Idea 5 rests on a contrast claim that should be computed, not assumed. Ideas 1 and 4 rest on behavioural assumptions that need a player, not a spec.
2. **Build the harness early** (E3) if more than one of these is going ahead.
3. **Sequence by dependency:** ideas 2 and 3 are self-contained and cheap. Idea 4 is the core-loop bet. Idea 1 is a phase of work on its own, gated on writing `GameHost`.
4. **Watch for collisions with in-flight work** — the 124 uncommitted files in this worktree touch `CompDetailView`, `CompsListView`, `OverlayContentView` and `OverlayPanelController`, all of which ideas 3, 4 and 5 land on.
