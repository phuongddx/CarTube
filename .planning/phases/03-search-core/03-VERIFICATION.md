---
phase: 03-search-core
verified: 2026-08-18T23:35:00Z
status: gaps_found
score: 3/4 must-haves verified
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "On 403/quota/key failure, search degrades automatically to the existing webview search path — the driver is never left without a working search (fail-closed degradation)"
    status: partial
    reason: >
      The tested subset (SearchError.apiKeyMissing/apiKeyInvalid/quotaExceeded/other -> SearchFallback.decide ->
      .degradeToWebviewSearch) is genuinely wired and passes 6 fixture tests. However, two confirmed-unfixed
      critical defects (03-REVIEW.md CR-01, CR-02 — HEAD is still the review commit itself, zero fix commits
      since) mean realistic failure modes never reach the typed SearchError contract this fail-closed design
      depends on:
        1. `SearchResult.decodeDurationsByVideoId` builds its lookup with
           `Dictionary(uniqueKeysWithValues:)`, which traps (crashes the whole app, not just search) if
           `videos.list` ever returns a duplicate video ID for the caller's own `id=` list. A crash is strictly
           worse than "left without a working search" — it takes down CarPlay entirely.
        2. `YouTubeSearchService.checkForAPIError` only inspects HTTP status; on any 200 response it decodes
           straight into `JSONDecoder().decode`, which throws untyped `DecodingError` on malformed bodies
           (captive-portal HTML, API schema drift — both realistic in a car's variable-connectivity
           environment). That error is not `SearchError` and is not caught/converted anywhere in
           `search(query:)`, so it can propagate past `SearchFallback.decide` (which only accepts
           `Result<[SearchResult], SearchError>`) entirely — defeating the fail-closed guarantee for a
           common real-world failure class.
      Verified directly in the current source (not just the review): `git diff <review-commit> -- CarTube/Search/`
      is empty, and both lines are present verbatim in `SearchResult.swift:72` and
      `YouTubeSearchService.swift:60-76` today.
    artifacts:
      - path: "CarTube/Search/SearchResult.swift"
        issue: "decodeDurationsByVideoId (line 72) uses Dictionary(uniqueKeysWithValues:) — traps on any duplicate id key from the videos.list response body (untrusted external data)"
      - path: "CarTube/Search/YouTubeSearchService.swift"
        issue: "search(query:) (lines 60-76) never converts DecodingError (or any non-SearchError throw) from the two JSONDecoder().decode call sites into SearchError before it escapes the function"
    missing:
      - "Replace Dictionary(uniqueKeysWithValues:) with a duplicate-tolerant construction (e.g. Dictionary(_:uniquingKeysWith:) keeping the first/last value) so a duplicate video ID cannot crash the process"
      - "Wrap both decode call sites (decodeSearchResponse, decodeDurationsByVideoId) so any thrown error that is not already SearchError is converted to SearchError.other(...) before propagating out of search(query:), guaranteeing every throw from the client is a typed SearchError that SearchFallback.decide can route"
deferred: []
human_verification: []
---

# Phase 3: Search Core Verification Report

