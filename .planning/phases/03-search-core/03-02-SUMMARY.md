---
phase: 03-search-core
plan: 02
subsystem: search
tags: [codable, urlsession, async-await, urlprotocol-stub, youtube-data-api]

requires:
  - phase: 03-search-core
    plan: 01
    provides: CarTubeTests unit-test target + shared-scheme xcodebuild test pipeline
provides:
  - CarTube/Search/SearchResult.swift — flat five-field Codable model (videoId/title/channel/thumbnail/duration), private envelope types, Foundation-only
  - CarTube/Search/YouTubeSearchService.swift — stateless async client: search(query:) -> [SearchResult], typed SearchError, default-init key gate, two-request duration fill, one-page quota budget
  - CarTubeTests/MockURLProtocol.swift — URLProtocol stub with request-log + response-queue, reusable by any future network test
  - CarTubeTests/Fixtures/{search-response,videos-response,error-403-quota,search-response-empty}.json
  - CarTube/Util/Constants.swift additions: YOUTUBE_SEARCH_ENDPOINT, YOUTUBE_VIDEOS_ENDPOINT
affects: [03-search-core (plan 03 builds the quota-budget cache + SRCH-03 degrade decision on top of this client), Phase 4 (results UI consumes SearchResult directly), Phase 5 (voice search intent calls YouTubeSearchService)]

actuals:
  tokens: 7864
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "First Codable/JSONDecoder usage in the repo: flat public struct + private nested envelope types kept in the same file — API shapes never escape Search/"
    - "Key gate via injected initializer + convenience default initializer reading Bundle.main.object(forInfoDictionaryKey:) — testable without touching Bundle.main from tests"
    - "async/await for all new Search/ code (no completion closures) — decided per 03-PATTERNS.md deviation 7, iOS 16 floor makes it available"
    - "Custom percent-encoding CharacterSet (urlQueryAllowed minus &=+) for query VALUES — .urlQueryAllowed alone permits literal & in a value, which corrupts multi-word queries containing '&'"
    - "URLProtocol stub (MockURLProtocol) with a static request-log + response-queue is now the house pattern for any URLSession-based unit test"
    - "Quota budget is structural in the API surface (part=snippet&type=video&maxResults=10, no pagination parameter), not caller discipline"

key-files:
  created:
    - CarTube/Search/SearchResult.swift
    - CarTube/Search/YouTubeSearchService.swift
    - CarTubeTests/MockURLProtocol.swift
    - CarTubeTests/Fixtures/search-response.json
    - CarTubeTests/Fixtures/videos-response.json
    - CarTubeTests/Fixtures/error-403-quota.json
    - CarTubeTests/Fixtures/search-response-empty.json
    - CarTubeTests/YouTubeSearchServiceTests.swift
  modified:
    - CarTube/Util/Constants.swift
    - CarTube.xcodeproj/project.pbxproj

key-decisions:
  - "Fixture loading uses Bundle(for:).path(forResource:ofType:) WITHOUT inDirectory: — the xcodeproj gem's new_file() on a group adds fixtures as flat group references, so resources land at the CarTubeTests.xctest bundle root, not under a Fixtures/ subdirectory, even though the pbxproj group is nested. Discovered via a Fatal error unwrapping nil on the first fixture-loading test."
  - "The empty-items decode test (task 1, model-only) uses an inline JSON literal rather than the search-response-empty.json fixture, because that fixture is scoped to task 2's files list (service-level empty-success test via MockURLProtocol) — keeps each task's git diff matching its own <files> declaration."
  - "Repeated the Phase 2 / 03-01 fix: the xcodeproj gem's project.save dropped dstSubfolder = PlugIns from the Embed Foundation Extensions copy-files phase on BOTH gem invocations this plan (task 1 and task 2 wiring) — restored by hand each time before committing. Task 1's save also added a spurious empty dependencies = (); array to the PlayOnCarTube target, which was removed; task 2's save did not repeat that second quirk."
  - "Query-value percent-encoding uses a custom CharacterSet (.urlQueryAllowed minus &=+) instead of the bare .urlQueryAllowed the codebase's existing CarPlaySingleton.searchVideo uses — .urlQueryAllowed treats & as an allowed/unescaped character, which is correct for encoding a whole query string but wrong for a single value that must not reintroduce the delimiter. Verified by a dedicated percent-encoding test asserting 'lofi beats & focus' survives as 'lofi%20beats%20%26%20focus'."
  - "SearchError.other(String) carries a description string (HTTP status code or underlying error's localizedDescription) rather than being a plain case with no payload, so the 03-03 degrade-decision consumer (and any future logging) still has diagnostic detail even though the enum case doesn't distinguish sub-reasons within 'other'."

