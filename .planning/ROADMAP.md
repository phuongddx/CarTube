# Roadmap: CarTube

## Overview

CarTube is an existing TrollStore-sideloaded CarPlay YouTube app. This milestone moves it to a standard-signed, TestFlight-ready App Store build and adds driver-safe search (Siri phrase + push-to-talk → glanceable tappable results), while preserving the webview video core. The phases follow the dependency order the research established: external clocks start first (Apple entitlement, Google key), the binary is severed from private APIs before any new code lands on the same files, the search backend is built leaf-first as the project's first tested island, the CarPlay results surface lands next as the shared landing zone, voice input builds on that funnel, and a coherent submission package closes the milestone. Horizontal-layer grouping (infrastructure → services → UI → voice → submission) matches this order naturally.

**Milestone Definition of Done:** TestFlight-ready upload — user owns the actual submission and review outcome.

## Phases

**Phase Numbering:**

- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: External Dependencies & Project Setup** - Start the uncontrolled external clocks (CarPlay entitlement, Google API key) and wire the grant when it lands
- [x] **Phase 2: Severance, Signing & Modernization** - Strip TrollStore/private-API surface, standard signing, iOS 16 target, scan gate (completed 2026-08-18)
- [ ] **Phase 3: Search Core** - YouTube Data API client with quota budget, webview fallback, first test target
- [ ] **Phase 4: CarPlay Search Surface** - Glanceable tappable results overlay + SearchCoordinator funnel
- [ ] **Phase 5: Voice Input** - On-device push-to-talk, phone-first permissions, Siri App Shortcut
- [ ] **Phase 6: TestFlight Submission Package** - Honest review notes/metadata, fallback ladder, hardening, coherent upload

## Phase Details

### Phase 1: External Dependencies & Project Setup

**Goal**: The two timelines outside our control (Apple entitlement review, Google key provisioning) are started on day 1 so no later phase blocks on them, and the entitlement grant is wired the moment it arrives
**Depends on**: Nothing (first phase)
**Requirements**: INFRA-01
**Success Criteria** (what must be TRUE):

  1. CarPlay entitlement application is submitted to Apple under the audio category, with the request rationale documented as a Key Decision and the submission date recorded
  2. A restricted YouTube Data API key exists in a dedicated Google Cloud project (API + bundle-ID restrictions, never committed to the repo) with a build-time delivery mechanism decided, so search work never blocks on Google
  3. If Apple grants the entitlement during this phase, the new provisioning profile is wired into the project and the CarPlay scene connection is verified; if still pending, it is tracked as a dated blocker rather than silently blocking later phases

**Plans**: 3/3 plans executed

Plans:
**Wave 1**

- [x] 01-01-PLAN.md — Build-time secret delivery: xcconfig → $(YOUTUBE_API_KEY) → Info.plist, hygiene gates
- [x] 01-02-PLAN.md — Apple entitlement: runbooks, bundle-ID decision gate, audio-category submission, dated blocker

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 01-03-PLAN.md — Google restricted key provisioning, build injection verification, Key Decisions, phase close-out

### Phase 2: Severance, Signing & Modernization

**Goal**: The binary contains no auto-detectable review violations and installs under standard App Store signing — sever before extend, because the files search must touch are the exact files losing MediaRemote/brightness code
**Depends on**: Phase 1
**Requirements**: INFRA-02, INFRA-03, INFRA-04, INFRA-05, INFRA-06
**Success Criteria** (what must be TRUE):

  1. App and share extension build and run with standard App Store code signing; no TrollStore artifacts remain (private entitlement keys, `ipabuild.sh`, ldid pipeline)
  2. Now-playing takeover and lock-screen dimming are removed while the screen-off warning label survives, with every removed private-API symbol caller-mapped before deletion
  3. Deployment target is iOS 16.0 and existing injected-JS behaviors (ad block, SponsorBlock, age-restriction bypass) are re-validated via a hook-verification debug screen
  4. Settings contains no dead toggles for removed features, and changing settings applies the webview configuration in place instead of terminating the app
  5. A `strings` binary scan gate runs in CI on both binaries and fails the build on private-API markers

**Plans**: 4/4 plans executed