**Phase Goal:** A stateless, unit-tested YouTube Data API search client exists as a leaf component — the project's first test target — with quota budgeting and fail-closed degradation to the existing webview search
**Verified:** 2026-08-18T23:35:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | A search query returns parsed YouTube results (title, channel, duration, thumbnail) via Data API v3 with the key injected at build time and never present in the repo | ✓ VERIFIED | `SearchResult` flat Codable decodes real-shaped fixtures (13 service/model tests pass); key read only via `Bundle.main.object(forInfoDictionaryKey: "YOUTUBE_API_KEY")` in the default init; `CarTube/Info.plist:18-19` carries `$(YOUTUBE_API_KEY)`, resolved from gitignored root `Secrets.xcconfig` (confirmed `git check-ignore -q Secrets.xcconfig` exits 0, absent from `git status`); `git grep -nE 'AIza[0-9A-Za-z_-]{30,}'` returns zero matches repo-wide |
| 2 | Search spends quota deliberately: explicit-submit only, one page of results per query, and a last-query cache that avoids repeat calls | ✓ VERIFIED | `YouTubeSearchService` has one public `search(query:)` entry point, `maxResults=10` fixed, no `pageToken`/pagination parameter anywhere (`grep` gate green); `LastQueryCache` actor (single-slot, exact-string match) with 6 passing behavior tests (`cachedResults(for:)` nil on miss, hit on same query, nil after overwrite, `clear()` empties slot); `grep -rniE 'retry\|backoff\|prefetch\|autosearch' CarTube/Search/` returns zero matches |
| 3 | On 403/quota/key failure, search degrades automatically to the existing webview search path — the driver is never left without a working search | ⚠️ PARTIAL | `SearchFallback.decide` correctly routes every `SearchError` case (apiKeyMissing/apiKeyInvalid/quotaExceeded/other) to `.degradeToWebviewSearch`, tested by 6 passing fixture tests. **But** two confirmed, unfixed critical defects (03-REVIEW.md CR-01/CR-02, still present verbatim in HEAD) mean a duplicate-ID `videos.list` response crashes the app instead of degrading, and a malformed-200-body decode failure escapes the `SearchError` contract entirely instead of routing through `SearchFallback`. See Gaps below. |
| 4 | An XCTest target exists and passes fixture-JSON tests for the search client and shared URL parsing | ✓ VERIFIED | Re-ran `xcodebuild -project CarTube.xcodeproj -scheme CarTube -destination 'id=BC6D2019-EE12-458D-9990-FD25A9C3FD2E' test` directly (not taking SUMMARY's word for it): `** TEST SUCCEEDED **`, 38 tests, 0 failures, across `UtilitiesTests` (13), `YouTubeSearchServiceTests` (13), `LastQueryCacheTests` (6), `SearchFallbackTests` (6). Shared scheme's `TestAction` `Testables` block names `CarTubeTests` (confirmed by direct read of the `.xcscheme` XML, not grep alone) |

**Score:** 3/4 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `CarTubeTests` PBXNativeTarget | unit-test product type, Debug+Release, dependency on CarTube | ✓ VERIFIED | `project.pbxproj:387` `productType = "com.apple.product-type.bundle.unit-test"`; target dependency present |
| `CarTube.xcscheme` shared scheme | TestAction runs CarTubeTests | ✓ VERIFIED | Read full `<TestAction>` block: `Testables` names `BlueprintName = "CarTubeTests"`; file lives under `xcshareddata` (committed), not `xcuserdata` |
| `CarTubeTests/UtilitiesTests.swift` | 13-test URL-class matrix | ✓ VERIFIED | 13 `func test` methods, all passing |
| `CarTube/Search/SearchResult.swift` | flat Codable + private envelopes | ✓ VERIFIED | `struct SearchResult` public with 5 fields; envelope types are file-private (`private struct`) |
| `CarTube/Search/YouTubeSearchService.swift` | stateless, key/session-injectable, two-request search | ✓ VERIFIED | `final class`, injectable `apiKey`/`session`, two-request search+videos chain confirmed by reading source |
| `CarTubeTests/Fixtures/*.json` (4 files) | happy, durations, 403 quota, empty | ✓ VERIFIED | All 4 present, wired into `Resources` build phase, zero `AIza` substrings |
| `CarTubeTests/MockURLProtocol.swift` | request-log + response-queue stub | ✓ VERIFIED | Present, wired, used by all service tests — zero real network calls possible |
| `CarTube/Util/Constants.swift` additions | `YOUTUBE_SEARCH_ENDPOINT`/`YOUTUBE_VIDEOS_ENDPOINT` | ✓ VERIFIED | Both constants present, referenced as service defaults |
| `CarTube/Search/LastQueryCache.swift` | single-slot actor | ✓ VERIFIED | `actor LastQueryCache` with exactly the 3-method surface, no `UserDefaults` |
| `CarTube/Search/SearchFallback.swift` | pure decision function + caller contract | ✓ VERIFIED | `enum SearchOutcomeAction` + pure `static func decide`; caller-contract comment names `searchVideo`/`.shared` without importing or naming `CarPlaySingleton` literally in executable code (grep-gate confirmed) |
| `docs/runbooks/google-dev-key.md` | dev-key provisioning runbook | ✓ VERIFIED | Exists, mirrors shipping runbook, live-smoke section explicitly marked deferred, zero `AIza` substrings |
| `.planning/PROJECT.md` Key Decision rows (3) | no-toggle, dedupe-deferred, dev-key-separation | ✓ VERIFIED | Exactly 3 new rows present at end of Key Decisions table |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| Shared scheme TestAction | CarTubeTests target | `Testables` XML block | ✓ WIRED | Confirmed by direct scheme read |
| `CarTubeTests` target | `CarTube` app binary | `@testable import CarTube` + `TEST_HOST`/`BUNDLE_LOADER` | ✓ WIRED | Tests compile and run against real app source (38 green tests prove the link) |
| Default init | `Bundle.main.object(forInfoDictionaryKey:)` | key gate | ✓ WIRED | `YouTubeSearchService.swift:41` |
| Fixture JSON | `MockURLProtocol` → injected `URLSession` → `JSONDecoder` → `[SearchResult]` | stub + decode | ✓ WIRED | 13 service tests exercise this chain end-to-end with zero real network calls |
| `search.list` items | `videoIds` → `videos.list` → duration merge | two-request chain | ✓ WIRED | `testSearchHappyPathFillsDurationsAndIssuesTwoCorrectlyShapedRequests` asserts both request shapes and the merged duration |
| `SearchError` (failure) | `SearchFallback.decide` → `.degradeToWebviewSearch` | pure decision | ⚠️ WIRED BUT INCOMPLETE | Wired and tested for every named `SearchError` case, but the chain has a hole upstream — see gap: not every real failure reaches `SearchError` in the first place (CR-01 crashes before any `SearchError` exists; CR-02 throws a non-`SearchError` past the boundary) |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| SRCH-01 | 03-02 | Parsed results via Data API v3, key injected, never in repo | ✓ SATISFIED | Decode + key-gate tests pass; `Info.plist`/`Secrets.xcconfig` pipe confirmed; zero key literals |
| SRCH-02 | 03-03 | 100/day budget respected — explicit-submit, one page, last-query cache | ✓ SATISFIED | `LastQueryCache` tests pass; no pagination parameter; no auto-search tokens (grep gate) |
| SRCH-03 | 03-03 | On quota/key failure (403), degrades to webview search, never a dead screen | ✗ BLOCKED | Decision function itself is correct and tested, but two confirmed unfixed critical defects (CR-01, CR-02) mean the client can crash or leak an untyped error before `SearchFallback` ever sees it — the "never a dead screen" guarantee does not hold for these realistic failure modes |
| SRCH-04 | 03-01, 03-02 | XCTest target + fixture tests for client and shared parsing | ✓ SATISFIED | 38 tests, `TEST SUCCEEDED`, re-run directly by this verifier |

No orphaned requirements — REQUIREMENTS.md maps exactly SRCH-01..04 to Phase 3, and all four are claimed across the three plans.

Note: `.planning/REQUIREMENTS.md` still shows SRCH-02/SRCH-03 checkboxes unchecked ("Pending") — this is a bookkeeping lag expected to be resolved at phase close, not itself a functional gap, but SRCH-03 should remain unchecked given the finding above rather than be marked complete as-is.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `CarTube/Search/SearchResult.swift` | 72 | `Dictionary(uniqueKeysWithValues:)` on untrusted external data | 🛑 Blocker | Crashes the app on a duplicate video ID in the `videos.list` response — see Gaps |
| `CarTube/Search/YouTubeSearchService.swift` | 60-76 | Decode errors not converted to `SearchError` | 🛑 Blocker | Untyped `DecodingError` can escape `search(query:)`, bypassing `SearchFallback` entirely — see Gaps |
| `CarTube/Search/YouTubeSearchService.swift` | 79-85 | `CancellationError`/`URLError(.cancelled)` folded into `SearchError.other` | ⚠️ Warning | A cancelled in-flight request (e.g. cache-driven stale-query cancellation) would spuriously trigger a webview degrade rather than being treated as a silent no-op — not yet exercised since no caller cancels tasks in Phase 3, but the Phase 4 coordinator will |
| `CarTube/Search/YouTubeSearchService.swift` | 50-57 | No guard on empty/whitespace query before spending `search.list` quota | ⚠️ Warning | A blank/whitespace query burns a full 100-unit call; not yet reachable from any UI in Phase 3, but worth guarding before Phase 4 wires a live caller |
| `CarTube/Search/YouTubeSearchService.swift` | 92-96 | `addingPercentEncoding` failure silently falls back to the un-encoded raw value | ⚠️ Warning | Untested branch; assigning unescaped reserved characters into `percentEncodedQuery` is documented as producing invalid/undefined results |
| `CarTubeTests/LastQueryCacheTests.swift` | 57 | `XCTAssertTrue(cached == nil \|\| cached != nil)` — tautological, cannot fail | ⚠️ Warning | Gives false confidence that the concurrency test verifies actor safety; it only verifies the process didn't crash (which XCTest already reports independently) |
| `CarTube/Search/YouTubeSearchService.swift` | 62, 75-76 | Search response JSON decoded twice per call | ℹ️ Info | Redundant parsing, not a correctness issue |
| `CarTube/Search/YouTubeSearchService.swift` / `SearchResult.swift` | 68 / 39-50 | `videos.list` requests+decodes unused `snippet` part | ℹ️ Info | Dead weight, not a correctness issue |
| `CarTubeTests/YouTubeSearchServiceTests.swift` | — | Only `quotaExceeded` 403-reason branch tested; `apiKeyInvalid`/default paths untested | ℹ️ Info | Coverage gap, not a functional defect |
| `CarTube/Search/YouTubeSearchService.swift` | 45-48 | `normalizedKey` accepts whitespace-only keys as "present" | ℹ️ Info | Would surface as a less-diagnostic `SearchError.other("HTTP 400")` rather than `.apiKeyMissing`/`.apiKeyInvalid` |

No `TBD`/`FIXME`/`XXX`/`TODO`/`HACK`/`PLACEHOLDER` markers found in any Phase 3 file.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full suite runs and passes against real app source | `xcodebuild -project CarTube.xcodeproj -scheme CarTube -destination 'id=BC6D2019-EE12-458D-9990-FD25A9C3FD2E' test` (run once, directly, by this verifier) | `** TEST SUCCEEDED **`, 38 tests, 0 failures | ✓ PASS |
| No source drift since code review | `git diff e7f9372 -- CarTube/Search/` | empty diff | ✓ PASS (confirms CR-01/CR-02 are still live, not stale findings) |
| Zero key material in repo | `git grep -nE 'AIza[0-9A-Za-z_-]{30,}'` | no matches | ✓ PASS |
| Secrets.xcconfig stays gitignored | `git check-ignore -q Secrets.xcconfig` | exit 0 | ✓ PASS |

### Probe Execution

Not applicable — no `scripts/*/tests/probe-*.sh` convention in this project and none declared by the phase's plans. SKIPPED.

## Gaps Summary

The scaffold, model, client, cache, and decision-function work is genuinely solid: 38 real tests pass against real app source, the quota-budget surface is structurally correct (one page, explicit-submit, cache), and the key-injection pipe is clean (zero key material anywhere in the repo). SRCH-01, SRCH-02, and SRCH-04 are fully satisfied.

SRCH-03 and the phase's central "fail-closed degradation" goal are not fully satisfied. The 03-REVIEW.md code review — completed the same day, at the current HEAD commit, with zero fix commits since — already identified two **critical** defects that this verification independently confirmed by reading the live source: a crash on duplicate `videos.list` IDs (`Dictionary(uniqueKeysWithValues:)`), and JSON decode failures that escape the typed `SearchError` contract entirely. Both are realistic failure modes in a car's variable-connectivity environment (captive portals return 200 with HTML; duplicate/echoed IDs are a documented API edge case), and both mean the driver can be left with a crashed app or an unhandled exception — a strictly worse outcome than "left without a working search," which is precisely what this phase's fail-closed design exists to prevent.

These are narrow, well-scoped fixes (both already have concrete patches proposed in 03-REVIEW.md) and do not require replanning the phase's architecture — but they should be applied (or an explicit override recorded) before the phase is considered to have achieved its stated goal.

---

_Verified: 2026-08-18T23:35:00Z_
_Verifier: Claude (gsd-verifier)_