requirements-completed: [SRCH-01, SRCH-04]

coverage:
  - id: D1
    description: "A search query decodes a real-shaped search.list response into [SearchResult] carrying videoId/title/channel/thumbnail/duration, with duration filled by a follow-up videos.list call inside one search(...) completion"
    requirement: "SRCH-01"
    verification:
      - kind: unit
        ref: "CarTubeTests/YouTubeSearchServiceTests.swift#testSearchHappyPathFillsDurationsAndIssuesTwoCorrectlyShapedRequests"
        status: pass
    human_judgment: false
  - id: D2
    description: "The API key is read only in the service's default initializer via Bundle.main.object(forInfoDictionaryKey:), and nil/empty/$(-prefixed values are all treated as not-configured, failing immediately with SearchError.apiKeyMissing and zero network requests"
    requirement: "SRCH-01"
    verification:
      - kind: unit
        ref: "CarTubeTests/YouTubeSearchServiceTests.swift#testSearchWithNilKeyThrowsApiKeyMissingAndIssuesZeroRequests"
        status: pass
      - kind: unit
        ref: "CarTubeTests/YouTubeSearchServiceTests.swift#testSearchWithUnsubstitutedOrEmptyKeyThrowsApiKeyMissingAndIssuesZeroRequests"
        status: pass
      - kind: unit
        ref: "CarTubeTests/YouTubeSearchServiceTests.swift#testNormalizedKeyGateRejectsNilEmptyAndUnsubstitutedValues"
        status: pass
    human_judgment: false
  - id: D3
    description: "Every unit test runs against fixture JSON served through an injected URLSession stubbed by MockURLProtocol — zero tests hit the network"
    requirement: "SRCH-04"
    verification:
      - kind: integration
        ref: "xcodebuild -project CarTube.xcodeproj -scheme CarTube -destination 'id=F14D9B48-EF6B-4ACD-BB09-2D5951BF5D0A' test"
        status: pass
    human_judgment: false
  - id: D4
    description: "SearchError distinguishes apiKeyMissing/apiKeyInvalid/quotaExceeded/other so the caller can make the SRCH-03 degrade decision on typed data, not string matching"
    requirement: "SRCH-04"
    verification:
      - kind: unit
        ref: "CarTubeTests/YouTubeSearchServiceTests.swift#test403QuotaResponseMapsToSearchErrorQuotaExceeded"
        status: pass
      - kind: unit
        ref: "CarTubeTests/YouTubeSearchServiceTests.swift#testNonQuotaHTTPErrorMapsToOtherDistinctFromQuota"
        status: pass
    human_judgment: false

duration: 15min
completed: 2026-08-18
status: complete
---

# Phase 3 Plan 02: YouTube Data API Search Client Summary

**Stateless, Foundation-only YouTube Data API v3 client: flat Codable SearchResult model, typed SearchError, key-gate default initializer, two-request duration fill, and a fixture-JSON test suite proven to hit zero real network calls via MockURLProtocol.**

## Performance

- **Duration:** 15 min
- **Started:** 2026-08-18T22:30:57+07:00
- **Completed:** 2026-08-18T22:45:49+07:00
- **Tasks:** 2
- **Files modified:** 10