Plans:
**Wave 1**

- [x] 02-01-PLAN.md — Entitlements emptied, ipabuild/ldid pipeline deleted, standard-signing tracer build; Key Decisions encoded, NOTES retired
- [x] 02-02-PLAN.md — TDD strings scan-gate script (removed-symbols markers, survivor exclusions) + CI workflow scanning both binaries

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 02-03-PLAN.md — Caller-first severance of MediaRemote/brightness code, LockScreenDimmingOn contract dead, idle-timer NoSleep, in-place settings apply

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 02-04-PLAN.md — iOS 16 deployment target, Dynamic SPM removal, hook-verification debug screen, on-simulator behavioral checkpoint

**UI hint**: no

### Phase 3: Search Core

**Goal**: A stateless, unit-tested YouTube Data API search client exists as a leaf component — the project's first test target — with quota budgeting and fail-closed degradation to the existing webview search
**Depends on**: Phase 2
**Requirements**: SRCH-01, SRCH-02, SRCH-03, SRCH-04
**Success Criteria** (what must be TRUE):

  1. A search query returns parsed YouTube results (title, channel, duration, thumbnail) via Data API v3 with the key injected at build time and never present in the repo
  2. Search spends quota deliberately: explicit-submit only, one page of results per query, and a last-query cache that avoids repeat calls
  3. On 403/quota/key failure, search degrades automatically to the existing webview search path — the driver is never left without a working search
  4. An XCTest target exists and passes fixture-JSON tests for the search client and shared URL parsing

**Plans**: 3 plans

Plans:
**Wave 1**

- [ ] 03-01-PLAN.md — Test-target tracer: CarTubeTests unit-test target, committed shared scheme with TestAction, parser input-class matrix (SRCH-04)

**Wave 2** *(blocked on Wave 1 completion)*

- [ ] 03-02-PLAN.md — SearchResult model + YouTubeSearchService: typed errors, build-time key gate, two-request duration fill, fixture-JSON tests behind a URLProtocol stub (SRCH-01, SRCH-04)

**Wave 3** *(blocked on Wave 2 completion)*

- [ ] 03-03-PLAN.md — LastQueryCache + SearchFallback fail-closed decision, dev-key runbook + live smoke checkpoint, Key Decisions (SRCH-02, SRCH-03)

**UI hint**: no

### Phase 4: CarPlay Search Surface

**Goal**: Drivers see search results as a native, glanceable, tappable list on the CarPlay screen, layered over the webview without disturbing playback — the landing zone both voice inputs require
**Depends on**: Phase 3
**Requirements**: UI-01, UI-02, UI-03
**Success Criteria** (what must be TRUE):

  1. Driver sees search results as a tappable list on the CarPlay screen — ≤8 rows, ≥60pt rows, thumbnail + title + channel + duration — and one tap plays the video
  2. Playback continues beneath the results list without resizing or navigating the webview until a concrete video is chosen
  3. All search inputs funnel through a single SearchCoordinator (typed input now; voice surfaces land on it in Phase 5), adding ≤3 new passthrough methods to CarPlaySingleton
  4. The results list displays "Results from YouTube" attribution

**Plans**: 2 plans

Plans:
**Wave 1**

- [ ] 04-01-PLAN.md — Tracer: typed keyboard query → SearchCoordinator funnel → native results overlay over the webview → one-tap play; exactly 3 passthroughs; DurationFormatter + attribution header (UI-01, UI-02, UI-03)

**Wave 2** *(blocked on Wave 1 completion)*

- [ ] 04-02-PLAN.md — State completion: fallback row + ≤2s auto-dismiss, empty-state retry, stale-response guard, coordinator test matrix, phone-side preview harness + visual checkpoint (UI-01, UI-02, UI-03)

**UI hint**: yes

### Phase 5: Voice Input

