---
phase: 03-search-core
plan: 03
subsystem: search
tags: [actor, pure-function, tdd, google-cloud, key-management]

requires:
  - phase: 03-search-core
    plan: 02
    provides: YouTubeSearchService.search(query:) async throws -> [SearchResult], SearchError enum
provides:
  - CarTube/Search/LastQueryCache.swift — actor, single-slot (query, [SearchResult]) exact-match cache with cachedResults(for:)/store/clear
  - CarTube/Search/SearchFallback.swift — pure decide(Result<[SearchResult], SearchError>, query:) -> SearchOutcomeAction {showResults, showNoResults, degradeToWebviewSearch} + caller contract documented in comments
  - CarTubeTests/LastQueryCacheTests.swift + CarTubeTests/SearchFallbackTests.swift (12 new tests)
  - docs/runbooks/google-dev-key.md — cartube-dev project provisioning runbook, mirrors the shipping-key runbook, live-smoke section explicitly marked deferred
  - .planning/PROJECT.md — 3 new Key Decision rows (no Phase 3 search toggle, parser-dedupe deferred, dev-key separation), all Outcome: Pending
affects: [03-search-core (Task 3 step 2 + Task 4 remain — live smoke + checkpoint), Phase 4 (SearchCoordinator consumes LastQueryCache + SearchFallback.decide and wires the degradeToWebviewSearch edge to CarPlaySingleton.shared.searchVideo(query))]

actuals:
  tokens: 6203
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "Single-slot actor cache (LastQueryCache) mirrors CarPlaySingleton's cachedVideo triad shape at query granularity — exact-string match, no TTL, no UserDefaults, store-on-submit/read-before-network/clear-on-new-query"
    - "Fail-closed pure decision function (SearchFallback.decide) keeps the CarPlay singleton call out of Search/ entirely — the caller contract lives in a comment block, not code, preserving the one-directional Search -> (documented, unimported) CarPlay boundary"
    - "Dev-key runbook mirrors the shipping-key runbook structure but relaxes the application-restriction requirement (optional for a dev-only key) and documents the CI command-line-override delivery path alongside the local Secrets.xcconfig swap"

key-files:
  created:
    - CarTube/Search/LastQueryCache.swift
    - CarTube/Search/SearchFallback.swift
    - CarTubeTests/LastQueryCacheTests.swift
    - CarTubeTests/SearchFallbackTests.swift
    - docs/runbooks/google-dev-key.md
  modified:
    - .planning/PROJECT.md
    - CarTube.xcodeproj/project.pbxproj

key-decisions:
  - "SearchFallback's caller-contract comment names the CarPlay facade singleton's .shared instance and searchVideo(query) method by behavior, not by the literal type name CarPlaySingleton — the plan's own acceptance gate (`! grep -rq 'CarPlaySingleton' CarTube/Search/`) forbids the literal string anywhere under Search/, including comments, so the contract is phrased around the method name and group location instead"
  - "No user-visible search toggle shipped in Phase 3 (Key Decision row, Outcome: Pending) — quota budget stays code-enforced (cache + explicit-submit surface), UX-level toggle decision deferred to Phase 4's coordinator"
  - "Share-extension parser dedupe deferred (Key Decision row, Outcome: Pending) — recorded as tech debt per 03-PATTERNS.md's own recommendation; zero Phase 3 value against a pbxproj target-membership change"
  - "Dev key separated into a dedicated cartube-dev Google Cloud project (Key Decision row, Outcome: Pending) — the runbook exists and is fully click-path-ready, but no key has been created yet; that action plus the live-smoke decision is exactly what Task 4's checkpoint gates"

requirements-completed: []

coverage:
  - id: D1
    description: "LastQueryCache — a repeat of the identical query returns the cached page with zero network requests; a new query overwrites the single slot and re-fetches"
    requirement: "SRCH-02"
    verification:
      - kind: unit
        ref: "CarTubeTests/LastQueryCacheTests.swift#testStoreThenCachedResultsForSameQueryReturnsStoredArray"
        status: pass
      - kind: unit
        ref: "CarTubeTests/LastQueryCacheTests.swift#testStoringNewQueryEvictsPreviousSlot"
        status: pass
    human_judgment: false
  - id: D2
    description: "Search/ exposes no auto/prefetch/retry surface anywhere — grep gate confirms zero retry|backoff|prefetch|autosearch tokens"
    requirement: "SRCH-02"
    verification:
      - kind: other
        ref: "grep -rniE 'retry|backoff|prefetch|autosearch' CarTube/Search/ (zero matches)"
        status: pass
    human_judgment: false
  - id: D3
    description: "SearchFallback.decide maps every SearchError kind to degradeToWebviewSearch, empty success to showNoResults, and non-empty success to showResults, as a pure fixture-testable function"
    requirement: "SRCH-03"
    verification:
      - kind: unit
        ref: "CarTubeTests/SearchFallbackTests.swift#testKeyMissingDegradesToWebviewSearch"
        status: pass
      - kind: unit
        ref: "CarTubeTests/SearchFallbackTests.swift#testOtherFailureDegradesToWebviewSearch"
        status: pass
      - kind: unit
        ref: "CarTubeTests/SearchFallbackTests.swift#testSuccessWithEmptyResultsShowsNoResults"
        status: pass
    human_judgment: false
  - id: D4
    description: "Dev/shipping key separation runbooked, and PROJECT.md records the 3 planner decisions this plan makes"
    requirement: "SRCH-03"
    verification:
      - kind: other
        ref: "docs/runbooks/google-dev-key.md exists; PROJECT.md Key Decisions row-count delta == 3 against git HEAD baseline"
        status: pass
    human_judgment: false
  - id: D5
    description: "Live smoke search against the real YouTube Data API, spending 2 quota units through a human-approved key path"
    requirement: "SRCH-03"
    verification: []
    human_judgment: true
    rationale: "Requires a human decision (provision cartube-dev, spend shipping-key units, or skip) and Google Cloud console access the executor does not have — this is exactly Task 3 step 2 + Task 4's blocking checkpoint, deliberately not executed this session"

