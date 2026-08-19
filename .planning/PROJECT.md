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
- ✓ App Store distribution: TrollStore entitlements/ldid/`ipabuild.sh` removed, standard code signing (one Apple Developer team across all 4 build configs) — Phase 2
- ✓ Private API audit: MediaRemote now-playing interception, brightness private symbols, and springboard reads removed; CarPlay webview video experience kept — Phase 2
- ✓ Deployment target raised from iOS 14.0 to iOS 16 minimum — Phase 2
- ✓ Now-playing takeover feature and lock-screen dimming removed; screen-off warning label survives — Phase 2
- ✓ Permanent `strings` binary scan gate in CI catching private-API regression on both binaries — Phase 2
- ✓ Settings applies in place (no `exit(0)`) — Phase 2
- ✓ Stateless, unit-tested YouTube Data API v3 search client (`YouTubeSearchService`) with build-time-injected key, quota-deliberate single-page requests, last-query cache, and fail-closed degradation to the existing webview search on 403/quota/key/decode failure — Phase 3

### Active

- [ ] Official CarPlay entitlement: apply under the audio category (honest fit; video category requires parked-only + AirPlay which contradicts Core Value); submit the application day 1 — it gates all on-device CarPlay work including the simulator — Phase 1, submitted 2026-08-18 (Case-ID 21672656), **granted 2026-08-18**; entitlements-file wiring done, provisioning-profile creation/import + Xcode signing toggle + CarPlay Simulator scene verification remain human/portal steps (see docs/runbooks/carplay-entitlement-grant-wiring.md)
- [ ] Voice search via Siri: "Search YouTube for X" hands-free while driving
- [ ] Push-to-talk mic button on the CarPlay screen using on-device speech recognition
- [ ] Native, glanceable results list on the CarPlay screen wired to the Phase 3 search backend; tap to play — Phase 4
- [ ] Fix HideScrollBar Debug-row verification logic — compares against the wrong IMP and may always report PASS regardless of hook-install state (02-REVIEW.md CR-02, knowingly left unfixed in Phase 2)
- [ ] Regenerate AGENTS.md / README.md — both still describe the removed `Dynamic` package, lock-screen dimming, and the retired exit-to-apply Settings contract (02-REVIEW.md WR-05/WR-06)
- [ ] `scan-private-apis.sh` marker-list/test gaps — missing `BKEnableALS` marker, only 3/14 markers have positive-match test coverage, BRE instead of fixed-string grep (02-REVIEW.md WR-01/WR-02/WR-03)

### Out of Scope

- Official CarPlay templates rebuild (audio-first) — user explicitly chose to keep webview video and accept review risk
- Dual distribution builds (App Store + sideload) — single App Store target this milestone
- Queued playback / playlist management — single video load model retained
- Crash/diagnostic telemetry — noted as codebase gap, not this milestone's focus

## Context

- Two-target Xcode project: `CarTube` main app + `PlayOnCarTube` share extension; Swift/SwiftUI phone shell, UIKit/WebKit CarPlay surface, Objective-C AutoHook swizzling layer, vendored JavaScript browser scripts
- Deployment target is iOS 16.0 minimum (raised from 14.0 in Phase 2); standard App Store code signing, zero private entitlement keys
- CarPlay scene manifests a `UIWindow` via `UIWindowSceneSessionRoleCarPlay` with `CarPlayViewController` — not CarPlay template APIs; this is the deliberate core mechanism being preserved. This scene role only activates once iOS sees a granted CarPlay entitlement in the app's entitlements file — until Phase 1's Apple application (Case-ID 21672656) is granted and wired in, `CarTube.entitlements` stays a bare empty dict and no CarPlay simulation (Simulator External Displays, CarPlay Simulator.app, or a real head unit) can connect to the app's CarPlay scene at all
- Known code debt that this milestone should not worsen: duplicated YouTube URL parser (app + extension), no test target (Phase 2 added a shell-script test suite for the private-API scanner, not a Swift/XCTest target), force-unwrap hotspots (one flagged in CarPlayViewController.loadUrl, 02-REVIEW.md WR-07), string-literal UserDefaults keys
- Full codebase analysis lives in `.planning/codebase/` (ARCHITECTURE, STACK, CONCERNS, CONVENTIONS, INTEGRATIONS, STRUCTURE, TESTING)

## Constraints