**Goal**: The driver can search hands-free — push-to-talk with on-device recognition as the fallback for non-Siri users, and a zero-setup Siri phrase — both landing on the finished search funnel
**Depends on**: Phase 4
**Requirements**: VOX-01, VOX-02, VOX-03
**Success Criteria** (what must be TRUE):

  1. Driver can push-to-talk from the CarPlay screen: on-device speech recognition, mic button visible only when authorized, a visible listening state, and auto-stop on silence
  2. User completes microphone + speech-recognition permission onboarding on the phone before CarPlay use (both purpose strings present in the first speech commit)
  3. User can say "Search YouTube for X" via a Siri App Shortcut with zero setup, and it produces results on the CarPlay screen
  4. When speech is unavailable or denied, the mic button is hidden and typed/Siri paths remain fully usable — no dead ends

**Plans**: 3 plans

Plans:
**Wave 1**

- [ ] 05-01-PLAN.md — Push-to-talk tracer: purpose strings + construction-gated SpeechRecognizerService + MicButton + funnel landing + availability/error/silence-timer tests + Debug voice preview (VOX-01, VOX-02)

**Wave 2** *(blocked on Wave 1 completion)*

- [ ] 05-02-PLAN.md — Phone onboarding: VoiceSearchSetup Form (explainer/CTA/ready/limited/denied + Open Settings) + first-run auto-present + persistent row (VOX-02)

**Wave 3** *(blocked on Wave 2 completion)*

- [ ] 05-03-PLAN.md — Siri App Shortcut: SearchCarTubeIntent + corrected phrase pair (app-name token + parameterless fallback) + no-dead-ends verification + phase-gate checkpoint (VOX-03, VOX-01)

**UI hint**: yes

### Phase 6: TestFlight Submission Package

**Goal**: The upload is coherent so the webview surface is the only remaining rejection reason — honest review notes and metadata, a documented fallback ladder, and long-standing hardening resolved
**Depends on**: Phase 5
**Requirements**: SHIP-01, SHIP-02, SHIP-03
**Success Criteria** (what must be TRUE):

  1. App Review notes deliverable describes the CarPlay webview mechanism honestly under the audio category, and App Store metadata contains no ad-block/SponsorBlock marketing
  2. The fallback ladder is documented (parked-gate variant → audio-UI variant as fast-follows) so a webview rejection has a pre-decided next move
  3. GitHub update-check responses are validated before display, and the pasteboard read on activation is replaced with an explicit paste interaction
  4. A final scan-clean archive of app + share extension is produced that uploads under standard signing (TestFlight-ready)

**Plans**: 3 plans
**UI hint**: no

Plans:
**Wave 1**

- [ ] 06-01-PLAN.md — Tracer: hardening fixes (typed fork-targeted GitHubRelease update check + PasteButton replacing activation pasteboard read) with MockURLProtocol tests and dual-binary scan proof (SHIP-03)
- [ ] 06-02-PLAN.md — Submission docs: honest App Review notes under audio category with 2.3.1 disclosure, ad-block-free App Store metadata, fallback ladder rungs 0–2 (SHIP-01, SHIP-02)

**Wave 2** *(blocked on Wave 1 completion)*

- [ ] 06-03-PLAN.md — Entitlement-branch checkpoint → standard-signing Release archive → dual-binary scan gate → altool upload with ASC key hygiene + submission notes (SHIP-01, SHIP-03)

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. External Dependencies & Project Setup | 3/3 | In Progress|  |
| 2. Severance, Signing & Modernization | 4/4 | Complete    | 2026-08-18 |
| 3. Search Core | 0/3 | Planning complete | - |
| 4. CarPlay Search Surface | 0/2 | Planning complete | - |
| 5. Voice Input | 0/3 | Planning complete | - |
| 6. TestFlight Submission Package | 0/3 | Planning complete | - |

## Notes

- **Entitlement dependency:** Until Apple grants the CarPlay entitlement, Phases 3–5 develop and verify against phone-side mocks; on-device CarPlay verification happens as soon as the grant lands (wired in Phase 1, re-verified in Phase 6 with the new provisioning profile and automatic signing off).
- **Scan gate is permanent:** The `strings` gate created in Phase 2 runs in every subsequent phase's CI, catching private-API regression before upload.
- **Research flags:** Phase 5 warrants `--research-phase` (Speech framework details are MEDIUM confidence); Phase 1 optionally benefits from a light pass on entitlement request-text positioning. Phases 2–4, 6 are codebase- or guidelines-driven and skip research-phase.
