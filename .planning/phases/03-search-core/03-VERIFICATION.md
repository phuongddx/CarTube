---
phase: 03-search-core
verified: 2026-08-19T09:10:00Z
status: passed
score: 4/4 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 3/4
  gaps_closed:
    - "On 403/quota/key failure, search degrades automatically to the existing webview search path — the driver is never left without a working search (fail-closed degradation)"
  gaps_remaining: []
  regressions: []
deferred: []
human_verification: []
---

# Phase 3: Search Core Verification Report

**Phase Goal:** A stateless, unit-tested YouTube Data API search client exists as a leaf component — the project's first test target — with quota budgeting and fail-closed degradation to the existing webview search
**Verified:** 2026-08-19T09:10:00Z
**Status:** passed
**Re-verification:** Yes — after gap closure (commit 86914c4)

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | A search query returns parsed YouTube results (title, channel, duration, thumbnail) via Data API v3 with the key injected at build time and never present in the repo | ✓ VERIFIED | Unchanged since prior verification. `SearchResult` flat Codable decodes real-shaped fixtures; key read only via `Bundle.main.object(forInfoDictionaryKey: "YOUTUBE_API_KEY")`; `Info.plist` carries `$(YOUTUBE_API_KEY)` resolved from gitignored `Secrets.xcconfig` (`git check-ignore -q Secrets.xcconfig` exits 0, confirmed again this run); `git grep -nE 'AIza[0-9A-Za-z_-]{30,}'` returns zero matches repo-wide (re-run) |
| 2 | Search spends quota deliberately: explicit-submit only, one page of results per query, and a last-query cache that avoids repeat calls | ✓ VERIFIED | Unchanged. `maxResults=10` fixed, no pagination parameter; `LastQueryCache` actor with 6 passing tests; no retry/backoff/prefetch/autosearch code paths |
| 3 | On 403/quota/key failure, search degrades automatically to the existing webview search path — the driver is never left without a working search | ✓ VERIFIED | **Gap closed.** Re-read current source directly (not the review or SUMMARY): `CarTube/Search/SearchResult.swift:70-77` — `decodeDurationsByVideoId` now builds the lookup with a plain `for item in envelope.items { durations[item.id] = ... }` loop (last-write-wins), replacing the trapping `Dictionary(uniqueKeysWithValues:)` (CR-01 closed — confirmed via `git show 86914c4` diff, matches source verbatim). `CarTube/Search/YouTubeSearchService.swift:82-90` adds a private `static func decode<T>(_ body: () throws -> T) throws -> T` that catches any non-`SearchError` throw and rethrows as `SearchError.other(...)`; both decode call sites in `search(query:)` (lines 62, 75, 76) are now wrapped through it, guaranteeing every throw out of `search(query:)` is a typed `SearchError` (CR-02 closed). `SearchFallback.decide` (unchanged, `CarTube/Search/SearchFallback.swift:22-29`) still maps every `.failure(SearchError)` to `.degradeToWebviewSearch` — the chain is now complete end-to-end with no hole upstream of the typed-error boundary. New regression tests independently confirmed: `testDuplicateVideoIdInVideosResponseDoesNotCrashAndLastDurationWins` (asserts last-write-wins duration, no trap) and `testMalformed200ResponseBodyMapsToSearchErrorOtherInsteadOfEscapingAsDecodingError` (stubs an HTML captive-portal-style 200 body, asserts the thrown error is `SearchError.other`, not a raw `DecodingError`) — both present in `CarTubeTests/YouTubeSearchServiceTests.swift` and **passed** in my own independent `xcodebuild test` run (see Behavioral Spot-Checks). |
| 4 | An XCTest target exists and passes fixture-JSON tests for the search client and shared URL parsing | ✓ VERIFIED | Independently re-ran `xcodebuild -project CarTube.xcodeproj -scheme CarTube -destination 'id=BC6D2019-EE12-458D-9990-FD25A9C3FD2E' test` myself (not trusting SUMMARY/task-prompt claims): `** TEST SUCCEEDED **`, 40 tests, 0 failures — `UtilitiesTests` (13), `YouTubeSearchServiceTests` (15, up from 13 — the 2 new CR-01/CR-02 regression tests), `LastQueryCacheTests` (6), `SearchFallbackTests` (6) |

