# Requirements: CarTube

**Defined:** 2026-08-17
**Core Value:** A driver can open any YouTube video on their car screen — by voice, search, or share — with ads and sponsors skipped automatically.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### App Store Infrastructure

- [ ] **INFRA-01**: CarPlay entitlement application submitted under the audio category on day 1, with documented rationale and dated record; new provisioning profile wired when granted
- [x] **INFRA-02**: All TrollStore artifacts removed (private entitlement keys, `ipabuild.sh`, ldid pipeline) and the app builds with standard App Store code signing
- [x] **INFRA-03**: Riskiest private APIs removed with callers mapped first — MediaRemote now-playing interception (feature removed), BackBoardServices brightness/lock-screen dimming (feature removed), SpringBoard reads — screen-off warning label survives
- [x] **INFRA-04**: Deployment target raised to iOS 16.0 with hook behavioral re-validation (hook-verification debug screen) and Settings toggles updated (no dead toggles for removed features)
- [x] **INFRA-05**: `strings` binary scan gate runs on app + share-extension binaries in CI, failing the build on private-API markers
- [x] **INFRA-06**: Settings no longer terminates via `exit(0)` — webview configuration is recreated in place

### Search Core

- [x] **SRCH-01**: User can search YouTube from the car via `YouTubeSearchService` (Data API v3, build-time-injected key, never committed to the repo)
- [x] **SRCH-02**: Search respects the 100 calls/day shared budget — explicit-submit only, one page of results, last-query cache
- [x] **SRCH-03**: On quota/key failure (403), search degrades automatically to the existing webview search path — never a dead screen
- [x] **SRCH-04**: XCTest target exists with fixture-JSON tests for the search client and shared URL parsing

### CarPlay Search Surface

- [x] **UI-01**: Driver sees search results as a native tappable list on the CarPlay screen (≤8 rows, ≥60pt rows, thumbnail + title + channel + duration; one tap plays; playback continues beneath without webview resize)
- [x] **UI-02**: Siri, mic, and fallback inputs all funnel through one `SearchCoordinator` with ≤3 new `CarPlaySingleton` passthrough methods
- [x] **UI-03**: Results list shows "Results from YouTube" attribution

### Voice Input

- [ ] **VOX-01**: Driver can push-to-talk: on-device speech recognition, mic button visible only when authorized, visible listening state, auto-stop on silence
- [ ] **VOX-02**: User completes mic + speech permission onboarding on the phone before CarPlay use (both `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` present)
- [ ] **VOX-03**: User can say "Search YouTube for X" via Siri App Shortcut (zero setup, in-process)

### Submission Package

- [ ] **SHIP-01**: App Review notes deliverable describes the CarPlay webview mechanism honestly under the audio category; App Store metadata contains no ad-block/SponsorBlock marketing
- [ ] **SHIP-02**: Fallback ladder documented (parked-gate variant → audio-UI variant as fast-follows) if webview video is rejected
- [ ] **SHIP-03**: Existing hardening items fixed: GitHub update-check response validated before display; pasteboard read on activation replaced with explicit paste interaction

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Search Enhancements

- **SRCH-05**: Last-query "play it again" affordance beyond the cache
- **SRCH-06**: Quota extension request tooling

### Stability

- **STAB-01**: Hook kill-switch dashboard for field-disabled AutoHook behaviors

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Official CarPlay template rebuild (audio-first UI) | User chose to keep webview video and accept rejection risk |
| Parked-video mode under Apple's video category | Requires AirPlay video support; parked-only contradicts Core Value |
| Queued playback / playlists | Single-cached-video model retained |
| Telemetry/crash reporting | Defer until App Store survival proven |
| Now-playing takeover | No public API exists; removed with MediaRemote severance |
| Lock-screen dimming | No public API for external-display brightness; removed with severance |
| Dual distribution (App Store + sideload builds) | Single App Store target this milestone |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| INFRA-01 | Phase 1 | Pending |
| INFRA-02 | Phase 2 | Complete |
| INFRA-03 | Phase 2 | Complete |
| INFRA-04 | Phase 2 | Complete |
| INFRA-05 | Phase 2 | Complete |
| INFRA-06 | Phase 2 | Complete |
| SRCH-01 | Phase 3 | Complete |
| SRCH-02 | Phase 3 | Complete |
| SRCH-03 | Phase 3 | Complete |
| SRCH-04 | Phase 3 | Complete |
| UI-01 | Phase 4 | Complete |
| UI-02 | Phase 4 | Complete |
| UI-03 | Phase 4 | Complete |
| VOX-01 | Phase 5 | Pending |
| VOX-02 | Phase 5 | Pending |
| VOX-03 | Phase 5 | Pending |
| SHIP-01 | Phase 6 | Pending |
| SHIP-02 | Phase 6 | Pending |
| SHIP-03 | Phase 6 | Pending |

**Coverage:**

- v1 requirements: 19 total
- Mapped to phases: 19
- Unmapped: 0 ✓

---
*Requirements defined: 2026-08-17*
*Last updated: 2026-08-18 after roadmap creation (traceability populated)*
