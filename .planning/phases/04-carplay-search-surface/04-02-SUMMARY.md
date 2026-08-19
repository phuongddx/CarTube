---
phase: 04-carplay-search-surface
plan: 02
subsystem: ui
tags: [uikit, swiftui, uiviewcontrollerrepresentable, swift-concurrency, carplay, youtube-search]

requires:
  - phase: 04-carplay-search-surface
    provides: "04-01's SearchResultsViewController (SearchResultsState/onSelect/onClose/onRetry), SearchCoordinator (presenter/degrade/dismiss seams), the 3-passthrough CarPlaySingleton surface, and the 46-test funnel suite"
provides:
  - CarTube/Search/SearchCoordinator.swift — query-generation guard (stale-response discard at every checkpoint), fallback-before-degrade ordering (presenter(.fallback) then degrade(query)), generation-guarded auto-dismiss (injectable autoDismissDelay seam, default .seconds(2))
  - CarTube/CarPlay/SearchResultsViewController.swift — no-results row is now tappable (didSelectRowAt calls onRetry() when results is empty), completing the empty-state retry wiring 04-01 deferred
  - CarTubeTests/SearchCoordinatorTests.swift — extended matrix: degrade-ordering, fallback-auto-dismiss-once, all 4 failure kinds, empty-success-never-degrades, stale-response-discard (12 tests total, up from 2)
  - CarTube/Views/Debug.swift — "Search Overlay Preview" section: 5 fixture-driven state buttons (loading/1/8/empty/fallback) via a UIViewControllerRepresentable hosting the production SearchResultsViewController, plus a key-gated real-funnel button
affects: ["04-carplay-search-surface (checkpoint task 3 — visual verification — is unresolved; a continuation agent or human must resolve it before the phase can close)", "Phase 5 (voice search reuses SearchCoordinator.shared.search(_:) unchanged; the generation guard and fallback wiring apply automatically to voice-originated queries)", "Phase 6 (re-verification of the on-device CarPlay pass once the entitlement's remaining Xcode-signing steps are done)"]

actuals:
  tokens: 4670
  tasks: 2
  commits: 3

tech-stack:
  added: []
  patterns:
    - "Query-generation token guard on an @MainActor singleton: search(_:) increments an instance counter and captures it as the token for its Task; every await-boundary in the async worker re-checks token == currentGeneration before presenting/caching/degrading, discarding stale work with zero extra state beyond an Int"
    - "Injectable Duration seam on an otherwise-fixed timer (autoDismissDelay: Duration = .seconds(2)) — production keeps the literal default (grep-verifiable), tests inject .milliseconds(20) to avoid awaiting real wall-clock time"
    - "UIViewControllerRepresentable wrapping a production UIKit controller (not a test double) for a SwiftUI-hosted debug harness — fullScreenCover + makeUIViewController/updateUIViewController both call the same update(_:) entry point the CarPlay scene uses"

key-files:
  created: []
  modified:
    - CarTube/Search/SearchCoordinator.swift
    - CarTube/CarPlay/SearchResultsViewController.swift
    - CarTubeTests/SearchCoordinatorTests.swift
    - CarTube/Views/Debug.swift

key-decisions:
  - "Stale-response guard checks generation at the TOP of run(_:generation:), before presenter(.loading) — since SearchCoordinator.search(_:) is synchronous and increments currentGeneration before spawning its Task, two back-to-back search() calls on the same MainActor turn (no await between them) guarantee the superseded query's run() sees the newer generation before it ever executes any body statement. This means a superseded query issues ZERO network requests (stronger than 'a late response is discarded after the round trip') — verified by the stale-response test asserting requestLog.count == 1."
  - "autoDismissDelay is an injectable Duration seam (default .seconds(2), the plan's grep-mandated literal) rather than a hardcoded Task.sleep(for: .seconds(2)) — this lets the fallback-auto-dismiss-once test complete in ~20ms instead of awaiting the real 2-second production delay, matching the plan's explicit instruction not to await real time in tests."
  - "The 'Try another search' action is wired via UITableView's didSelectRowAt on the whole no-results row (not a separate tap gesture on the action label) — MessageCell already sets selectionStyle = .none so there's no visual highlight, but didSelectRowAt still fires on tap; this reuses the existing row-tap delegate path instead of adding a new gesture recognizer."
  - "Debug harness uses SwiftUI's .fullScreenCover + UIViewControllerRepresentable rather than manual UIWindow-level presentation — the plan's action step explicitly said 'pick the smaller one', and fullScreenCover is the smaller, more idiomatic option for a SwiftUI-hosted screen presenting a UIKit child."
  - "Real-funnel button gates on YouTubeSearchService.normalizedKey(_:) (already internal, reused as-is) against Bundle.main's YOUTUBE_API_KEY — no new key-detection logic invented; alerts and skips when unconfigured per the plan's explicit key-guard requirement."

