---
phase: 04-carplay-search-surface
plan: 01
subsystem: ui
tags: [uikit, uitableviewcontroller, mainactor, swift-concurrency, carplay, youtube-search]

requires:
  - phase: 03-search-core
    provides: YouTubeSearchService (async search client), LastQueryCache (actor), SearchFallback.decide (pure degrade decision), SearchResult model, CarTubeTests/MockURLProtocol fixture-stub infrastructure
provides:
  - CarTube/CarPlay/SearchResultsViewController.swift — UITableViewController overlay with SearchResultsState enum (loading/results/fallback), 68pt result rows, Close+attribution header, loading/no-results rows, async-cancelled thumbnails
  - CarTube/Search/SearchCoordinator.swift — @MainActor funnel singleton (static let shared) with injectable service/cache/presenter/degrade/dismiss seams
  - CarTube/Search/DurationFormatter.swift — pure ISO-8601 PT-duration to badge-string formatter
  - CarPlaySingleton — exactly 3 new passthroughs (showSearchResults, dismissSearchResults, submitSearchQuery) — the milestone's 3-passthrough cap is now spent
  - CarPlayViewController — full-frame overlay wiring below screenOffLabel + show/dismiss with zero webview mutation
  - KeyboardView — typed-query buffer + magnifyingglass submit key on all 3 keyboard modes
  - Re-scoped boundary gate — "no CarPlaySingleton under CarTube/Search/" now excludes SearchCoordinator.swift by design
affects: [04-carplay-search-surface (plan 02 builds fallback-row rendering, onRetry wiring, and phone-preview harness on top of this controller/coordinator), Phase 5 (voice search intent and mic button call SearchCoordinator.shared.search and reuse the same 3 passthroughs unchanged)]

actuals:
  tokens: 7500
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "First UITableViewController + custom UITableViewCell in the repo — hand-rolled, no third-party image library, per-cell async thumbnail load via URLSession.shared.data(from:) cancelled in prepareForReuse"
    - "SearchCoordinator is @MainActor; CarPlaySingleton stays a plain (non-isolated) class per the milestone convention — only the single bridging method (submitSearchQuery) is individually annotated @MainActor to cross the isolation boundary, rather than retrofitting @MainActor onto the whole singleton"
    - "SwiftUI View-conforming types (KeyboardView) inherit MainActor isolation for all their members via protocol-conformance inference, so the plain submitSearch() -> CarPlaySingleton.shared.submitSearchQuery(...) call site compiles without extra annotation"
    - "SearchResultsState enum (loading/results([SearchResult])/fallback) is the presenter vocabulary shared by SearchCoordinator and SearchResultsViewController — an empty .results([]) array IS the no-results state, not a separate case"
    - "Re-scoped Search/ boundary gate: SearchCoordinator.swift is the sole documented exception permitted to reference CarPlaySingleton"

key-files:
  created:
    - CarTube/Search/DurationFormatter.swift
    - CarTube/CarPlay/SearchResultsViewController.swift
    - CarTube/Search/SearchCoordinator.swift
    - CarTubeTests/DurationFormatterTests.swift
    - CarTubeTests/SearchCoordinatorTests.swift
  modified:
    - CarTube/CarPlay/CarPlaySingleton.swift
    - CarTube/CarPlay/CarPlayViewController.swift
    - CarTube/Views/KeyboardView.swift
    - CarTube.xcodeproj/project.pbxproj

key-decisions:
  - "submitSearchQuery(_:) on CarPlaySingleton is individually marked @MainActor (not the whole class) to satisfy the compiler's actor-isolation check when bridging into SearchCoordinator.shared.search(_:) — the plan's patterns doc explicitly forbade retrofitting @MainActor onto the whole CarPlaySingleton class; annotating just the one bridging method honors that boundary while fixing the Rule-1 compile error the tracer surfaced. showSearchResults/dismissSearchResults stay non-isolated since they only forward to the (non-isolated) controller."
  - "Fallback row (.fallback state / MessageCell.configureFallback) is implemented in SearchResultsViewController for switch-exhaustiveness and future reuse, but is functionally unreachable in this plan — SearchCoordinator's .degradeToWebviewSearch branch calls degrade(query) then dismissOverlay() immediately, never presenting .fallback. Plan 04-02 wires the fallback-row presentation with its own auto-dismiss timer."
  - "\"Try another search\" action label renders in the no-results row but is non-interactive this plan (no tap target) — onRetry wiring is deferred to 04-02 per the plan's explicit action text."
  - "Loading row body label (\"Searching…\") uses white text rather than systemGray — UI-SPEC's Copywriting Contract doesn't pin a color for this state and white keeps it legible as the primary state indicator; systemGray is reserved for the no-results/fallback secondary body copy per the Color table."

