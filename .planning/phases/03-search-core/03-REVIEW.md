---
phase: 03-search-core
reviewed: 2026-08-18T23:18:00Z
depth: deep
files_reviewed: 17
files_reviewed_list:
  - CarTube.xcodeproj/project.pbxproj
  - CarTube.xcodeproj/xcshareddata/xcschemes/CarTube.xcscheme
  - CarTube/Search/LastQueryCache.swift
  - CarTube/Search/SearchFallback.swift
  - CarTube/Search/SearchResult.swift
  - CarTube/Search/YouTubeSearchService.swift
  - CarTube/Util/Constants.swift
  - CarTube/Util/Utilities.swift
  - CarTubeTests/Fixtures/error-403-quota.json
  - CarTubeTests/Fixtures/search-response-empty.json
  - CarTubeTests/Fixtures/search-response.json
  - CarTubeTests/Fixtures/videos-response.json
  - CarTubeTests/LastQueryCacheTests.swift
  - CarTubeTests/MockURLProtocol.swift
  - CarTubeTests/SearchFallbackTests.swift
  - CarTubeTests/UtilitiesTests.swift
  - CarTubeTests/YouTubeSearchServiceTests.swift
  - docs/runbooks/google-dev-key.md
findings:
  critical: 2
  warning: 4
  info: 4
  total: 10
status: issues_found
---

# Phase 03: Code Review Report

**Reviewed:** 2026-08-18T23:18:00Z
**Depth:** deep
**Files Reviewed:** 17
**Status:** issues_found

## Summary

Reviewed the YouTube Data API v3 search client (`YouTubeSearchService`), the single-slot `LastQueryCache` actor, the pure `SearchFallback` decision function, `SearchResult` Codable envelopes, supporting constants/utilities, the fixture-backed test suite, the Xcode project/scheme wiring, and the dev-key runbook.

The happy path, quota-budget shaping (single page, no pagination param, minimal `maxResults=10`), key-gating (`normalizedKey`), and query-value percent-encoding are all sound and covered by tests. Project file wiring (target membership, Resources build phase for fixtures) is correct.

However, two defects undermine the phase's stated goal of a **fail-closed** search path:

1. `decodeDurationsByVideoId` will crash the app (not degrade) if the `videos.list` response ever contains a duplicate video ID, because it builds the dictionary with `Dictionary(uniqueKeysWithValues:)`.
2. Decode failures (`DecodingError`) from a 200 response with an unexpected body (e.g. a captive-portal HTML page, or a Google API schema change) are never converted to `SearchError`, so they can escape the typed-error contract that `SearchFallback.decide(Result<[SearchResult], SearchError>, ...)` is built around.

Both are exactly the kind of untrusted-external-data assumptions that a "fail-closed" contract is supposed to guard against — a crash or an unhandled error type is a strictly worse outcome than the `.other`/webview-degrade path this phase otherwise builds carefully.

Additional robustness and quality issues are listed below.

## Critical Issues

### CR-01: Duplicate video ID in `videos.list` response crashes instead of degrading

**File:** `CarTube/Search/SearchResult.swift:70-73`
**Issue:** `decodeDurationsByVideoId` builds the duration lookup with:
```swift
return Dictionary(uniqueKeysWithValues: envelope.items.map { ($0.id, $0.contentDetails.duration) })
```
`Dictionary(uniqueKeysWithValues:)` traps with a fatal error if any key repeats. The `id` values come directly from the `videos.list` HTTP response body — untrusted, external data that `YouTubeSearchService.search` requests using an `id` parameter built from `results.map(\.videoId)` (`YouTubeSearchService.swift:65-69`). If a search response ever contains the same `videoId` twice (documented YouTube edge cases include a video appearing as both a regular and a live/duplicate listing), or if the `videos.list` endpoint echoes back a duplicate for a duplicated `id` in the request, this line crashes the whole app rather than falling through to `SearchError`/`SearchFallback.degradeToWebviewSearch`. That is the opposite of this phase's fail-closed goal — a crash brings down CarPlay entirely, whereas the whole point of `SearchFallback` is to never let a search failure become worse than "open the webview instead."
**Fix:**
```swift
static func decodeDurationsByVideoId(_ data: Data) throws -> [String: String] {
    let envelope = try JSONDecoder().decode(VideoResponseEnvelope.self, from: data)
    var durations: [String: String] = [:]
    for item in envelope.items {
        durations[item.id] = item.contentDetails.duration
    }
    return durations
}
```
(or `Dictionary(envelope.items.map { ($0.id, $0.contentDetails.duration) }, uniquingKeysWith: { first, _ in first })`)

### CR-02: JSON decode errors escape the `SearchError` contract on a 200 response