**Score:** 4/4 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `CarTubeTests` PBXNativeTarget | unit-test product type, Debug+Release, dependency on CarTube | ✓ VERIFIED | Unchanged from prior run |
| `CarTube.xcscheme` shared scheme | TestAction runs CarTubeTests | ✓ VERIFIED | Unchanged from prior run |
| `CarTubeTests/UtilitiesTests.swift` | 13-test URL-class matrix | ✓ VERIFIED | 13 tests, all passing |
| `CarTube/Search/SearchResult.swift` | flat Codable + private envelopes + non-trapping duration decode | ✓ VERIFIED | CR-01 fix confirmed in place at lines 70-77: for-loop assignment, no `Dictionary(uniqueKeysWithValues:)` remaining |
| `CarTube/Search/YouTubeSearchService.swift` | stateless, key/session-injectable, two-request search, all throws typed as `SearchError` | ✓ VERIFIED | CR-02 fix confirmed: `decode<T>` wrapper (lines 82-90) added and used at all 3 decode call sites (62, 75, 76) |
| `CarTubeTests/Fixtures/*.json` (4 files) | happy, durations, 403 quota, empty | ✓ VERIFIED | All 4 present, wired, zero `AIza` substrings |
| `CarTubeTests/MockURLProtocol.swift` | request-log + response-queue stub | ✓ VERIFIED | Present, wired, used by all service tests |
| `CarTube/Util/Constants.swift` additions | `YOUTUBE_SEARCH_ENDPOINT`/`YOUTUBE_VIDEOS_ENDPOINT` | ✓ VERIFIED | Unchanged |
| `CarTube/Search/LastQueryCache.swift` | single-slot actor | ✓ VERIFIED | Unchanged, 26 lines, no regression |
| `CarTube/Search/SearchFallback.swift` | pure decision function + caller contract | ✓ VERIFIED | Unchanged, 30 lines, `decide` still maps every `.failure` to `.degradeToWebviewSearch` |
| `docs/runbooks/google-dev-key.md` | dev-key provisioning runbook | ✓ VERIFIED | Unchanged from prior run |
| `.planning/PROJECT.md` Key Decision rows (3) | no-toggle, dedupe-deferred, dev-key-separation | ✓ VERIFIED | Unchanged from prior run |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| Shared scheme TestAction | CarTubeTests target | `Testables` XML block | ✓ WIRED | Unchanged |
| `CarTubeTests` target | `CarTube` app binary | `@testable import CarTube` + `TEST_HOST`/`BUNDLE_LOADER` | ✓ WIRED | 40 green tests prove the link |
| Default init | `Bundle.main.object(forInfoDictionaryKey:)` | key gate | ✓ WIRED | Unchanged |
| Fixture JSON | `MockURLProtocol` → injected `URLSession` → `JSONDecoder` → `[SearchResult]` | stub + decode | ✓ WIRED | Unchanged, exercised end-to-end |
| `search.list` items | `videoIds` → `videos.list` → duration merge | two-request chain | ✓ WIRED | Unchanged, plus duplicate-id path now non-trapping |
| Any decode-site throw (not already `SearchError`) | `Self.decode` wrapper | `catch { throw SearchError.other(...) }` | ✓ WIRED (new) | Confirmed at all 3 call sites; `testMalformed200ResponseBodyMapsToSearchErrorOtherInsteadOfEscapingAsDecodingError` proves a raw `DecodingError` from a malformed 200 body now surfaces as `SearchError.other`, not an untyped throw |
| `SearchError` (failure) | `SearchFallback.decide` → `.degradeToWebviewSearch` | pure decision | ✓ WIRED | Now complete — no hole upstream. Every throw from `search(query:)` is guaranteed a `SearchError`, and `SearchFallback.decide` routes every `SearchError` case to `.degradeToWebviewSearch` |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full test suite passes independently (not trusting SUMMARY/task claim) | `xcodebuild -project CarTube.xcodeproj -scheme CarTube -destination 'id=BC6D2019-EE12-458D-9990-FD25A9C3FD2E' test` | `** TEST SUCCEEDED **`, 40 tests, 0 failures | ✓ PASS |
| CR-01 regression test exists and passes | Enumerated in above run: `testDuplicateVideoIdInVideosResponseDoesNotCrashAndLastDurationWins` | passed (0.001s), asserts `durations["dup1"] == "PT2M"` (last-write-wins) from a 2-item duplicate-id fixture | ✓ PASS |
| CR-02 regression test exists and passes | Enumerated in above run: `testMalformed200ResponseBodyMapsToSearchErrorOtherInsteadOfEscapingAsDecodingError` | passed (0.005s), asserts thrown error is `SearchError.other`, not an escaped `DecodingError` | ✓ PASS |
| Fix commit diff matches SUMMARY/task claim verbatim | `git show 86914c4 -- CarTube/Search/SearchResult.swift CarTube/Search/YouTubeSearchService.swift` | Diff matches described fix exactly: for-loop duration build + `decode<T>` wrapper at 3 call sites | ✓ PASS |
| No key leaked to repo | `git grep -nE 'AIza[0-9A-Za-z_-]{30,}'` | zero matches | ✓ PASS |
| No debt markers in touched files | `grep -nE "TBD\|FIXME\|XXX\|TODO\|HACK\|PLACEHOLDER" CarTube/Search/*.swift CarTubeTests/*.swift` | zero matches | ✓ PASS |
| Working tree clean for phase paths (no uncommitted drift) | `git status --short CarTube/Search CarTubeTests .planning/phases/03-search-core` | empty | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| SRCH-01 | 03-02 | Parsed results via Data API v3, key injected, never in repo | ✓ SATISFIED | Unchanged — decode + key-gate tests pass; zero key literals |
| SRCH-02 | 03-03 | 100/day budget respected — explicit-submit, one page, last-query cache | ✓ SATISFIED | Unchanged — `LastQueryCache` tests pass; no pagination; no auto-search tokens |
| SRCH-03 | 03-03 | On quota/key failure (403), degrades to webview search, never a dead screen | ✓ SATISFIED | **Now satisfied.** Both confirmed-unfixed critical defects (CR-01, CR-02) from 03-REVIEW.md are closed in commit `86914c4`, verified directly against current source (not SUMMARY narrative), with dedicated regression tests independently re-run and passing. The typed-`SearchError` contract that `SearchFallback.decide` depends on now holds for every code path in `search(query:)` |
| SRCH-04 | 03-01, 03-02 | XCTest target + fixture tests for client and shared parsing | ✓ SATISFIED | 40 tests, `TEST SUCCEEDED`, re-run directly by this verifier |

No orphaned requirements — REQUIREMENTS.md maps exactly SRCH-01..04 to Phase 3, and all four are claimed across the three plans (confirmed by direct grep against REQUIREMENTS.md, unchanged from prior run).

### Anti-Patterns Found

None. `grep -nE "TBD|FIXME|XXX|TODO|HACK|PLACEHOLDER"` across `CarTube/Search/*.swift` and `CarTubeTests/*.swift` returns zero matches. No debt markers introduced by the fix commit.

### Human Verification Required

None. All four observable truths are verifiable programmatically and were independently confirmed against current source plus a fresh, self-run `xcodebuild test` pass.

### Gaps Summary

No gaps remain. The single gap from the prior verification run (SRCH-03 / Truth 3 — fail-closed degradation undermined by CR-01 duplicate-ID crash and CR-02 untyped-decode-error escape) is closed: both defects are fixed in commit `86914c4`, the fix diff was read directly and matches the claimed remediation exactly, dedicated regression tests exist for each defect, and the full test suite (40 tests, up from 38) was independently re-run by this verifier and passed with zero failures. No regressions were found in the previously-verified truths, artifacts, or key links.

---

_Verified: 2026-08-19T09:10:00Z_
_Verifier: Claude (gsd-verifier)_