patterns-established:
  - "Per-cell async image load + cancel-on-reuse Task pattern for any future thumbnail/avatar list in this repo"
  - "@MainActor-isolated singleton (SearchCoordinator) coexisting with a plain-class singleton (CarPlaySingleton) via one individually-annotated bridging method, rather than a blanket actor retrofit"

requirements-completed: [UI-01, UI-02, UI-03]

coverage:
  - id: D1
    description: "Populated results render as a native UIKit list layered over the webview: min(results.count, 8) rows at 68pt row height, thumbnail+title+channel+duration, one tap plays via loadUrl(YT_EMBED + videoId) and dismisses the overlay"
    requirement: "UI-01"
    verification:
      - kind: unit
        ref: "CarTubeTests/SearchCoordinatorTests.swift#testHappyPathQueryRecordsLoadingThenResultsAndIssuesTwoRequests"
        status: pass
      - kind: manual_procedural
        ref: "Deferred to 04-02's phone-preview harness or a CarPlay-entitled simulator run — no CarPlay entitlement/simulator scene available in this environment"
        status: unknown
    human_judgment: true
    rationale: "The row-tap-plays-and-dismisses visual flow requires either a CarPlay-entitled simulator scene or 04-02's phone-preview harness (neither exists yet); the funnel and cell-construction logic are unit-proven, but the actual on-screen tap interaction needs human/harness verification."
  - id: D2
    description: "Overlay shows/hides via isHidden toggling only; webview frame remains view.bounds for the entire overlay lifecycle (UI-01 hard constraint — no resize, reload, or navigation)"
    requirement: "UI-01"
    verification:
      - kind: automated_ui
        ref: "awk-scoped grep: showSearchResults/dismissSearchResults method bodies in CarPlayViewController.swift contain zero 'webView' references"
        status: pass
    human_judgment: false
  - id: D3
    description: "Typed keyboard input funnels through the single SearchCoordinator via exactly three new CarPlaySingleton passthroughs (showSearchResults, dismissSearchResults, submitSearchQuery)"
    requirement: "UI-02"
    verification:
      - kind: unit
        ref: "git diff HEAD~1 -- CarTube/CarPlay/CarPlaySingleton.swift | grep -cE '^\\+.*func ' == 3"
        status: pass
      - kind: unit
        ref: "CarTubeTests/SearchCoordinatorTests.swift (both tests) — funnel exercised end-to-end against MockURLProtocol fixtures"
        status: pass
    human_judgment: false
  - id: D4
    description: "\"Results from YouTube\" attribution persists in the header across all states"
    requirement: "UI-03"
    verification:
      - kind: unit
        ref: "grep -q 'Results from YouTube' CarTube/CarPlay/SearchResultsViewController.swift"
        status: pass
    human_judgment: false
  - id: D5
    description: "ISO-8601 PT durations render as mm:ss / h:mm:ss badge strings; unparseable or nil durations leave the badge hidden"
    verification:
      - kind: unit
        ref: "CarTubeTests/DurationFormatterTests.swift (4 test methods, 15 assertions covering both formats, zero-padding edges, and all nil/empty/malformed rejects)"
        status: pass
    human_judgment: false
  - id: D6
    description: "SearchCoordinator unit tests prove [loading, results] state sequence for a happy-path query and zero-further-requests on a repeated identical query (cache hit), against MockURLProtocol fixtures with zero live network"
    verification:
      - kind: unit
        ref: "CarTubeTests/SearchCoordinatorTests.swift#testHappyPathQueryRecordsLoadingThenResultsAndIssuesTwoRequests, #testRepeatedIdenticalQueryHitsCacheAndIssuesNoFurtherRequests"
        status: pass
    human_judgment: false

