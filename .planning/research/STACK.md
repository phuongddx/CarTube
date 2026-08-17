# Stack Research

**Domain:** App Store distribution, CarPlay entitlement, YouTube Data API v3 search, and on-device speech recognition for an existing hybrid SwiftUI/UIKit/WebKit iOS app
**Researched:** 2026-08-17
**Confidence:** HIGH for Apple framework choices and quota model (verified by the parallel Architecture research via official docs); MEDIUM for entitlement-process details (Apple-ID gated)

> Provenance note: this dimension's subagent runs failed twice on upstream API capacity errors (503/504). Content below was synthesized inline by the orchestrator from the verified sources in `.planning/research/ARCHITECTURE.md` (Apple docs via sosumi mirror, Google docs 2026-06-01) and `.planning/research/PITFALLS.md` (App Review Guidelines, CarPlay Developer Guide June 2026, YouTube developer policies 2026-06-24, Google key best practices). No new claims were introduced beyond those verified sources.

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| AppIntents framework (`AppIntent`, `AppShortcutsProvider`, `AppShortcut`) | iOS 16.0+ | Siri voice-search trigger: "Search YouTube for X" | `perform()` runs in the app process — calls `SearchCoordinator` directly with no extension target, no XPC relay, no intent-definition files; App Shortcuts need zero user setup; phrases compile-time extracted. Deployment-target raise (already required) makes this free |
| Speech framework (`SFSpeechRecognizer` + `AVAudioEngine` input tap + `SFSpeechAudioBufferRecognitionRequest`) | iOS 16.0+ (on-device floor practical floor) | Push-to-talk transcript | On-device recognition (`requiresOnDeviceRecognition = true`) has no network dependency (moving car), no server usage limits, no privacy-label burden. Crashes without `NSSpeechRecognitionUsageDescription` — both purpose strings are mandatory in the same commit as first speech code |
| YouTube Data API v3 `search.list` | v3 (REST), via plain `URLSession` | Structured search results (videoId, title, channel, thumbnail) | Direct REST GET with API key, `part=snippet&type=video&maxResults=10&fields=` — no Google API client library needed; the client is ~100 lines and unit-testable with fixture JSON. Current quota model: **100 `search.list` calls/day dedicated bucket at 1 unit each** (verified 2026-06-01 docs) — plan around it, don't fight it |
| UIKit child view controller overlay (`SearchResultsViewController`) | iOS 16.0+ | Driver-glanceable tappable results list over the webview | Follows the proven `KeyboardView` precedent in this codebase — native rows, known frame geometry, no JS/DOM interaction; deliberately does NOT resize the webview beneath |
| Standard Xcode automatic (or manual) App Store signing + provisioning | Xcode current | TestFlight distribution | Replaces TrollStore `ipabuild.sh`/ldid pipeline entirely; no unsigned/re-signed artifacts |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| (none — deliberate) | — | — | No new third-party dependencies this milestone. The single existing Swift package (`Dynamic`, used for MediaRemote protobuf decode) is **removed**, not extended. Keeping the search/speech stack first-party reduces App Review surface and dependency risk |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| `strings` binary scan gate (build script) | Fail the build if private-API markers appear in app or `.appex` binaries | Patterns: `SB[A-Z]`, `BKS`, `MRMediaRemote`, `kMRMediaRemoteNowPlayingInfo`, `_hasSleepDisabler`, `_simulateTextEntered`, `_UIStaticScrollBar`, `PrivateFrameworks/`, `com.apple.springboard.hasBlankedScreen`. Runs in CI and pre-submission |
| CarPlay Simulator (Xcode) + entitlement-era provisioning profile | Validate CarPlay scene connection without a head unit | Simulator development also requires the CarPlay capability on the App ID — a reason the entitlement application is a day-1 task |
| Google Cloud Console (separate dev project) | Dev testing key isolated from shipping key | Shared-bucket quota means dev usage eats production search budget if keys share a project |
| XCTest (new test target) | Unit tests for search service, URL parser, degradation chain | Codebase currently has zero tests; the search core (no UIKit deps) is the testable island |

## Installation

