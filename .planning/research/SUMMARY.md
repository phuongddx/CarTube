# Project Research Summary

**Project:** CarTube — App Store modernization + driver-safe voice search
**Domain:** iOS CarPlay app (hybrid SwiftUI/UIKit/WebKit) — App Store compliance, CarPlay entitlement, YouTube Data API v3 search, on-device speech
**Researched:** 2026-08-17
**Confidence:** HIGH (with a provenance caveat — see Confidence Assessment)

## Executive Summary

CarTube is an existing TrollStore-sideloaded app that renders YouTube's mobile web in a CarPlay-scene `WKWebView`; this milestone moves it to standard-signing TestFlight distribution and adds driver-safe search (Siri phrase + push-to-talk → tappable results). Research found no legitimate competitor ships webview video on CarPlay while driving: Apple's June 2026 video category exists precisely to route video to parked-only + AirPlay, which this milestone deliberately declines per user decision. The expert-shaped plan is therefore not a rebuild — it is surgical severance of every auto-detectable violation, plus first-party search/voice added as decoupled siblings around the untouched playback core, so the webview surface becomes the *only* remaining rejection vector with a documented fallback ladder.

Three load-bearing facts drive all sequencing. First, the CarPlay entitlement is an external day-1 dependency: under standard signing the CarPay scene never connects without it — **the simulator included** — so the application must precede all code work and later phases must be testable via phone-side mocks. Second, the YouTube quota model (verified 2026-06 docs) is a dedicated bucket of **100 `search.list` calls/day at 1 unit each, shared across all installs**, resetting midnight PT — the entire TestFlight audience combined, with the extension path effectively closed (compliance audit would fail on the ad-block scripts); search must be budgeted with automatic fallback to the existing webview search. Third, severance must precede search because both touch the same files (`CarPlaySingleton`, `CarPlayViewController.viewDidLoad`, `Utilities`). The stack is entirely first-party (AppIntents, Speech, plain `URLSession` REST) — zero new dependencies, one removed (`Dynamic`).

The dominant risks are stacked rejection (private-API string residue kills the submission in minutes before the *accepted* webview risk is even evaluated), silent swizzling failure after the iOS 16 deployment raise, API key leakage in a public repo (policy III.D.1.c names open-source embedding explicitly), and the ad-block × Data API ToS collision (key revocation independent of Apple). Every one has a concrete mitigation already specified: a `strings` scan gate in CI, a hook-verification debug screen, build-time key injection outside the repo + bundle-ID/API restrictions, a fail-closed degradation chain, and honest App Store metadata.

## Key Findings

### Recommended Stack

All first-party, no new third-party dependencies; the one existing package (`Dynamic`, MediaRemote protobuf decode) is **removed**, not extended. Details: [STACK.md](STACK.md).