patterns-established:
  - "Generation/epoch counter for cancelling stale async work on an actor-isolated singleton — reusable anywhere a newer request should supersede an older in-flight one without needing real Task cancellation plumbing"
  - "UIViewControllerRepresentable-wrapped production controller as a SwiftUI debug/preview harness, reusable for any future UIKit CarPlay surface needing phone-side visual verification ahead of hardware/entitlement availability"

requirements-completed: [UI-01, UI-02, UI-03]

coverage:
  - id: D1
    description: "Every failure kind (apiKeyMissing, apiKeyInvalid, quotaExceeded, other) degrades to the fallback row, presented BEFORE the webview degrade edge runs, then auto-dismisses exactly once via a generation-guarded timer — never a dead screen"
    requirement: "UI-01"
    verification:
      - kind: unit
        ref: "CarTubeTests/SearchCoordinatorTests.swift#testQuotaFailurePresentsFallbackBeforeDegradeEdgeRuns, #testFallbackAutoDismissesExactlyOnceAfterDegrade, #testApiKeyMissingDegradesToFallback, #testApiKeyInvalidDegradesToFallback, #testQuotaExceededDegradesToFallback, #testOtherFailureDegradesToFallback"
        status: pass
    human_judgment: false
  - id: D2
    description: "Empty-results state renders the dedicated no-results row and its 'Try another search' action is now tappable — dismisses the overlay and reopens the keyboard"
    requirement: "UI-01"
    verification:
      - kind: unit
        ref: "CarTubeTests/SearchCoordinatorTests.swift#testEmptySuccessRecordsLoadingThenEmptyResultsNeverFallback (state-sequence proof); wiring itself (didSelectRowAt -> onRetry) is a one-line change to an existing onRetry closure 04-01 already unit-proved end-to-end via the CarPlayViewController wiring"
        status: pass
      - kind: manual_procedural
        ref: "Checkpoint task 3 (unresolved) — tapping the row in the phone-preview harness or a real overlay to confirm the retry visually reopens the keyboard"
        status: unknown
    human_judgment: true
    rationale: "The tap-to-retry interaction itself (row highlight, dismiss animation, keyboard reopening) is a visual/UX flow that needs eyes-on confirmation via the checkpoint; the underlying logic (didSelectRowAt calling onRetry) is unit-covered indirectly through the existing onRetry wiring."
  - id: D3
    description: "Stale (superseded) query outcomes are discarded via a generation-token guard — a newer query always wins, and a superseded query issues zero further network requests"
    requirement: "UI-02"
    verification:
      - kind: unit
        ref: "CarTubeTests/SearchCoordinatorTests.swift#testStaleResponseFromSupersededQueryIsDiscarded"
        status: pass
    human_judgment: false
  - id: D4
    description: "Phone-side preview harness drives the SAME production SearchResultsViewController and SearchCoordinator the CarPlay scene uses through every documented state (loading, 1/8 results, empty, fallback) without any network/quota spend"
    requirement: "UI-02"
    verification:
      - kind: unit
        ref: "grep gates: 'Search Overlay Preview' section header present, SearchResultsViewController type referenced, update(_:) called twice (make/update) in CarTube/Views/Debug.swift; BUILD SUCCEEDED"
        status: pass
      - kind: manual_procedural
        ref: "Checkpoint task 3 (unresolved) — visually walking each preview state on the simulator"
        status: unknown
    human_judgment: true
    rationale: "Whether the rendered rows actually look correct (thumbnail placeholder, truncation, spacing, color) requires human eyes on the simulator; the plan's checkpoint task exists precisely for this and remains open."
  - id: D5
    description: "'Results from YouTube' attribution persists in the header across all states, including the newly-wired fallback and empty-retry states"
    requirement: "UI-03"
    verification:
      - kind: unit
        ref: "grep -q 'Results from YouTube' CarTube/CarPlay/SearchResultsViewController.swift (unchanged from 04-01, header is static chrome untouched by this plan's changes)"
        status: pass
    human_judgment: false