duration: 24min
completed: 2026-08-18
status: halted
---

# Phase 3 Plan 03: Quota Cache + Fail-Closed Fallback (partial — halted at checkpoint) Summary

**LastQueryCache actor and SearchFallback pure decision function built and tested (12 new tests, 38 total suite-wide); dev-key runbook authored and 3 Key Decision rows recorded — Task 3's live smoke search and Task 4's blocking checkpoint intentionally not executed, awaiting a human decision on which Google key to spend against.**

## Performance

- **Duration:** 24 min
- **Started:** 2026-08-18T22:50:00+07:00
- **Completed (partial — halted):** 2026-08-18T23:14:00+07:00
- **Tasks:** 3 of 4 (Task 3 partial: steps 1+3 done, step 2 deferred; Task 4 not attempted)
- **Files modified:** 7

## Accomplishments
- `LastQueryCache` — an `actor` with exactly the three-method surface (`cachedResults(for:)`, `store(query:results:)`, `clear()`), single-slot exact-string match, no TTL, no `UserDefaults`, Foundation-only — SRCH-02's repeat-call avoider, tested with 6 behavior tests including a concurrent-access sanity check
- `SearchFallback` — `enum SearchOutcomeAction { showResults, showNoResults, degradeToWebviewSearch }` plus the pure `static func decide(_:query:)` implementing the exact SRCH-03 decision tree (every `SearchError` case degrades; empty success is data, not failure), tested with 6 behavior tests covering all four `SearchError` cases plus both success branches
- The caller contract for `.degradeToWebviewSearch` is documented in a comment block naming the target method and its group location, without ever using the literal `CarPlaySingleton` type name or importing anything CarPlay-related — verified by the plan's own grep gates (zero executable `searchVideo` references, zero `CarPlaySingleton` references anywhere under `CarTube/Search/`)
- `docs/runbooks/google-dev-key.md` — a complete click-path runbook for a second, dedicated `cartube-dev` Google Cloud project, mirroring the Phase 1 shipping-key runbook's structure, stating the separation rule verbatim and documenting both the local `Secrets.xcconfig` swap and the CI command-line-override delivery paths
- Three Key Decision rows appended to `.planning/PROJECT.md` (verified `AFTER − BEFORE == 3` against the `git HEAD` baseline): no Phase 3 search toggle, share-extension parser dedupe deferred, dev-key project separation — all recorded `Outcome: Pending`
- Full test suite: 38 tests, 0 failures (`** TEST SUCCEEDED **`), up from 32 at the start of this plan

## Task Commits

Each completed task/step was committed atomically:

1. **Task 1: LastQueryCache — single-slot (query, results) with zero-request hit** - `cfe6e87` (feat)
2. **Task 2: SearchFallback — pure fail-closed decision function with documented caller contract** - `17236a5` (feat)
3. **Task 3 steps 1+3: Dev-key runbook authored + 3 Key Decision rows appended to PROJECT.md** - `7beec13` (docs)

**Not executed this session:** Task 3 step 2 (live smoke search) and Task 4 (checkpoint:human-verify, gate="blocking") — see "Deviations from Plan" below.

## Files Created/Modified
- `CarTube/Search/LastQueryCache.swift` - Actor, single-slot exact-match `(query, [SearchResult])` cache
- `CarTubeTests/LastQueryCacheTests.swift` - 6 behavior tests
- `CarTube/Search/SearchFallback.swift` - `SearchOutcomeAction` enum + pure `decide` function + caller-contract comment block
- `CarTubeTests/SearchFallbackTests.swift` - 6 behavior tests
- `docs/runbooks/google-dev-key.md` - cartube-dev project provisioning runbook (new)
- `.planning/PROJECT.md` - +3 Key Decision rows
- `CarTube.xcodeproj/project.pbxproj` - 4 new source/test files wired into `CarTube`/`CarTubeTests` targets (2 gem invocations, each requiring the known `dstSubfolder = PlugIns` restoration — see Deviations)