**File:** `CarTube/Search/YouTubeSearchService.swift:60-76`
**Issue:** `checkForAPIError` only inspects the HTTP status code; on any `200`, execution proceeds straight into `SearchResult.decodeSearchResponse(searchData)` (line 62) and later `SearchResult.decodeDurationsByVideoId(videosData)` / `decodeSearchResponse(searchData, durationsByVideoId:)` (lines 75-76). Both call `JSONDecoder().decode`, which throws `DecodingError` — a type that is **not** `SearchError` and does not conform to it. `search(query:)` is declared as plain `async throws` (Swift 5 language mode per `SWIFT_VERSION = 5.0` in the project settings — no typed throws), so a malformed 200 body (a very real scenario on mobile networks: captive Wi-Fi portals frequently return HTTP 200 with an HTML login page instead of the requested payload; a Google API schema drift would have the same effect) propagates as a raw `DecodingError`. The entire downstream design in this phase is built around exhaustively-typed `SearchError` — `SearchFallback.decide` only accepts `Result<[SearchResult], SearchError>`, and the `SearchFallback.swift` CALLER CONTRACT comment describes Phase 4's coordinator consuming that typed result. If Phase 4's coordinator does `catch let error as SearchError` without a catch-all, a decode failure will crash or silently propagate instead of triggering `.degradeToWebviewSearch` — defeating the fail-closed guarantee for a failure mode that is common in a car's variable-connectivity environment.
**Fix:** Wrap both decode call sites and rethrow as `SearchError.other(...)`:
```swift
private static func decode<T>(_ decode: () throws -> T) throws -> T {
    do {
        return try decode()
    } catch let error as SearchError {
        throw error
    } catch {
        throw SearchError.other("Malformed API response: \(error.localizedDescription)")
    }
}
```
and call sites become `try Self.decode { try SearchResult.decodeSearchResponse(searchData) }`, etc. This guarantees every throw out of `search(query:)` is a `SearchError`, matching the contract `SearchFallback` is built on.

## Warnings

### WR-01: Cancelled in-flight requests are misreported as hard failures

**File:** `CarTube/Search/YouTubeSearchService.swift:79-85`
**Issue:**
```swift
private func performRequest(_ url: URL) async throws -> (Data, URLResponse) {
    do {
        return try await session.data(from: url)
    } catch {
        throw SearchError.other(error.localizedDescription)
    }
}
```
This catch-all also converts Swift Concurrency's `CancellationError` (and `URLError(.cancelled)`, thrown when the calling `Task` is cancelled — e.g. a typeahead search UI cancelling a stale in-flight request when the user types another character, which is exactly the scenario `LastQueryCache` exists to support) into `SearchError.other(...)`. `SearchFallback.decide` unconditionally maps every `.failure` case to `.degradeToWebviewSearch`, so an intentional cancellation — not a real error — will trigger a spurious webview fallback. This also violates the Swift Concurrency convention of letting `CancellationError` propagate untouched so callers can distinguish "cancelled" from "failed."
**Fix:**
```swift
private func performRequest(_ url: URL) async throws -> (Data, URLResponse) {
    do {
        return try await session.data(from: url)
    } catch is CancellationError {
        throw CancellationError()
    } catch let urlError as URLError where urlError.code == .cancelled {
        throw urlError
    } catch {
        throw SearchError.other(error.localizedDescription)
    }
}
```
and have the eventual caller treat cancellation as a silent no-op rather than routing it through `SearchFallback`.

### WR-02: No guard against empty/whitespace query before spending search.list quota

**File:** `CarTube/Search/YouTubeSearchService.swift:50-57`
**Issue:** `search(query:)` performs no validation on `query` before building the request and spending a `search.list` call. Per this file's own comment (line 16, "Structural quota budget") and `docs/runbooks/google-dev-key.md`'s emphasis on the 100-unit/day shared bucket, an accidental blank or whitespace-only query (plausible from a live-search UI mid-keystroke, or a caller bug) still burns a full 100-unit `search.list` call for a meaningless request — 100% of the daily budget in one call.
**Fix:** Guard early:
```swift
public func search(query: String) async throws -> [SearchResult] {
    guard let apiKey = self.apiKey else { throw SearchError.apiKeyMissing }
    let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedQuery.isEmpty else { return [] }
    ...
}
```

### WR-03: `percentEncodedQuery` fallback can assign un-encoded delimiters