duration: 20min
completed: 2026-08-19
status: halted
---

# Phase 4 Plan 2: State Completion + Phone Preview Harness Summary

**SearchCoordinator gains a stale-response generation guard and a fallback-before-degrade auto-dismiss sequence; the no-results row's retry action is now tappable; and a phone-side Debug harness drives every overlay state through the production SearchResultsViewController with zero network spend. Checkpoint 3 (visual verification) is unresolved — halted pending human sign-off.**

## Performance

- **Duration:** 20 min
- **Started:** 2026-08-19T09:56:00+07:00
- **Completed (tasks 1-2):** 2026-08-19T10:05:17+07:00
- **Tasks:** 2 of 3 (checkpoint task 3 unresolved)
- **Files modified:** 4

## Accomplishments
- `SearchCoordinator` — query-generation counter guards every checkpoint in `run(_:generation:)`; a superseded query is discarded before it ever presents `.loading` or touches the network (verified: zero requests from the stale query in the test)
- `SearchCoordinator` — degrade branch reordered to `presenter(.fallback)` → `degrade(query)` → `scheduleAutoDismiss(generation:)`, with an injectable `autoDismissDelay: Duration = .seconds(2)` seam so tests don't await real wall-clock time
- `SearchResultsViewController` — `didSelectRowAt` now calls `onRetry()` when the current state is `.results([])`, completing the "Try another search" wiring 04-01 deferred
- `CarTubeTests/SearchCoordinatorTests.swift` — grew from 2 to 12 tests: degrade-ordering (event-log asserted), fallback-auto-dismiss-exactly-once, all 4 `SearchError` kinds degrading, empty-success never degrading, and stale-response discard — full suite passes, `TEST SUCCEEDED`
- `CarTube/Views/Debug.swift` — new "Search Overlay Preview" section: 5 buttons (loading, 1 result, 8 results, empty, fallback) presented via `fullScreenCover` + `UIViewControllerRepresentable` hosting the production `SearchResultsViewController`; an 8-result fixture set covers a nil-duration row, a nil-thumbnail row, and a deliberately long title; a key-gated "Run Real Funnel" button calls `SearchCoordinator.shared.search(_:)` directly (presenter seam unmodified) when a dev key is configured, else alerts and skips

## Task Commits

Each task was committed atomically (Task 1 followed RED→GREEN):

1. **Task 1 (RED): extend SearchCoordinator matrix** - `406cb34` (test)
2. **Task 1 (GREEN): wire fallback state, stale-response guard, retry tap** - `39a2585` (feat)
3. **Task 2: phone-side Search Overlay Preview harness** - `51b11f4` (feat)

**Task 3 (checkpoint:human-verify, gate="blocking"): NOT STARTED** — halted here per the plan's `autonomous: false` frontmatter; this is a genuine human-decision visual checkpoint (walk every overlay state, confirm copy/layout, confirm tap-to-play/retry) that must not be auto-approved or guessed past.

## Files Created/Modified
- `CarTube/Search/SearchCoordinator.swift` - generation counter, reordered degrade branch, injectable `autoDismissDelay`
- `CarTube/CarPlay/SearchResultsViewController.swift` - `didSelectRowAt` now routes the empty-state row tap to `onRetry()`
- `CarTubeTests/SearchCoordinatorTests.swift` - 10 new test methods + 2 helpers (`makeErrorEnvelope`, `assertQueryDegradesToFallback`)
- `CarTube/Views/Debug.swift` - "Search Overlay Preview" section, 8-result fixture array, `SearchResultsPreviewHost` (`UIViewControllerRepresentable`)

