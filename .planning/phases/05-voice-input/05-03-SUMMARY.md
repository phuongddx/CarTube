---
phase: 05-voice-input
plan: 03
subsystem: voice-input
tags: [appintents, siri, app-shortcuts, appshortcutsprovider, appintent, funnel]

requires:
  - phase: 05-voice-input
    provides: "05-01's SearchCoordinator-facing funnel contract (SearchCoordinator.shared.search) and 05-02's VoiceSearchAvailability/VoiceSearchSetup onboarding — this plan's intent calls the funnel directly and needs neither Speech file"
provides:
  - "SearchCarTubeIntent — AppIntent with normalize(_:)/resolve(_:search:) helpers, @MainActor perform() routing a trimmed, non-empty query into SearchCoordinator.shared.search, honest 'nothing to search for' dialog on empty/whitespace"
  - "CarTubeShortcuts — AppShortcutsProvider with a single build-legal phrase ('Search YouTube in \\(.applicationName)'); requestValueDialog captures the query as a Siri follow-up question"
  - "SearchIntentTests.swift — normalize/resolve/perform funnel-spy proof using the same MockURLProtocol fixture convention as SearchCoordinatorTests"
  - "Phase-gate record: full 87/87 suite green, real BUILD SUCCEEDED through AppIntentsMetadataExtractor, and a live phone-simulator pass confirming the onboarding sheet, ContentView row, and Debug mic-preview gate all render correctly"
affects: [06-testflight-submission-package]

actuals:
  tokens: 1600
  tasks: 3
  commits: 2

tech-stack:
  added: []
  patterns:
    - "SearchCarTubeIntent.resolve(_:search:) factors perform()'s guard+dispatch body behind an injected closure so the funnel-routing behavior is unit-testable via a plain spy closure without ever touching SearchCoordinator.shared over live network — perform() itself still calls Self.resolve(query) { SearchCoordinator.shared.search($0) }, so production behavior is unchanged"

key-files:
  created:
    - CarTube/Search/SearchCarTubeIntent.swift
    - CarTube/Search/CarTubeShortcuts.swift
    - CarTubeTests/SearchIntentTests.swift
  modified:
    - CarTube.xcodeproj/project.pbxproj

key-decisions:
  - "The plan's two-phrase design ('Search YouTube for \\(\\.$query) in \\(.applicationName)' + a parameterless fallback) fails real xcodebuild ExtractAppIntentsMetadata on this Xcode 26.3 / iOS 26.2 SDK toolchain with 'Invalid parameter type. AppEntity and AppEnum are the only allowed types for query' — confirmed against Apple Developer Forum reports of the identical error (thread 770037). Open-ended String parameters cannot be embedded in an AppShortcut phrase at all; only AppEntity/AppEnum can. This disproves research's Assumption A1 ('16.4 added String phrase-parameter support' — logged MEDIUM confidence, community-held belief) as a hard build-time constraint, not merely a runtime uncertainty."
  - "Fix: ship only the parameterless phrase 'Search YouTube in \\(.applicationName)'. This is exactly the fallback path 05-RESEARCH.md Pattern 2 / Open Question 1 already designed for the scenario where runtime query capture fails — 'Siri asks, driver answers — no code change needed.' VOX-03's zero-setup goal is fully preserved: Siri invokes the shortcut hands-free, requestValueDialog asks 'What do you want to search for?', the driver answers, and perform() routes the answer through the identical SearchCoordinator funnel. The only change from the plan's intent is a two-turn Siri interaction instead of a one-turn one."
  - "SearchCarTubeIntent.resolve(_:search:) is an additional helper beyond the plan's named normalize(_:) — needed so the funnel-routing tests could drive a genuine closure spy instead of touching the real SearchCoordinator.shared (which would issue live network calls for any non-empty query in a unit test). perform() still calls Self.resolve(query) { SearchCoordinator.shared.search($0) } verbatim, so this is purely a testability seam, not a behavior change."

patterns-established:
  - "AppIntent perform() bodies that must route through a production singleton (SearchCoordinator.shared) factor their guard+dispatch logic behind a static helper taking an injected closure, keeping perform() itself a one-line call while making the logic spy-testable."

requirements-completed: [VOX-03, VOX-01]