## Decisions Made
- SearchFallback's caller-contract comment refers to the CarPlay facade singleton by behavior (`.shared` instance, `searchVideo(query)` method, "defined in the CarPlay/ group") rather than by its literal type name, because the plan's own acceptance gate forbids the string `CarPlaySingleton` anywhere under `CarTube/Search/`, including comments
- Task 1 and Task 2 each landed as a single `feat` commit covering RED+GREEN together (tests + implementation), matching the precedent set by plan 03-02's two task commits rather than splitting into separate `test`/`feat` commits
- Task 3's live-smoke verification section in the runbook is written as a template with an explicit "Status of this section as of 2026-08-18: deferred" note, rather than left blank, so the next session has the exact fields to fill in once a key exists

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] xcodeproj gem's save dropped `dstSubfolder = PlugIns` on both gem invocations this plan**
- **Found during:** Task 1 and Task 2 (pbxproj diff review before each commit)
- **Issue:** Same known gem quirk documented in plans 03-01 and 03-02: `project.save` on the Embed Foundation Extensions copy-files phase drops `dstSubfolder = PlugIns;` every time the gem is invoked
- **Fix:** Restored `dstSubfolder = PlugIns;` by hand before each commit
- **Files modified:** `CarTube.xcodeproj/project.pbxproj`
- **Verification:** `git diff` scoped to only the intended Search-group/test-file additions plus this known-quirk correction on both occasions; no spurious empty `dependencies = ();` array appeared either time
- **Committed in:** `cfe6e87` (Task 1), `17236a5` (Task 2)

### Intentional Non-Execution (per explicit instruction, not a deviation)

**Task 3 step 2 (live smoke search) and Task 4 (checkpoint:human-verify, gate="blocking") were deliberately not attempted this session.** The plan's own task-ordering note states step 2 must not complete before Task 4's blocking checkpoint resolves — this session halted at exactly that boundary rather than fabricating a key, guessing at Google Cloud console state, or attempting to resolve the checkpoint without the human's input. Specifically:
- No Google Cloud project was created (neither `cartube-dev` nor any substitute)
- `Secrets.xcconfig` was not read, written, or inspected for its value — it remains whatever it was before this session (confirmed still gitignored, still absent from `git status`)
- No network request was made against `googleapis.com`
- The runbook's live-smoke verification section is explicitly marked "deferred" with the fields to fill in once resolved

---

**Total deviations:** 1 auto-fixed (Rule 3, repeated known gem quirk) + 1 documented intentional non-execution (checkpoint boundary, per explicit instruction)
**Impact on plan:** The gem-quirk fix was necessary and cosmetic-scope only (unrelated pbxproj attribute restoration). The non-execution is the plan's own designed stop point — nothing was skipped that the plan expected this session to complete.

## Issues Encountered
None beyond the deviation documented above.

## User Setup Required

**External action required before this plan can close out.** The human must choose ONE of three paths at Task 4's checkpoint:

1. **Follow `docs/runbooks/google-dev-key.md`** to create the `cartube-dev` project, restrict the key, and paste it into `Secrets.xcconfig` — then report "dev key ready" plus the project ID.
2. **Approve spending 2 quota units from the shipping key** for the smoke search instead — reply "use shipping key". (Note: per this session's environment context, the real shipping key does not yet exist either — Phase 1's Google Cloud checkpoint is still pending — so this path is currently unavailable until that resolves.)
3. **Skip live verification this phase** — reply "skip smoke", and the smoke is recorded as deferred-to-first-Phase-4-run per Task 3's own fallback criterion.

The human should also review the three new PROJECT.md Key Decision rows (no Phase 3 search toggle, parser-dedupe deferred, dev-key separation) and flag any wording changes.

## Next Phase Readiness
- `LastQueryCache` and `SearchFallback` are complete, tested, and ready for Phase 4's `SearchCoordinator` to consume directly — no further work needed on either component this phase
- The dev-key runbook is fully written and ready to execute the moment a human starts it
- **Blocker:** Task 3 step 2 + Task 4 remain open. Phase 3 cannot close out (and the phase-level `xcodebuild test` / SRCH requirement traceability in the plan's own `<verification>` section cannot be fully asserted "closed") until this checkpoint resolves
- STATE.md records the halt, the pending human decision, and points back to this plan file as the resume point

---
*Phase: 03-search-core*
*Completed: 2026-08-18 (partial — halted at checkpoint)*

## Self-Check: PASSED

All key files (LastQueryCache.swift, LastQueryCacheTests.swift, SearchFallback.swift, SearchFallbackTests.swift, docs/runbooks/google-dev-key.md, this SUMMARY) and all three commit hashes (cfe6e87, 17236a5, 7beec13) verified present on disk / in git log. `git grep -nE 'AIza[0-9A-Za-z_-]{30,}'` returns zero matches. `Secrets.xcconfig` confirmed still gitignored (`git check-ignore -q Secrets.xcconfig` exits 0) and absent from `git status`.