duration: 55min
completed: 2026-08-19
status: complete
---

# Phase 4 Plan 1: End-to-End Typed Search Overlay Summary

**Native UITableViewController search-results overlay wired end-to-end: CarPlay keyboard submit key → @MainActor SearchCoordinator funnel → ≤8-row 68pt tappable list over the uninterrupted webview → one-tap playback and dismiss, with exactly three CarPlaySingleton passthroughs and a fixture-proven funnel test suite.**

## Performance

- **Duration:** 55 min
- **Started:** 2026-08-19T09:31:00+07:00
- **Completed:** 2026-08-19T10:26:00+07:00
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments
- `DurationFormatter` — Foundation-only, RED-first, strict `PT[nH][nM][nS]` regex parser producing `"12:34"` / `"1:02:03"` badge strings, nil on any malformed/empty/nil input (4 test methods, 15 assertions)
- `SearchResultsViewController` — the repo's first `UITableViewController` + custom-cell hand-roll: 68pt fixed-height rows, 106×60pt async-loading thumbnails (cancel-on-reuse `Task`), 22pt/17pt/15pt-monospaced text stack, `Close` + `"Results from YouTube"` header, loading/no-results single-row states, `min(results.count, 8)` row-count formula
- `SearchCoordinator` — `@MainActor final class` singleton with injectable `service`/`cache`/`presenter`/`degrade`/`dismissOverlay` seams, composing the Phase 3 chain (`LastQueryCache` → `YouTubeSearchService` → `SearchFallback.decide`) into a single `search(_:)` entry point
- `CarPlaySingleton` gains exactly 3 one-line passthroughs (`showSearchResults`, `dismissSearchResults`, `submitSearchQuery`) — the milestone's 3-passthrough cap is now fully spent
- `CarPlayViewController` wires the overlay below `screenOffLabel` with `insertSubview(belowSubview:)`, full `view.bounds` + `[.flexibleWidth, .flexibleHeight]` autoresizing, and show/dismiss methods that touch zero webview state
- `KeyboardView` gains a typed-query mirror buffer and a `magnifyingglass` submit key on all three keyboard modes, routing through `CarPlaySingleton.shared.submitSearchQuery`
- Two funnel tests prove `[loading, results]` state sequencing and a cache-hit short-circuit (zero further stubbed requests) against `MockURLProtocol` fixtures — full suite now at 46 passing tests, 0 failures, `TEST SUCCEEDED`

## Task Commits

Each task was committed atomically:

1. **Task 1: DurationFormatter — pure ISO-8601 PT→badge formatter, RED first** - `7075de0` (feat)
2. **Task 2: End-to-end typed search — keyboard submit → coordinator funnel → overlay rows → tap plays → dismiss** - `8ff450b` (feat)

## Files Created/Modified
- `CarTube/Search/DurationFormatter.swift` - Pure PT-duration → badge-string formatter, Foundation-only
- `CarTube/CarPlay/SearchResultsViewController.swift` - UITableViewController overlay, `SearchResultsState` enum, `ResultCell`/`MessageCell`, closure-based `onSelect`/`onClose`/`onRetry` init
- `CarTube/Search/SearchCoordinator.swift` - `@MainActor` funnel singleton, injectable seams, blank-query guard
- `CarTube/CarPlay/CarPlaySingleton.swift` - 3 new passthroughs; `submitSearchQuery` individually `@MainActor`
- `CarTube/CarPlay/CarPlayViewController.swift` - `resultsController` property + wiring + show/dismiss methods
- `CarTube/Views/KeyboardView.swift` - typed-query buffer, `magnifyingglass` submit key on all 3 modes
- `CarTubeTests/DurationFormatterTests.swift` - 4 test methods, 15 assertions
- `CarTubeTests/SearchCoordinatorTests.swift` - 2 funnel smoke tests against `MockURLProtocol` fixtures
- `CarTube.xcodeproj/project.pbxproj` - 4 new source files wired into `CarTube`/`CarTubeTests` targets (`Search` and `CarPlay` groups); recurring `dstSubfolder = PlugIns` gem-save quirk restored twice (once per wiring pass)