coverage:
  - id: D1
    description: "Siri App Shortcut phrase ('Search YouTube in CarTube') resolves through the App Shortcut into an in-process perform() that routes the query through SearchCoordinator.shared.search — the identical funnel typed and voice input use"
    requirement: "VOX-03"
    verification:
      - kind: unit
        ref: "CarTubeTests/SearchIntentTests.swift#testValidQueryDrivesCoordinatorSpyThroughLoadingThenResults"
        status: pass
      - kind: other
        ref: "xcodebuild build (real ExtractAppIntentsMetadata pass) — BUILD SUCCEEDED"
        status: pass
    human_judgment: true
    rationale: "Live Siri phrase capture and the resulting requestValueDialog conversation are device-only (no Siri on the simulator) — this is 05-VALIDATION.md's Manual-Only row A1, recorded as open against the Phase 1 CarPlay-entitlement blocker, not skipped."
  - id: D2
    description: "Empty or whitespace-only query is rejected before any presentation — no search issued, no API call spent, the intent returns an honest 'nothing to search for' dialog"
    requirement: "VOX-01"
    verification:
      - kind: unit
        ref: "CarTubeTests/SearchIntentTests.swift#testEmptyAndWhitespaceQueryIssuesNoSearchCall"
        status: pass
      - kind: unit
        ref: "CarTubeTests/SearchIntentTests.swift#testEmptyQueryIntentPerformCompletesWithoutTouchingSharedFunnel"
        status: pass
    human_judgment: false
  - id: D3
    description: "No Intents extension target exists — perform() runs in-process; CarPlaySingleton gains zero new methods across this plan"
    requirement: "VOX-03"
    verification:
      - kind: other
        ref: "negative grep: no INIntent/IntentsExtension under CarTube/Search/; git diff -- CarTube/CarPlay/CarPlaySingleton.swift is empty across both task commits"
        status: pass
    human_judgment: false
  - id: D4
    description: "The build-time phrase-validation gate — the actual xcodebuild AppIntentsMetadataExtractor pass IS the automated verify, and it now passes with the corrected single-phrase design"
    requirement: "VOX-03"
    verification:
      - kind: other
        ref: "xcodebuild -project CarTube.xcodeproj -scheme CarTube build — BUILD SUCCEEDED"
        status: pass
    human_judgment: false
  - id: D5
    description: "Phase gate: full CarTubeTests suite green, and every phone-simulator-walkable voice-input state (onboarding sheet auto-present with exact UI-SPEC copy, persistent 'Voice Search' row, Debug mic-preview availability gate) observed live"
    requirement: "VOX-01"
    verification:
      - kind: unit
        ref: "xcodebuild test (full CarTube scheme) — 87/87 tests passing"
        status: pass
      - kind: automated_ui
        ref: "Live argent simulator pass on iPhone Air (iOS 26.5): fresh-launch VoiceSearchSetup sheet auto-presented with the exact explainer/CTA copy, ContentView 'Voice Search' row present, Debug > Voice Search Preview correctly showed the needsOnboarding gate copy (mic button withheld) — screenshots captured this session"
        status: pass
    human_judgment: true
    rationale: "The CarPlay-scene visual pass (mic button pulse/pill, hold-to-talk, live listening-state visibility — 05-VALIDATION.md row 2.5.14) and webview-audio-survival-during-recording (row A2) both require the CarPlay entitlement's still-pending Xcode-signing/provisioning steps (STATE.md Phase 1 blocker) or a real head unit — neither available this session. Recorded as open against that dated blocker, not skipped, matching 05-01/05-02's precedent."

duration: 35min
completed: 2026-08-19
status: complete
---

# Phase 05 Plan 03: Siri Voice Search — Zero-Setup App Shortcut Summary

**SearchCarTubeIntent + CarTubeShortcuts ship a build-legal, zero-setup Siri App Shortcut that routes into the identical SearchCoordinator funnel as typed and push-to-talk input — after discovering and fixing a real Xcode 26.3 build-time constraint the plan's own two-phrase design could not survive.**

## Performance

- **Duration:** 35 min
- **Completed:** 2026-08-19
- **Tasks:** 3 (2 auto + 1 checkpoint, auto-approved)
- **Files modified:** 4 (3 created, 1 modified)

## Accomplishments