```bash
# No packages to install. Removals instead:
# - Delete Swift package dependency: Dynamic (MediaRemote decode path dies with it)
# - Delete ipabuild.sh (TrollStore pipeline)
# - Strip private entitlement keys from CarTube.entitlements
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| AppIntents (iOS 16+) | SiriKit `INIntent` + Intents extension | Never for this app — extension runs in a separate process, can't see `CarPlaySingleton`/webview, forces XPC/URL relay; also requires intent-definition files and per-user shortcut setup |
| Plain `URLSession` REST client | Google API Objective-C client library | Only if future features need OAuth or complex endpoint coverage; for `search.list` the library adds binary weight and review surface for zero gain |
| Native UIKit results overlay | Rendering results inside the webview | Never — destroys single-cached-video playback state, adds page loads per interaction, depends on the private text-simulation path being severed |
| On-device speech only | Server-based `SFSpeechRecognizer` | Only as last-resort fallback when `supportsOnDeviceRecognition` is false on a device; server model has ~1-minute segment limit, needs network, adds privacy-label disclosure |
| Keep remaining AutoHook swizzling (AutoResize, HideScrollBar) | Full template-based CarPlay rebuild | Template rebuild is explicitly out of scope per user decision; each surviving hook is a documented 2.5.1 rejection candidate with a kill-switch |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| MediaRemote framework (`MRMediaRemoteGetNowPlayingInfo`, `kMRMediaRemoteNowPlayingInfo*` keys, `_MRNowPlayingClientProtobuf` decode via `Dynamic` package) | Private framework; string markers detected by automated binary scans; now-playing takeover feature is removed this milestone | Feature deletion — no public API reads other apps' now-playing info (`MPNowPlayingInfoCenter` is write-only for own app) |
| BackBoardServices brightness symbols (`BKSDisplayBrightnessGetCurrent/Set`, `BKSDisplayBrightnessSetAutoBrightnessEnabled`) + SpringBoard CFPreferences reads | Private symbols + container-external reads (guideline 2.5.2); `dlsym` NULL + `unsafeBitCast` force-cast is a crash, not an error | Feature deletion — lock-screen dimming goes; the screen-off warning label survives (public notify path) |
| `exit(0)` settings flow | Apple documentation: "Do not use this function in shipping applications"; known review flag | In-place WKWebView configuration recreation |
| API key committed to source/plist | YouTube policy III.D.1.c explicitly prohibits embedding credentials in open-source projects (this repo is a public fork); `strings IPA` extracts it in seconds | Build-time xcconfig injection outside the repo + bundle-ID/API restrictions in Google Cloud Console + remote-config rotation path |
| `search.list` as unlimited search | 100 calls/day is the **entire TestFlight audience combined**; each results page costs a full call from that bucket; quota extension requires an API Compliance Audit this app's ad-block scripts would fail (III.I.5/6) | Budgeted search + last-query cache + 403 fallback to existing webview search path |
| Old quota folklore ("10k units/day, search costs 100 units") | Docs changed 2026-06: dedicated 100-calls/day `search.list` bucket; PROJECT.md's original quota note was corrected from this research | Current docs: developers.google.com/youtube/v3/determine_quota_cost |

## Stack Patterns by Variant

**If CarPlay entitlement is still pending when search phases run:**
- Develop search/speech/coordinator behind protocols with a phone-side mock renderer
- Because the CarPlay scene won't connect at all under standard signing without the entitlement — simulator included

**If `supportsOnDeviceRecognition` is unavailable on a target device:**
- Hide the mic button; degrade to on-screen search/URL entry
- Never silently fall back to server recognition; never prompt from the CarPlay scene

**If quota 403 hits:**
- Single retry with backoff, then permanent session fallback to webview search
- Do not hammer — every request, even invalid, costs a unit from the bucket

## Version Compatibility

| Component | Compatible With | Notes |
|-----------|-----------------|-------|
| AppIntents App Shortcuts | iOS 16.0+ | The deployment-target raise (14.0 → 16 minimum) is a prerequisite; iOS 17/18 optional preference |
| `requiresOnDeviceRecognition` | iOS 13+ API, on-device availability locale/device-gated | Availability check (`supportsOnDeviceRecognition`) required; degrade by hiding mic, not by crashing |
| Remaining AutoHook swizzling | Untested above iOS 15.4.1 | `AutoHookImplementor` type-encoding matching may silently skip on modern SDKs — treat the target raise as a behavioral re-validation phase, add a hook-verification debug screen |
| Existing WKWebView scripts (AdBlocker, SponsorBlock, AgeRestrictBypass, CustomLayout) | YouTube DOM dependent | Re-verify injection after deployment raise; WebKit version changes affect injection points and DOM assumptions |

## Sources

- developers.google.com/youtube/v3/determine_quota_cost + /getting-started (2026-06-01) — quota model — HIGH (verified by Architecture research)
- developer.apple.com/documentation/appintents/* (iOS 16.0+ availability) — HIGH (verified by Architecture research)
- developer.apple.com/documentation/speech — on-device recognition, purpose strings — HIGH
- App Review Guidelines (2.5.1, 2.5.2, 4.2, 5.2.3) — HIGH (verified by Pitfalls research)
- CarPlay Developer Guide, June 2026 — entitlement process, provisioning, categories — HIGH
- YouTube API Services Developer Policies (2026-06-24) III.D.1.c, III.I.5/6, III.F.2 — HIGH (verified by Pitfalls research)
- Google API key best practices (support.google.com/googleapi/answer/6310037) — HIGH

---
*Stack research for: CarTube App Store + voice search milestone*
*Researched: 2026-08-17*