- **App Review**: Webview video on CarPlay + remaining private APIs carry a high rejection risk — user accepted this risk explicitly; goal is TestFlight-ready, not guaranteed approval
- **CarPlay entitlement**: Apple application process required; timeline outside our control
- **YouTube Data API**: Requires a Google developer key; current model (2026-06 docs) is a dedicated bucket of 100 `search.list` calls/day at 1 unit each, shared across ALL installs; quota extension requires an API Compliance Audit the ad-block scripts would fail
- **Tech stack**: Keep SwiftUI/UIKit/WebKit hybrid; no rewrite of the phone shell
- **Behavioral contracts**: Settings now applies in place (Phase 2 replaced "exit to apply" with `applyConfigurationInPlace()`); single-cached-video model retained unless a phase explicitly changes it

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Distribution bundle ID: `com.cartube.carplay` (+ `.playon` extension) | User choice 2026-08-18 — product-brand-first prefix; replaces upstream `com.avangelista.CarTube` which belongs to the fork's original author | ✓ Shipped Phase 2 — all 4 build configs (CarTube/PlayOnCarTube × Debug/Release) aligned to the new bundle IDs and team K2TYLYAWMK; Release configs had silently kept the old `com.avangelista.*` IDs with 3 different signing teams until code review caught it (02-REVIEW.md CR-03) |
| Keep webview video on CarPlay for App Store submission | User prioritized the core video experience over approval odds | — Pending |
| Remove riskiest private APIs (MediaRemote, brightness symbols), keep remaining hooks | Balance functionality against automated review detection | — Pending |
| Voice input: Siri intent + on-screen push-to-talk | Hands-free while driving plus fallback for users who haven't set up Siri | — Pending |
| Search results as tappable list on CarPlay screen | Driver glances once, taps once | — Pending |
| YouTube Data API for search backend | Reliable structured results vs fragile scraping | — Pending |
| Done = TestFlight-ready upload | User owns submission and handles review outcome | — Pending |
| CarPlay entitlement requested under the audio category | App genuinely plays YouTube audio through the vehicle's system; the video category requires AirPlay video support and describes parked-only use, contradicting the milestone's core value. Residual risk: an on-screen video surface under an audio entitlement may still draw review scrutiny | — Pending |
| API key delivered via gitignored root Secrets.xcconfig with $(YOUTUBE_API_KEY) Info.plist injection | Apple's documented substitution, zero moving parts; CI rotates via xcodebuild command-line override. Known limit: the key ships in the IPA and is public-by-design, guarded by API + iOS bundle-ID restrictions and quota alerting | — Pending |
| Google dev-key project deferred to Phase 3 | Researcher recommendation; Phase 1 provisions only the shipping key so search work never blocks on a second project | — Pending |
| Phase 2 removes ALL private entitlement keys, including SBStarkCapable, com.apple.runningboard.assertions.webkit, and com.apple.multitasking.systemappassertions | INFRA-02 (no private entitlement keys) wins over keeping NoSleep on entitlements; the NoSleep hidden webview is replaced by the public UIApplication idle timer in plan 02-03, and any residual wake-lock degradation is observable on the INFRA-04 hook-verification debug screen rather than treated as a blocker | ✓ Shipped Phase 2 — entitlements confirmed empty dict; idle-timer replacement live |
| Phase 2 strings-scan gate (INFRA-05) fails only on symbols this phase REMOVES (MediaRemote, BackBoardServices brightness, SpringBoard lock/port, TrollStore entitlement markers) | Surviving private WebKit calls (_simulateTextEntered) and remaining AutoHook swizzling stay out of the gate per the accepted webview-video risk; the surviving com.apple.springboard.hasBlankedScreen notify key powering the screen-off warning label is likewise excluded | ✓ Shipped Phase 2 — wired into `.github/workflows/scan.yml`; 6/6 TDD tests pass; exit 0 on both real compiled binaries |
| Settings apply-in-place must also resync idle-timer state, not just webview config | Code review (02-REVIEW.md CR-01) caught that replacing `exit(0)` with `applyConfigurationInPlace()` only rebuilt the webview — the Screen Persistence Helper toggle had no effect until the next CarPlay scene transition | ✓ Fixed Phase 2 — `CarPlaySingleton.applyConfiguration()` now also calls `enablePersistence()`/`disablePersistence()`, mirroring the scene delegate's own gating |
| Local Xcode/Simulator SDK-runtime mismatch (Xcode 26.3 ships iphonesimulator SDK 26.2; only iOS 26.5 runtime was installed) | Blocked real `BUILD SUCCEEDED` verification for 3 of 4 Phase 2 plans; installing a matching iOS 26.3.1 simulator runtime resolved it mid-phase | ✓ Resolved Phase 2 — closed out `.planning/WINDOWS.md` entries 3-5; all subsequent builds/scans run against real compiled binaries |
| No user-visible search toggle shipped in Phase 3 | SRCH-01..04 name no toggle; the quota budget (explicit-submit surface, one-page requests, last-query cache) is enforced structurally in code, not by a settings switch; the UX-level decision of whether/how to expose a toggle belongs to Phase 4's coordinator once the results UI exists | — Pending |
| Share-extension parser dedupe deferred (duplicated YouTube URL-extraction regex in `Utilities.swift` and `ShareViewController.swift`) | Deduping requires a pbxproj target-membership change (`Utilities.swift` added to the `PlayOnCarTube` extension target) for zero Phase 3 value; recorded as tech debt per 03-PATTERNS.md's recommendation to defer; revisit when voice/Siri handoff (Phase 5) needs shared parsing, mindful of Pitfall 4's parser-drift warning | — Pending |
| Dev key separated into a dedicated Google Cloud project (`cartube-dev`), distinct from the shipping project (`cartube-shipping`) | Development and CI must not burn the shipping project's shared 100/day `search.list` bucket (Pitfall 7); fixture-only unit tests already make quota-spend-in-tests structurally impossible via `MockURLProtocol`, and the dev key covers the remaining live-smoke/manual-verification surface | — Pending |

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
*Last updated: 2026-08-19 after Phase 3*