- `SearchCarTubeIntent` ships a thin, unit-proven funnel head: `normalize(_:)` trims whitespace/newlines, `resolve(_:search:)` guards the normalized query and returns an honest dialog for both the empty and non-empty branches, and `@MainActor perform()` calls `Self.resolve(query) { SearchCoordinator.shared.search($0) }` — identical production behavior to the plan's Pattern 2, factored for testability.
- Discovered a real build-time failure the plan and its research (05-RESEARCH.md Assumption A1) did not anticipate: Xcode 26.3's `appintentsmetadataprocessor` rejects any phrase-embedded parameter whose type isn't `AppEntity`/`AppEnum` — `"Invalid parameter type. AppEntity and AppEnum are the only allowed types for query"` — confirmed against an identical Apple Developer Forum report. The plan's parameterized phrase (`"Search YouTube for \(\.$query) in \(.applicationName)"`) cannot build on this toolchain; open-ended `String` phrase parameters are not supported by App Shortcuts at all.
- Fixed by shipping only the parameterless phrase `"Search YouTube in \(.applicationName)"` — exactly the fallback path 05-RESEARCH.md Pattern 2 already designed for this scenario. VOX-03's zero-setup goal survives fully intact: "Hey Siri, search YouTube" invokes the shortcut hands-free, `requestValueDialog` asks "What do you want to search for?", the driver answers, and `perform()` routes the answer through the same funnel — a two-turn conversation instead of one-turn, with zero code change to the funnel itself.
- `SearchIntentTests.swift` proves normalize/resolve/perform behavior with 5 tests, including a funnel-spy test that drives a real `SearchCoordinator` instance (MockURLProtocol fixtures, same convention as `SearchCoordinatorTests`) through `[loading, results]` using the intent's own normalized output — proving the intent enters the identical funnel typed search uses.
- Phase-gate checkpoint: full `CarTubeTests` suite is 87/87 green (82 carried from 05-01/05-02 + 5 new), the real `xcodebuild build` passes `ExtractAppIntentsMetadata`, and a live phone-simulator pass (via Argent) confirmed the fresh-install `VoiceSearchSetup` onboarding sheet auto-presents with the exact UI-SPEC copy, the persistent "Voice Search" row exists in `ContentView`, and `Debug > Voice Search Preview` correctly withholds the mic button while showing the "needs onboarding" gate copy — all consistent with `VoiceSearchAvailability.evaluate`.

## Task Commits

Each task was committed atomically:

1. **Task 1: SearchCarTubeIntent — parameter resolution + funnel routing** - `726af14` (feat)
2. **Task 2: CarTubeShortcuts provider — corrected single-phrase design after a real build-time discovery** - `d97fc32` (feat)
3. **Task 3: Phase-gate checkpoint** - auto-approved (gate="blocking", non-human-verify auto-mode per run instructions); no additional commit beyond this SUMMARY's metadata commit

## Files Created/Modified

- `CarTube/Search/SearchCarTubeIntent.swift` - `AppIntent` with `@Parameter(title: "Query", requestValueDialog: "What do you want to search for?") var query: String`, `normalize(_:)`, `resolve(_:search:)`, `@MainActor perform()`
- `CarTube/Search/CarTubeShortcuts.swift` - `AppShortcutsProvider` with one `AppShortcut` over `SearchCarTubeIntent`: single parameterless phrase, `shortTitle` "Search YouTube", `systemImageName` "magnifyingglass"
- `CarTubeTests/SearchIntentTests.swift` - 5 tests: normalize trims, resolve routes into a spy, empty/whitespace issues zero funnel invocations (both via direct `resolve()` spy and via the real `.shared`-backed `perform()`, which is network-safe because the guard fires before any call), a valid query drives a spy `SearchCoordinator` through `[loading, results]`
- `CarTube.xcodeproj/project.pbxproj` - all three new files wired into their targets (`CarTube`/`CarTubeTests`) via the `xcodeproj` gem, in two separate wiring passes (one per task, so the pbxproj diff stays attributable per commit); restored `dstSubfolder = PlugIns` dropped by the gem's `project.save` (same recurring quirk documented since Phase 2)

## Decisions Made

- The plan's two-phrase Siri design is build-infeasible on this SDK — fixed to a single parameterless phrase; see key-decisions in frontmatter for the full Apple-forum-corroborated root cause and why the fix fully preserves VOX-03.
- Added `SearchCarTubeIntent.resolve(_:search:)` beyond the plan's named `normalize(_:)` helper so funnel-routing tests could drive a genuine closure spy without touching `SearchCoordinator.shared` over live network — `perform()`'s production call path is unchanged.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Task 2's plan-specified phrase pair fails real Xcode build-time metadata validation**
- **Found during:** Task 2, first `xcodebuild build` run
- **Issue:** `"Search YouTube for \(\.$query) in \(.applicationName)"` — an open-ended `String` `@Parameter` embedded in a phrase — is rejected by `appintentsmetadataprocessor` on Xcode 26.3: `"Invalid parameter type. AppEntity and AppEnum are the only allowed types for query"`. This is a genuine SDK/toolchain constraint, not a project misconfiguration — corroborated by an identical error reported on Apple Developer Forums thread 770037. Research's own Assumption A1 had flagged the underlying "String phrase params work" claim as an unverified, MEDIUM-confidence community belief; this is now a confirmed, hard build-time fact.
- **Fix:** Removed the parameterized phrase; shipped only `"Search YouTube in \(.applicationName)"`. The intent's existing `requestValueDialog` ("What do you want to search for?") already covers query capture as a Siri follow-up — exactly the contingency research designed for. No funnel or intent-logic change was needed.
- **Files modified:** `CarTube/Search/CarTubeShortcuts.swift`
- **Verification:** `xcodebuild build` → `BUILD SUCCEEDED` (was previously a hard failure at the `ExtractAppIntentsMetadata` build phase); re-ran all Task 2 grep gates adjusted for the one-phrase design (`applicationName` present once, `AppShortcut(` exactly once, `magnifyingglass`/`Search YouTube` present, zero `CarPlaySingleton.swift` diff) — all pass
- **Committed in:** `d97fc32` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 Rule-1 bug — a plan-specified design that does not build on the real toolchain, corrected to the functionally-equivalent fallback the plan's own research had already designed for this exact contingency)
**Impact on plan:** Necessary for correctness — the plan as literally written cannot produce a working app. The fix preserves 100% of VOX-03's zero-setup requirement; the only observable difference is a two-turn Siri conversation instead of a one-turn one when the driver doesn't include a full sentence-final query the (now nonexistent) parameterized phrase would have captured anyway. No scope creep.