## Accomplishments
- `SearchResult` — the repo's first `Codable`/`JSONDecoder` type: flat public struct with `videoId`/`title`/`channel`/`thumbnail`/`duration`, private nested envelope types (`SearchItemEnvelope`, `VideoItemEnvelope`) that never escape the file
- `YouTubeSearchService` — stateless `final class` with `search(query:) async throws -> [SearchResult]`, a typed `SearchError` enum, and a default initializer whose key gate collapses nil/empty/`$(...)`-unsubstituted values to `.apiKeyMissing` before any request is built
- Two-request duration fill: `search.list?part=snippet&type=video&maxResults=10` then, only if results are non-empty, `videos.list?part=contentDetails,snippet&id=<comma-list>` — one page, no pagination parameter anywhere in the surface
- `MockURLProtocol` — request-log + response-queue URLProtocol stub, now the house pattern for any future URLSession test
- Four fixtures (`search-response`, `videos-response`, `error-403-quota`, `search-response-empty`) plus 17 new tests (4 model-decode + 13 service-behavior/key-gate/percent-encoding), all passing with zero network calls
- Custom percent-encoding `CharacterSet` fixes a latent bug class: `.urlQueryAllowed` alone treats `&` as unescaped, which would corrupt any query containing an ampersand

## Task Commits

Each task was committed atomically:

1. **Task 1: SearchResult model — flat five-field Codable over real envelope shapes** - `7fe6f4f` (feat)
2. **Task 2: YouTubeSearchService — typed errors, key gate, two-request duration fill, stubbed URLSession** - `86fb880` (feat)

## Files Created/Modified
- `CarTube/Search/SearchResult.swift` - Flat `Codable`/`Equatable` model + private envelope types + `decodeSearchResponse`/`decodeDurationsByVideoId` mapping functions
- `CarTube/Search/YouTubeSearchService.swift` - Stateless async client, `SearchError` enum, key gate, two-request duration fill, custom percent-encoding
- `CarTube/Util/Constants.swift` - Added `YOUTUBE_SEARCH_ENDPOINT` / `YOUTUBE_VIDEOS_ENDPOINT`
- `CarTubeTests/MockURLProtocol.swift` - URLProtocol stub with static request log + response queue
- `CarTubeTests/Fixtures/search-response.json` - 3-item real-shaped `search.list` response
- `CarTubeTests/Fixtures/videos-response.json` - 3-item real-shaped `videos.list` response with `PT#M#S`-style durations
- `CarTubeTests/Fixtures/error-403-quota.json` - Minimal real-shaped 403 quota error envelope
- `CarTubeTests/Fixtures/search-response-empty.json` - Empty-items search response
- `CarTubeTests/YouTubeSearchServiceTests.swift` - 17 tests across model decode + service behavior
- `CarTube.xcodeproj/project.pbxproj` - `Search` group + 2 source files + 4 fixtures wired into `CarTube`/`CarTubeTests` targets

## Decisions Made
- Fixture loading via `Bundle(for:).path(forResource:ofType:)` without `inDirectory:` — the xcodeproj gem's flat group-reference resource wiring puts fixtures at the test bundle root regardless of the pbxproj group nesting
- Task 1's empty-items decode test uses an inline JSON literal instead of the `search-response-empty.json` fixture, to keep that fixture's git-diff scope inside task 2 where the plan declared it
- Custom `CharacterSet` (`.urlQueryAllowed` minus `&=+`) for percent-encoding query values, since the default set leaves `&` unescaped in a value — verified by a dedicated encoding test
- `SearchError.other(String)` carries a diagnostic string (HTTP status or `localizedDescription`) so future callers/logging retain detail within the catch-all case

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixture loading returned nil with `inDirectory: "Fixtures"`**
- **Found during:** Task 1 (first test run)
- **Issue:** `Bundle(for:).path(forResource:ofType:inDirectory:)` returned `nil`, crashing with a force-unwrap `Fatal error` — the xcodeproj gem's `new_file` on a nested group adds a flat group reference, so the built test bundle copies fixtures to its root rather than preserving the `Fixtures/` subpath the pbxproj group implies
- **Fix:** Dropped `inDirectory:` from the fixture-loading helper
- **Files modified:** CarTubeTests/YouTubeSearchServiceTests.swift
- **Verification:** All model-decode tests pass after the fix
- **Committed in:** 7fe6f4f (Task 1 commit)

