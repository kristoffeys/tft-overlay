# tft-overlay

A native macOS overlay and companion app for **Teamfight Tactics**.

## Why this exists

There is no TFT overlay on macOS. Every existing one — Blitz, Mobalytics, MetaTFT — is built on Overwolf, which is Windows-only.

In 2026 it stopped being a gap and became the only option: TFT **dropped native macOS support on 2026-08-26**, with Set 18 "Enchanted Wilds" / patch 18.1 and the migration from the Hextech engine to Unreal. This is already in effect — not a forecast. Riot calls the removal temporary but has committed to no return date. (Separately, a standalone TFT client is due 2026-10-09, four patches into Set 18; that is a different thing and does not restore macOS.)

So on macOS today, TFT runs under [**Mactician**](https://sergeinaumov.dev/mactician) — an MIT-licensed community launcher that runs the Android TFT build in an Android Emulator on Apple Silicon. That is this project's primary host.

## What that means technically

| | Native PC client | Mactician (our host) |
|---|---|---|
| LCU API (lockfile, REST, WebSocket) | yes | **no** |
| Live Client Data API (port 2999) | responds, but useless for TFT | **no** |
| Game UI | PC layout | **mobile layout** |
| Window mode | exclusive fullscreen is a problem | ordinary resizable window — **easier** |
| Viewport geometry | inferred | **pinned** by Mactician resolution + UI scale |
| Extra capture path | — | **adb** to the guest framebuffer |

Board awareness is therefore a pixels-only problem, and the mobile UI means none of the existing PC overlay prior art transfers directly.

**Hard constraint, permanently:** pixels only. No process memory reads, no injection, on host or guest.

## Phases

| Milestone | What it delivers |
|---|---|
| **Phase 0 — Foundations** | Architecture, Xcode + SwiftPM skeleton, menu bar shell, hotkeys, logging, CI, and the `GameHost` abstraction |
| **Phase 1 — Tier 1: Comps & Items Overlay** | **The first shippable result.** Transparent click-through overlay with comps, comp detail, item cheat sheet, augments and unit reference, auto-showing around Mactician games. No screen capture. |
| **Phase 2 — Board Awareness (Vision)** | ScreenCaptureKit or adb capture, plus CV/OCR to read shop, board, bench, items, gold and level from the mobile UI |
| **Phase 3 — Recommendations & Data Platform** | Own comp statistics harvested from TFT-MATCH-V1, and a live recommendation engine driven by board state |
| **Phase 4 — Compliance, Release & Distribution** | Riot registration and policy audit, notarization, auto-update, privacy policy, public beta |
| **Deferred — Native macOS client** | LCU integration and borderless-fullscreen handling. Parked until Riot restores native macOS support. |

## Policy boundaries

Riot permits companion overlays, including in ranked. The bright lines this project stays behind:

- **No tracking or predicting opponents** during gameplay or the loading screen, including aggregate lobby stats
- No automation of input
- No obscuring the shop, board, trait rail or system menus
- The app is registered with Riot even though it uses only public APIs

## Status

Planning. See the issues and milestones.

---

*Independent community project. Not affiliated with, endorsed by, or sponsored by Riot Games. Not affiliated with Mactician.*
