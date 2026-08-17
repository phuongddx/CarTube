# CarTube

## What This Is

CarTube is an iOS app that plays YouTube videos on CarPlay screens by rendering the YouTube mobile web inside a CarPlay-scene `WKWebView`, enhanced with injected JavaScript (ad blocking, SponsorBlock, age-restriction bypass, custom layout). The phone app is a launcher and settings editor; a share extension opens videos via the `cartube://` scheme. This milestone modernizes the app for App Store distribution and adds driver-friendly voice search.

## Core Value

A driver can open any YouTube video on their car screen — by voice, search, or share — with ads and sponsors skipped automatically.

## Requirements

### Validated

- ✓ Manual playback: paste/enter a YouTube URL or ID on the phone, plays on CarPlay webview — existing
- ✓ Share-extension playback: share a YouTube link from any app via `cartube://` handoff — existing
- ✓ YouTube web enhancement: ad blocking, SponsorBlock, age-restriction bypass, custom layout via injected JS — existing
- ✓ Now-playing takeover: detects audio playing in the YouTube app and offers to switch playback to CarTube — existing
- ✓ Settings toggles for scripts/features with persistence (UserDefaults) — existing
- ✓ Screen persistence (NoSleep) and brightness control during CarPlay playback — existing
- ✓ On-CarPlay text search with custom keyboard input simulation — existing
- ✓ TrollStore IPA build pipeline (`ipabuild.sh`) — existing (to be removed this milestone)

### Active

- [ ] App Store distribution: strip TrollStore entitlements, ldid re-signing, and `ipabuild.sh`; build with standard code signing
- **Private API audit**: remove the riskiest private-framework usage (MediaRemote now-playing interception, brightness private symbols, springboard reads) that automated App Review scans detect; keep the CarPlay webview video experience
- [ ] Raise deployment target from iOS 14.0 to iOS 16 minimum (AppIntents floor; enables modern speech/AppIntents APIs)
- [ ] Official CarPlay entitlement: apply under the audio category (honest fit; video category requires parked-only + AirPlay which contradicts Core Value); submit the application day 1 — it gates all on-device CarPlay work including the simulator
- [ ] Remove now-playing takeover feature and lock-screen dimming (both depend on severed private APIs); screen-off warning label survives
- [ ] Voice search via Siri: "Search YouTube for X" hands-free while driving
- [ ] Push-to-talk mic button on the CarPlay screen using on-device speech recognition
- [ ] YouTube Data API search backend with results list on CarPlay screen; tap to play

### Out of Scope

- Official CarPlay templates rebuild (audio-first) — user explicitly chose to keep webview video and accept review risk
- Dual distribution builds (App Store + sideload) — single App Store target this milestone
- Queued playback / playlist management — single video load model retained
- Crash/diagnostic telemetry — noted as codebase gap, not this milestone's focus

## Context

- Two-target Xcode project: `CarTube` main app + `PlayOnCarTube` share extension; Swift/SwiftUI phone shell, UIKit/WebKit CarPlay surface, Objective-C AutoHook swizzling layer, vendored JavaScript browser scripts
- Current compatibility window is iOS 14.0–15.4.1 with TrollStore installation; App Store build must target modern iOS
- CarPlay scene manifests a `UIWindow` with `CarPlayViewController` — not CarPlay template APIs; this is the deliberate core mechanism being preserved
- Known code debt that this milestone should not worsen: duplicated YouTube URL parser (app + extension), no test target, force-unwrap hotspots, string-literal UserDefaults keys
- Uncommitted work in the tree: new `CarTube/Assets.xcassets`, `ipabuild.sh` and project-file modifications
- Full codebase analysis lives in `.planning/codebase/` (ARCHITECTURE, STACK, CONCERNS, CONVENTIONS, INTEGRATIONS, STRUCTURE, TESTING)

## Constraints

- **App Review**: Webview video on CarPlay + remaining private APIs carry a high rejection risk — user accepted this risk explicitly; goal is TestFlight-ready, not guaranteed approval
- **CarPlay entitlement**: Apple application process required; timeline outside our control
- **YouTube Data API**: Requires a Google developer key; current model (2026-06 docs) is a dedicated bucket of 100 `search.list` calls/day at 1 unit each, shared across ALL installs; quota extension requires an API Compliance Audit the ad-block scripts would fail
- **Tech stack**: Keep SwiftUI/UIKit/WebKit hybrid; no rewrite of the phone shell
- **Behavioral contracts**: Settings "exit to apply" and single-cached-video model retained unless a phase explicitly changes them

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Keep webview video on CarPlay for App Store submission | User prioritized the core video experience over approval odds | — Pending |
| Remove riskiest private APIs (MediaRemote, brightness symbols), keep remaining hooks | Balance functionality against automated review detection | — Pending |
| Voice input: Siri intent + on-screen push-to-talk | Hands-free while driving plus fallback for users who haven't set up Siri | — Pending |
| Search results as tappable list on CarPlay screen | Driver glances once, taps once | — Pending |
| YouTube Data API for search backend | Reliable structured results vs fragile scraping | — Pending |
| Done = TestFlight-ready upload | User owns submission and handles review outcome | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `$gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `$gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-08-17 after initialization*