**File:** `CarTube/Search/YouTubeSearchService.swift:92-96`
**Issue:**
```swift
let encodedValue = value.addingPercentEncoding(withAllowedCharacters: Self.queryValueAllowedCharacters) ?? value
```
If `addingPercentEncoding` ever returns `nil` (practically never for a valid Swift `String`, but not contractually guaranteed), the raw, un-encoded `value` — potentially still containing `&`, `=`, `+`, or other characters — is assigned directly into `components.percentEncodedQuery` at line 96. Foundation's `percentEncodedQuery` setter expects an already-valid percent-encoded query string; assigning one with unescaped reserved characters is documented as producing undefined/invalid results and can trap. This branch is untested and silently masks a failure instead of failing closed.
**Fix:** Treat encoding failure as an explicit error instead of silently falling back to the raw value:
```swift
guard let encodedValue = value.addingPercentEncoding(withAllowedCharacters: Self.queryValueAllowedCharacters) else {
    throw SearchError.other("Failed to encode query value for \(name)")
}
```

### WR-04: Tautological assertion gives false confidence in concurrency test

**File:** `CarTubeTests/LastQueryCacheTests.swift:51-58`
**Issue:**
```swift
func testConcurrentAccessFromTwoTasksDoesNotCrash() async {
    let cache = LastQueryCache()
    async let first: Void = cache.store(query: "lofi", results: [makeResult(id: "abc12345678")])
    async let second: Void = cache.store(query: "jazz", results: [makeResult(id: "xyz98765432")])
    _ = await (first, second)
    let cached = await cache.cachedResults(for: "jazz")
    XCTAssertTrue(cached == nil || cached != nil)
}
```
`XCTAssertTrue(cached == nil || cached != nil)` is always true regardless of what `cached` actually is — this assertion can never fail. The test name and comment imply it verifies "does not crash," but XCTest would already fail the test on a crash without this assertion; as written, the assertion contributes zero verification value and could mask a real regression (e.g., if `cachedResults` started throwing or hanging in a way that doesn't trap).
**Fix:** Assert something meaningful about the actor's actual last-write-wins semantics, e.g.:
```swift
XCTAssertTrue(cached == nil || cached == [makeResult(id: "xyz98765432")])
```
which actually encodes the two valid outcomes (either task finished last) instead of a tautology.

## Info

### IN-01: Search response JSON is decoded twice per call

**File:** `CarTube/Search/YouTubeSearchService.swift:62, 75-76`
**Issue:** `SearchResult.decodeSearchResponse(searchData)` is called once (line 62) purely to check `results.isEmpty`, then the identical `searchData` is decoded again at line 76 with `durationsByVideoId` filled in. This is redundant JSON parsing of the same payload for every search.
**Fix:** Decode once, keep the intermediate envelope/results, and enrich durations onto the already-decoded array instead of re-parsing.

### IN-02: `videos.list` requests and decodes an unused `snippet` part

**File:** `CarTube/Search/YouTubeSearchService.swift:68`, `CarTube/Search/SearchResult.swift:39-50`
**Issue:** The videos request uses `fixedQuery: "part=contentDetails,snippet"`, and `VideoItemEnvelope` decodes a full `Snippet` (`title`, `channelTitle`). Only `contentDetails.duration` is ever read (`decodeDurationsByVideoId`, `SearchResult.swift:70-73`); the decoded `Snippet` fields are dead weight — parsed but discarded on every call.
**Fix:** Drop `snippet` from the `videos.list` `part` value and remove `VideoItemEnvelope.Snippet` if it's truly unused, per YAGNI.

### IN-03: Partial test coverage of the 403 reason-mapping switch

**File:** `CarTubeTests/YouTubeSearchServiceTests.swift` (whole file), `CarTube/Search/YouTubeSearchService.swift:117-127`
**Issue:** `checkForAPIError`'s `switch reason` has four branches (`quotaExceeded`/`rateLimitExceeded`/`dailyLimitExceeded` → `.quotaExceeded`, `keyInvalid`/`badRequest` → `.apiKeyInvalid`, and `default` → `.other("HTTP 403")`), but only the `quotaExceeded` case (`test403QuotaResponseMapsToSearchErrorQuotaExceeded`) is exercised by a test. The `.apiKeyInvalid` mapping and the 403-with-unrecognized-reason default path have no fixture or test coverage.
**Fix:** Add a fixture (e.g. `error-403-key-invalid.json`) and a test asserting `SearchError.apiKeyInvalid` for `reason: "keyInvalid"`.

### IN-04: `normalizedKey` accepts whitespace-only keys as "present"

**File:** `CarTube/Search/YouTubeSearchService.swift:45-48`
**Issue:** `normalizedKey` only checks `!key.isEmpty` and the `$(` xcconfig-placeholder prefix; a key consisting solely of whitespace (e.g. accidental trailing newline from a copy-paste into `Secrets.xcconfig`) passes the gate as "present" and triggers a real network call that will fail with an HTTP 400, surfacing as a generic `SearchError.other("HTTP 400")` rather than the more diagnostic `.apiKeyMissing`/`.apiKeyInvalid`.
**Fix:** `guard let key, !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !key.hasPrefix("$(") else { return nil }`

---

_Reviewed: 2026-08-18T23:18:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_