**Core technologies:**
- **AppIntents** (`AppIntent` + `AppShortcutsProvider`, iOS 16+) — Siri "Search YouTube for X": `perform()` runs in-process, calls `SearchCoordinator` directly; no extension target, no XPC relay, zero user setup. The deployment raise already required makes this free. Never SiriKit `INIntent` (separate process, can't see the singleton/webview).
- **Speech** (`SFSpeechRecognizer` + `AVAudioEngine` tap, `requiresOnDeviceRecognition = true`) — push-to-talk with no network dependency, no server limits, no privacy-label burden. Both purpose strings are crash-mandatory in the same commit as first speech code.
- **YouTube Data API v3 `search.list`** via plain `URLSession` — ~100-line testable client; `part=snippet&type=video&maxResults=10&fields=`. Current quota: **100 calls/day dedicated bucket, shared across installs, midnight PT reset** — plan around it, don't fight it.
- **UIKit child-VC overlay** (`SearchResultsViewController`) — native glanceable results over the webview, following the proven `KeyboardView` precedent; deliberately does NOT resize the webview beneath (playback continuity).
- **Standard Xcode App Store signing** — replaces the entire TrollStore `ipabuild.sh`/ldid pipeline.
- **`strings` binary scan gate** (build script, app + `.appex`) — fails CI on private-API markers (`SB[A-Z]`, `BKS`, `MRMediaRemote`, `_simulateTextEntered`, `PrivateFrameworks/`, …).

### Expected Features

Full landscape: [FEATURES.md](FEATURES.md).

**Must have (table stakes):**
- App Store build that launches under standard signing — the milestone's core infrastructure (entitlement, severance, signing)
- Search YouTube from the car, with a glanceable tappable results list (≤5–8 rows, ≥60pt, one tap to play)
- Playback continuity while searching (overlay must not navigate/resize the webview)
- Phone-first permission setup (system prompts render only on iPhone; prompting from CarPlay dead-ends)
- YouTube attribution on results (policy III.F.2 — compliance that doubles as trust signal)

**Should have (differentiators):**
- Siri voice search (zero taps) + push-to-talk (for non-Siri users) — both funnel through one `SearchCoordinator`
- Webview search as invisible fallback when quota/key dies — turns legacy `searchVideo` into the safety net
- Ad/sponsor skipping retained but **never advertised** in App Store metadata

**Defer (v2+):**
- Parked-video mode under the official CarPlay video category (requires AirPlay video) — the sanctioned long-term shape, contradicts Core Value today
- Template-based CarPlay rebuild, playlists/queued playback, telemetry, quota-extension tooling

**Conscious removals (not silent losses):** now-playing takeover (no public API exists — `MPNowPlayingInfoCenter` is write-only for own app) and lock-screen dimming (private brightness symbols); the screen-off warning label survives via the public notify path.

### Architecture Approach

New components attach as **siblings around the existing singleton** — never inside it. The webview playback path (`CarPlaySingleton.loadUrl` → `CarPlayViewController` → `WKWebView.load`) stays byte-identical; every new feature terminates in a call to it. Details: [ARCHITECTURE.md](ARCHITECTURE.md).

**Major components:**
1. `YouTubeSearchService` — stateless API client, no UIKit/CarPlay imports; the unit-testable island in a codebase with zero tests
2. `SpeechRecognizerService` — terminal: emits a transcript `String`, holds no CarPlay references, structurally unable to destabilize playback
3. `SearchCoordinator` — the one funnel for Siri + mic + degradation; the only new code touching `CarPlaySingleton` (≤3 passthrough methods)
4. `SearchResultsViewController` + mic button — UIKit children of `CarPlayViewController`, layered like `KeyboardView` today
5. `SearchCarTubeIntent` + `CarTubeShortcuts` — ~40 lines over the finished funnel, built last so phrase extraction doesn't churn

**Key patterns:** overlay-not-navigation (webview never moves until a concrete `videoId` is chosen); singleton passthrough not ownership; fail-closed degradation chain (no key / 403 quota / speech denied → existing webview search or hidden mic — never a dead screen). **Anti-patterns rejected:** results rendered in the webview, search logic on the singleton, SiriKit extension, committed API key, server-based speech.

### Critical Pitfalls

Full detail: [PITFALLS.md](PITFALLS.md). Top five:

1. **CarPlay entitlement treated as late config** — it gates even simulator CarPlay scenes under standard signing; submit day 1 (audio category, honestly justified), record the date, develop behind phone-side mocks until granted, then new provisioning profile + automatic signing OFF.
2. **Private-API residue surviving "removal"** — deletion of calling code doesn't remove compiled strings/selector tables; every marker category is currently present (`dlsym` names, framework paths, `kMRMediaRemote*` keys, swizzled selectors, TrollStore entitlement keys). Removal must delete headers/hooks/entitlements keys, and a `strings` gate on app + `.appex` must run in CI forever.
3. **Severance breaking load-bearing features** — `getNowPlaying` sits in the `viewDidLoad` launch chain; `dlsym` NULL force-cast is a crash, not an error. Map every symbol to callers first; make explicit keep/kill decisions (takeover → remove; dimming → remove; warning label → keep); remove Settings toggles in the same phase.
4. **Quota + key exposure** — 100 searches/day *total* (each results page = a full call; invalid requests cost too); key must never touch the repo (public fork, III.D.1.c), must be build-time injected with API + bundle-ID restrictions, and 403 must degrade to webview search, not error.
5. **Speech/permission UX at drive time** — both purpose strings mandatory (crash without), prompts only on iPhone, mic button gated on authorization, visible listening state (2.5.14), on-device recognition only.

## Implications for Roadmap

Dependency-driven build order 0–6 from ARCHITECTURE.md maps cleanly to six phases:

### Phase 1: External Dependencies & Project Setup
**Rationale:** The CarPlay entitlement has an uncontrolled external timeline (days–months, no SLA) and gates all on-device CarPlay work; the Google key setup shares the "external, start now" character. Nothing else may wait on either.
**Delivers:** Entitlement application submitted (audio category, dated, rationale documented as Key Decision); separate dev Google Cloud project vs shipping key; key delivery mechanism decision (build-time xcconfig vs remote config); API + bundle-ID restrictions; XCTest target scaffold.
**Addresses:** Entitlement (blocking), key hygiene setup.
**Avoids:** Pitfalls 1, 2, 6 (setup half).

### Phase 2: Severance, Signing & Modernization
**Rationale:** Sever before extend — the files search must touch are the exact files losing MediaRemote/brightness code; extending first means rebasing new wiring over scheduled deletion. This phase makes the binary scanner-clean and TestFlight-installable.
**Delivers:** MediaRemote/brightness/springboard removal with caller-map-driven feature decisions; Settings cleanup (no dead toggles); TrollStore entitlements + `ipabuild.sh` removal; standard signing; deployment target → iOS 16; hook behavioral re-validation with a hook-verification debug screen; `strings` scan gate wired into CI; `exit(0)` settings replacement decision (behavioral contract — needs user sign-off).
**Addresses:** App Store build (table stakes); conscious removal of takeover + dimming.
**Avoids:** Pitfalls 3, 4, 5; webview-script re-verification after the SDK raise.

### Phase 3: Search Core (backend)
**Rationale:** Leaf-first — the API client has zero app dependencies, is unit-testable before any CarPlay work, and carries the external unknowns (key behavior, quota reality).
**Delivers:** `YouTubeSearchService` + `SearchResult` (Codable); budgeted quota strategy (~100/day app-wide, one page, explicit submit only, last-query cache design); 403 → webview-search fallback; key injected at build time, never committed; the project's first real tests (fixture JSON → `[SearchResult]`).
**Addresses:** Search-from-car core; attribution requirement passed to Phase 4 UI.
**Avoids:** Pitfalls 6, 7, 8 (documented ToS-collision Key Decision + swappable protocol-based client).

### Phase 4: CarPlay Search Surface
**Rationale:** Results display must exist before voice has anywhere to land; the overlay follows the proven keyboard precedent, so novelty risk is low. Works via phone-side mock until the entitlement lands.
**Delivers:** `SearchResultsViewController` (opaque full-screen, non-resizing, ≥60pt rows, thumbnail + title + channel + duration); `SearchCoordinator` funnel with degradation chain; ≤3 `CarPlaySingleton` passthroughs; "Results from YouTube" attribution.
**Addresses:** Glanceable-results table stakes; quota-fallback UX.
**Avoids:** Anti-patterns 1–2 (webview-rendered results, singleton bloat); CarPlay HIG glance-time violations.

### Phase 5: Voice Input
**Rationale:** Builds on the finished funnel + overlay; permission onboarding must exist before any CarPlay mic surface. Siri comes last-within-this-phase so App Shortcut phrase extraction sits on stable ground.
**Delivers:** `SpeechRecognizerService` (on-device, availability-gated); mic button with visible listening state + auto-stop; phone-first-run permission onboarding (both purpose strings in the first speech commit); Siri App Shortcut ("Search YouTube for …").
**Addresses:** Push-to-talk + Siri differentiators; permission-setup table stakes.
**Avoids:** Pitfall 9; anti-pattern 5 (never server-based speech fallback — hide the mic instead).

### Phase 6: TestFlight Submission Package
**Rationale:** User owns submission; the upload must be coherent so the webview surface is the *only* rejection reason — everything else fixed, notes specific, metadata honest.
**Delivers:** Entitlement-era provisioning switch if granted (new profile, automatic signing off, CarPlay Simulator verification); App Review notes describing the CarPlay webview mechanism under the audio category; honest metadata (no ad-block/SponsorBlock marketing); final scan pass on app + `.appex`; documented fallback ladder (parked-gate / audio-UI fast-follow); existing hardening items (GitHub update-check validation, pasteboard read) resolved or consciously deferred.
**Addresses:** Review-notes deliverable; submission gate.
**Avoids:** Pitfall 10; the "bare upload" failure mode.

### Phase Ordering Rationale

- **External before internal:** entitlement + key setup have timelines we don't control; starting them in Phase 1 means Phases 2–5 never block on Apple or Google.
- **Sever before extend:** identical files (`viewDidLoad`, `CarPlaySingleton`, `Utilities`); deleting first means new wiring never sits atop code scheduled for removal, and review-risk surface shrinks before anything new is added.
- **Leaf before UI before voice:** the API client is testable in isolation; the overlay is the landing zone both voice surfaces require; Siri is a thin layer finalized last to avoid phrase re-extraction churn.
- **Decoupling is the safety strategy:** search/voice terminate in the existing `loadUrl` and never sit between singleton and webview — this is exactly what makes the fallback ladder (Phase 6) cheap if the webview surface is rejected.
- **Every phase carries its scan gate:** the `strings` check created in Phase 2 runs in all subsequent CI, catching regression before upload.

### Research Flags

Phases likely needing deeper research during planning (`/gsd-plan-phase --research-phase`):
- **Phase 5 (Voice):** speech details are MEDIUM confidence (on-device availability matrix by locale/device, permission-UX specifics from established knowledge, not directly fetched docs); a focused pass on Speech framework current behavior is warranted.
- **Phase 1 (light):** entitlement application internals are Apple-ID gated and unverifiable in advance; worth a short research pass on request-text positioning under the audio category. Optional — the substance is "submit, date it, wait."

Phases with standard patterns (skip research-phase):
- **Phase 2:** codebase-driven; the marker inventory and caller map already exist in PITFALLS.md. Needs *device validation*, not doc research.
- **Phase 3:** plain REST + fixture tests; quota model already verified against two live doc pages.
- **Phase 4:** mirrors the existing `KeyboardView` wiring in-repo.
- **Phase 6:** guidelines fully verified; this is writing and checklist work.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All first-party Apple frameworks + verified Google quota docs; but **provenance caveat:** STACK.md was synthesized inline by the orchestrator (subagent failed twice on API capacity) from the verified ARCHITECTURE.md/PITFALLS.md sources — accurate, but not an independent research pass |
| Features | HIGH (constraints) / MEDIUM (competitors) | HIG and guideline categorization verified against official docs; competitor outcomes are community-reported |
| Architecture | HIGH | Official Apple/Google docs cross-checked against the local codebase; UIKit-in-CarPlay-scene viability verified empirically by the existing app |
| Pitfalls | HIGH | Apple/Google official documents fetched and read directly; swizzling and speech-UX details are codebase analysis + platform knowledge (MEDIUM within an otherwise HIGH file) |

**Overall confidence:** HIGH — every load-bearing claim (quota model, entitlement gating, category constraints, marker inventory, launch chain) traces to an official document or a direct codebase read. The caveat is breadth, not accuracy: STACK and FEATURES are derived views of the same verified sources rather than independently gathered dimensions.

### Gaps to Address

- **AutoHook behavior on iOS 16+ (unresolvable by research):** type-encoding match may silently skip; `_simulateTextEntered` may be gone. Phase 2 must validate empirically on device/simulator; search phases already avoid depending on the keyboard path.
- **Entitlement application internals:** Apple-ID gated; request-text quality under the audio category can't be pre-verified. Handle with a careful Phase 1 draft + documented rationale.
- **On-device speech availability matrix:** locale/device gating of `supportsOnDeviceRecognition` — validate on target hardware in Phase 5; degrade by hiding the mic.
- **Key delivery mechanism (xcconfig vs remote config):** a design decision for Phase 3 planning; both patterns are standard, rotation story is the deciding factor.
- **Quota extension feasibility:** effectively closed (compliance audit examines ad-block/player modification); treat 100/day as the hard ceiling and scale via fallback + caching, not extension hopes.
- **No test target exists:** Phase 3 establishes the testing pattern for the whole repo — size the phase for that, not just the client.
- **Webview rejection outcome:** unknowable until Apple reviews; the fallback ladder (Phase 6 deliverable) is the mitigation, plus keeping search/voice decoupled so they survive every rung.
- **Existing security items** (unvalidated GitHub update-check response, pasteboard reads on activation): fold into Phase 2 or Phase 6 hardening; small but reviewer-visible.

## Sources

### Primary (HIGH confidence)
- App Review Guidelines (developer.apple.com/app-store/review/guidelines/) — 2.1, 2.3.1, 2.3.7, 2.5.1, 2.5.2, 2.5.11, 2.5.14, 4.2, 4.4, 5.1.1, 5.2.1–5.2.3 — fetched directly
- CarPlay Developer Guide, June 2026 (developer.apple.com) — entitlement process, provisioning (incl. simulator requirement, automatic-signing-off), audio vs. video categories (parked-only + AirPlay), "cannot selectively show/hide CarPlay"
- YouTube Data API quota docs (developers.google.com/youtube/v3/determine_quota_cost + /getting-started, updated 2026-06-01) — 100 `search.list` calls/day dedicated bucket @ 1 unit, 10k units/day other endpoints, midnight-PT reset; **contradicts PROJECT.md's original 100-units-per-search note (since corrected)**
- YouTube API Services Developer Policies (2026-06-24) — III.A.1–2, III.C.5, III.D.1.c, III.D.3, III.D.6, III.E.1, III.F.1–2, III.I.1/5/6
- Google API key best practices (support.google.com/googleapi/answer/6310037) — no embedding, restrictions, rotation
- developer.apple.com AppIntents (App Shortcuts, `AppShortcut`, `AppShortcutsProvider`) and Speech framework docs
- Local codebase — marker inventory, launch chain, singleton/controller/keyboard wiring, duplicated parser, settings flow (read directly; see `.planning/codebase/`)

### Secondary (MEDIUM confidence)
- Speech permission/UX specifics (purpose-string crash behavior, prompt placement, on-device gating) — established platform knowledge; Apple docs JS-rendered, not directly fetched
- AutoHook type-encoding matching and modern-SDK swizzling behavior — codebase analysis + ObjC runtime knowledge; untested above iOS 15.4.1
- Entitlement approval timelines (days–months, no published SLA) — community-reported

### Tertiary (LOW confidence)
- Competitor landscape claims ("no legitimate middle-ground app exists") — inference from guidelines + category rules + community reports; directionally sound, unverifiable exhaustively

---
*Research completed: 2026-08-17*
*Ready for roadmap: yes*