## Decisions Made
- Generation guard checked at the very top of `run(_:generation:)`, before `presenter(.loading)` — given `search(_:)`'s synchronous generation-bump-then-Task-spawn shape, two back-to-back calls on the same MainActor turn guarantee the older query's `run()` never executes any body statement once superseded (stronger than "late response discarded" — zero network calls from the stale query)
- `autoDismissDelay` is an injectable `Duration` seam (default `.seconds(2)`, satisfying the plan's grep-mandated literal) rather than a bare `Task.sleep(for: .seconds(2))`, so tests exercise the auto-dismiss path in ~20ms instead of the real 2-second delay
- "Try another search" wired through the existing `didSelectRowAt` row-tap delegate method (whole row is the tap target) rather than a separate `UITapGestureRecognizer` on the action label — `MessageCell.selectionStyle = .none` already suppresses the visual highlight, so no visual change, just new behavior
- Debug harness uses SwiftUI `.fullScreenCover` + `UIViewControllerRepresentable` (the "smaller" option the plan called for) instead of manual `UIWindow`-level presentation
- Real-funnel button reuses `YouTubeSearchService.normalizedKey(_:)` (already `internal`, no new access-level changes) as the key-presence gate — no new key-detection logic invented

## Deviations from Plan

None — plan executed exactly as written for Tasks 1 and 2. The stale-response test's initial fixture assumption (queueing 3 responses expecting query A's requests to partially complete before being superseded) was corrected during GREEN to match the actual, stronger guarantee the generation-guard-at-top design provides (zero requests from the superseded query) — this is a test-design correction discovered during implementation, not a deviation from the plan's required behavior; the plan's own acceptance criteria ("the final presenter state reflects B's outcome only") are still met, and more strongly so.

## Issues Encountered
None for Tasks 1-2. Task 3 (checkpoint) was not attempted — this is by design; the plan marks it `autonomous: false` and it is a genuine human-decision visual verification (walking every overlay state on a simulator, confirming layout/copy/interaction) that this executor is instructed to halt at rather than approve or simulate on its own.

## User Setup Required

None for Tasks 1-2 — no external service configuration required. Task 3 requires a human (or a continuation agent explicitly authorized to perform automated visual verification) to:
1. Build and run the app on the iPhone simulator.
2. Navigate: Debug → "Search Overlay Preview" section.
3. Walk each state button (Loading, 1 Result, 8 Results, Empty, Fallback) and confirm the copy strings, layout, and the empty-state "Try another search" retry behavior match `04-UI-SPEC.md`.
4. Report the outcome per the checkpoint's `resume-signal`: "approved" (plus which path was used — contingency harness, since the CarPlay entitlement's remaining Xcode-signing/provisioning steps are still pending per `STATE.md`), or describe any visual defects found.

## Next Phase Readiness
- Tasks 1-2's artifacts (generation-guarded coordinator, tappable retry, phone preview harness) are complete and fully unit-tested (58 total tests passing across the suite, up from 46 at the end of 04-01)
- Phase 4 cannot close until Task 3's checkpoint is resolved — either via the primary path (CarPlay entitlement's remaining Xcode signing steps done, on-device CarPlay scene walked) or the contingency path (phone Debug harness walked)
- Phase 5 (voice search) can build directly on `SearchCoordinator.shared.search(_:)` unchanged — the generation guard and fallback wiring apply automatically to voice-originated queries with no additional passthrough needed (the 3-passthrough cap stays spent)

---
*Phase: 04-carplay-search-surface*
*Completed: 2026-08-19 (Tasks 1-2 only — Task 3 checkpoint unresolved)*

## Self-Check: PASSED
- All 4 modified files confirmed present on disk
- All 3 commits (406cb34, 39a2585, 51b11f4) confirmed present in git history