## Issues Encountered

- Same recurring `xcodeproj` gem quirk documented since Phase 2: each `project.save` call dropped `dstSubfolder = PlugIns` from the `Embed Foundation Extensions` build phase. Restored by hand before each build/test run, verified via `grep -n dstSubfolder` before every verification pass.
- No CarPlay entitlement/simulator scene available in this environment (same standing blocker as Phases 3–5; STATE.md Phase 1 blocker's remaining steps are human/portal/Xcode-UI actions). The on-CarPlay visual pass and live Siri phrase capture could not be executed here — recorded as open against that blocker per the checkpoint's own instructions, not skipped. A phone-simulator pass (onboarding sheet, ContentView row, Debug mic-preview gate) was completed live via Argent as the available substitute evidence.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- VOX-03 complete: the zero-setup Siri App Shortcut (`"Search YouTube in CarTube"`) is registered, build-legal, and routes in-process into the exact `SearchCoordinator.shared.search` funnel typed and push-to-talk input use. `requestValueDialog` makes query capture robust regardless of what Siri does with the phrase at runtime.
- VOX-01 closed out for this plan's slice: empty/whitespace queries are rejected before any cost is spent; no Intents extension exists; `CarPlaySingleton` remains at its Phase 4 cap (3 passthroughs, zero new this plan).
- Phase 05 (voice-input) is complete: all three plans (05-01 push-to-talk, 05-02 phone onboarding, 05-03 Siri) shipped. 87/87 tests green across the phase.
- Three Manual-Only device rows remain open, tracked against the Phase 1 CarPlay-entitlement dated blocker (unchanged from 05-01/05-02, not worsened by this plan): (A1) Siri runtime phrase capture / requestValueDialog conversation on a real device, (A2) webview audio survival during recording on a real head unit, (2.5.14) live listening-state visibility on a real car screen. All three require either a physical device with Siri or the CarPlay entitlement's remaining Xcode-signing/provisioning steps (developer.apple.com App ID capability, provisioning profile creation/import, Xcode Signing & Capabilities toggle) — none of which are executable by an agent in this environment.
- Ready for Phase 6 (TestFlight Submission Package), which re-verifies CarPlay-dependent behavior once the entitlement's remaining manual steps land.

## Self-Check: PASSED

- `[ -f CarTube/Search/SearchCarTubeIntent.swift ]`, `[ -f CarTube/Search/CarTubeShortcuts.swift ]`, `[ -f CarTubeTests/SearchIntentTests.swift ]` — all confirmed present on disk
- `git log --oneline -2` shows `d97fc32` and `726af14` in sequence on this branch
- All task-level `<acceptance_criteria>` re-verified: `SearchIntentTests` 5/5 green; `requestValueDialog`/dialog text/`SearchCoordinator.shared.search`/`@MainActor` all present; exactly one `import` in `SearchCarTubeIntent.swift`; no `INIntent`/`IntentsExtension` under `CarTube/Search/`; zero `CarPlaySingleton.swift` diff across both task commits; `CarTubeShortcuts.swift` greps (`applicationName`, `Search YouTube`, `magnifyingglass`, exactly one `AppShortcut(`, exactly one `.applicationName` occurrence matching the corrected single-phrase design) all pass; real `BUILD SUCCEEDED` through `ExtractAppIntentsMetadata`
- Plan-level `<verification>` re-run: full `xcodebuild test` on the `CarTube` scheme — **87/87 tests passing**, `BUILD SUCCEEDED`

---
*Phase: 05-voice-input*
*Completed: 2026-08-19*