## Decisions Made
- `submitSearchQuery(_:)` individually annotated `@MainActor` (not the whole `CarPlaySingleton` class) to bridge synchronously into the `@MainActor`-isolated `SearchCoordinator.shared.search(_:)` — the compiler's own suggested fix, and the minimal surgical change that respects the patterns doc's explicit "do NOT retrofit `@MainActor` onto `CarPlaySingleton`" rule (that rule refers to the whole class, not one bridging method)
- `.fallback` state and its `MessageCell.configureFallback()` rendering are implemented now for switch-exhaustiveness and 04-02 reuse, but are unreachable at runtime this plan — `SearchCoordinator`'s degrade branch calls `degrade(query)` then `dismissOverlay()` immediately per this plan's caller contract, never presenting `.fallback`
- "Try another search" action label renders in the no-results row without a tap target — `onRetry` wiring is explicitly deferred to 04-02 per the plan's action text
- Loading-row body text ("Searching…") uses white rather than `systemGray`, since the Copywriting Contract doesn't pin a color for that state and white reads as the primary state indicator (systemGray reserved for no-results/fallback secondary body copy)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `submitSearchQuery` needed per-method `@MainActor` to compile**
- **Found during:** Task 2 (full-suite build after wiring all 6 sub-steps)
- **Issue:** `CarPlaySingleton` is a plain (non-actor-isolated) class; `submitSearchQuery` synchronously called `SearchCoordinator.shared.search(_:)`, a `@MainActor`-isolated method — Swift's actor-isolation checker rejected the synchronous cross-actor call as a build error, not a warning
- **Fix:** Annotated only `submitSearchQuery` with `@MainActor` (compiler's own suggested fix), leaving `CarPlaySingleton` itself and its other methods non-isolated
- **Files modified:** `CarTube/CarPlay/CarPlaySingleton.swift`
- **Verification:** Full suite builds and passes (46/46 tests, `TEST SUCCEEDED`); `KeyboardView.submitSearch()`'s call site compiles without further changes because SwiftUI's `View` protocol conformance infers `@MainActor` isolation across all of `KeyboardView`'s members
- **Committed in:** `8ff450b` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 Rule-1 bug fix)
**Impact on plan:** Necessary for correctness (the plan would not compile otherwise); preserves the architectural intent (CarPlaySingleton stays non-isolated) with the smallest possible surface change. No scope creep.

## Issues Encountered
- The `xcodeproj` gem's `project.save` dropped `dstSubfolder = PlugIns` from the `Embed Foundation Extensions` copy-files phase on both wiring passes (Task 1 and Task 2) — this is the same recurring gem quirk documented in Phase 2 and Phase 3; restored by hand each time before committing, per established convention.
- No CarPlay entitlement/simulator scene is available in this environment, so the plan's `<human-check>` visual pass (type on the keyboard, tap magnifyingglass, see the overlay, tap a row, confirm dismiss) could not be executed here — it is explicitly deferred to 04-02's phone-preview harness per the plan's own verification section, and is recorded as `human_judgment: true` coverage (D1) rather than silently skipped.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- `SearchResultsViewController`, `SearchCoordinator`, and the 3-passthrough `CarPlaySingleton` surface are all in place for 04-02 to build the fallback-row presentation, `onRetry` wiring, and a phone-preview harness on top of
- The 3-passthrough milestone cap is fully spent — Phase 5's voice/Siri intent must call `SearchCoordinator.shared.search(_:)` directly rather than adding a fourth passthrough
- The visual end-to-end pass (type → submit → overlay → tap → play → dismiss) remains unverified in a real CarPlay scene; 04-02 or a later on-device pass should close this out per `docs/runbooks/carplay-entitlement-grant-wiring.md`'s remaining manual steps

---
*Phase: 04-carplay-search-surface*
*Completed: 2026-08-19*

## Self-Check: PASSED