**2. [Rule 3 - Blocking] xcodeproj gem's save dropped `dstSubfolder = PlugIns` and added a spurious empty `dependencies = ();` array (task 1 wiring)**
- **Found during:** Task 1 (pbxproj diff review before commit)
- **Issue:** Same known gem quirk documented in plan 03-01: the Embed Foundation Extensions copy-files phase lost `dstSubfolder = PlugIns;`, and an empty `dependencies = ();` array appeared on the unrelated `PlayOnCarTube` target
- **Fix:** Restored `dstSubfolder = PlugIns;`; removed the spurious empty `dependencies = ();`
- **Files modified:** CarTube.xcodeproj/project.pbxproj
- **Verification:** `git diff` scoped to only the intended Search-group/fixture additions plus this known-quirk correction
- **Committed in:** 7fe6f4f (Task 1 commit)

**3. [Rule 3 - Blocking] xcodeproj gem's save dropped `dstSubfolder = PlugIns` again (task 2 wiring)**
- **Found during:** Task 2 (pbxproj diff review before commit)
- **Issue:** The same gem quirk repeated on the second `project.save` call this plan; the spurious empty `dependencies` array did not recur this time
- **Fix:** Restored `dstSubfolder = PlugIns;`
- **Files modified:** CarTube.xcodeproj/project.pbxproj
- **Verification:** `git diff --stat` showed only the 4 new file-wiring entries plus this correction; full suite re-ran green
- **Committed in:** 86fb880 (Task 2 commit)

**4. [Rule 1 - Bug] Own explanatory comment tripped the `! grep -q 'pageToken'` acceptance gate**
- **Found during:** Task 2 (acceptance-criteria grep check before commit)
- **Issue:** A source comment reading "no pageToken parameter anywhere" contained the literal substring the plan's no-pagination gate greps for, self-failing the check despite the code itself never using pagination
- **Fix:** Reworded the comment to "no pagination parameter anywhere" without changing any code
- **Files modified:** CarTube/Search/YouTubeSearchService.swift
- **Verification:** Grep gate passes; full test suite re-ran green (26 tests, 0 failures) after the edit
- **Committed in:** 86fb880 (Task 2 commit)

---

**Total deviations:** 4 auto-fixed (all Rule 1/3 — blocking test/build issues and gate-comment wording)
**Impact on plan:** All four were necessary to reach a fully green, gate-passing `xcodebuild test` run; none expanded scope beyond the plan's stated model/service surface.

## Issues Encountered
None beyond the deviations documented above.

## User Setup Required
None — the service's default initializer already gates cleanly on the still-pending Google shipping key (STATE.md blocker); no test or build step in this plan requires a real key.

## Next Phase Readiness
- Plan 03-03 can build the last-query cache and SRCH-03 fail-closed degrade decision directly on top of `YouTubeSearchService.search(query:)` and `SearchError`
- `MockURLProtocol` is reusable as-is for any future network-adjacent test in the repo
- The `Search/` group remains Foundation-only and CarPlay-free, preserving the swappable/deletable boundary the milestone's Pitfall 8 requires
- No blockers for plan 03-03

---
*Phase: 03-search-core*
*Completed: 2026-08-18*

## Self-Check: PASSED

All key files (SearchResult.swift, YouTubeSearchService.swift, Constants.swift, MockURLProtocol.swift, four fixtures, YouTubeSearchServiceTests.swift, this SUMMARY) and both commit hashes (7fe6f4f, 86fb880) verified present on disk / in git log.
