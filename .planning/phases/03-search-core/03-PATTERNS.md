# Phase 3: Search Core - Pattern Map

**Mapped:** 2026-08-18
**Files analyzed:** 10 (4 created, 2-3 modified, 1 conditional modification, 1 reference-only)
**Analogs found:** 7 / 10

No `CONTEXT.md` or `RESEARCH.md` exists in this phase directory yet; the file list is derived from ROADMAP.md Phase 3 success criteria 1-4, requirements SRCH-01…04, milestone research `.planning/research/ARCHITECTURE.md`, and the phase scope communicated by the orchestrator.

**Codebase state verified at mapping time (2026-08-18):** Phases 1-2 are **not executed** (STATE.md: 0 plans completed). Deployment target is still `14.0` at all 6 pbxproj sites; `CarTube/Info.plist` contains **no** `YOUTUBE_API_KEY` key; no `Secrets.xcconfig` / `Config/` exists; the repo has **zero** `Codable`/`JSONDecoder`/`async`-`await` usage and **zero** test targets. Phase 3 executes after Phase 2, so the planner should assume iOS 16 APIs are available at build time while writing against files that currently still carry Phase 2's pre-severance state.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `CarTube/Search/YouTubeSearchService.swift` (CREATE) | service | request-response | `CarTube/CarTubeApp.swift:55-69` (`checkNewVersions` URLSession pattern) + `CarTube/Util/Utilities.swift:149-179` (`getNowPlaying` Result-completion shape) | role-match |
| `CarTube/Search/SearchResult.swift` (CREATE) | model | transform (decode) | none — `Constants.swift:1-12` is the pure-Foundation file-style analog only | none |
| `CarTube/Search/` quota last-query cache (CREATE, single-slot) | utility / store | CRUD (in-memory) | `CarTube/CarPlay/CarPlaySingleton.swift:14,25,108-115` (`cachedVideo` single-slot get/set/clear triad) | role-match |
| `CarTube/Util/Utilities.swift` (MODIFY: parser becomes shared/testable) | utility | transform | itself — `extractYouTubeVideoID` (`Utilities.swift:19-24`) | exact (self-edit) |
| `PlayOnCarTube/ShareViewController.swift` (CONDITIONAL MODIFY: parser dedupe) | controller (extension) | transform | itself — duplicated `extractVideoID` (`ShareViewController.swift:83-88`) | exact (self-edit) |
| `CarTubeTests/YouTubeSearchServiceTests.swift` + `CarTubeTests/UtilitiesTests.swift` (CREATE) | test | n/a | none — first tests in the repo (TESTING.md confirms no target, no fixtures, no scheme test action) | none |
| `CarTubeTests/Fixtures/*.json` (CREATE) | test fixture | file-I/O | resource-by-name loading convention `CarPlayViewController.swift:52-56` (quoted in `02-PATTERNS.md`) | partial |
| `CarTube.xcodeproj/project.pbxproj` (MODIFY: `Search/` group + unit-test target) | config | n/a | itself (group structure `pbxproj:125-280`) + Phase 1 ruby `xcodeproj` recipe (`01-01-PLAN.md:74-79`) | role-match |
| `CarTube/CarTubeApp.swift` (CONDITIONAL MODIFY: `YouTubeSearchOn` default) | config / entry | n/a | itself — `registerDefaults()` (`CarTubeApp.swift:44-52`) | exact (self-edit) |
| `CarTube/Views/Settings.swift` (CONDITIONAL MODIFY: toggle, if added) | component | CRUD (UserDefaults) | itself — toggle rows (`Settings.swift:37-63`) | exact (self-edit) |
| `CarTube/CarPlay/CarPlaySingleton.swift` (REFERENCE ONLY — fallback target, no modification expected) | facade | request-response | itself — `searchVideo` (`CarPlaySingleton.swift:36-39`) | reference |

The degradation call `CarPlaySingleton.shared.searchVideo(query)` (SRCH-03) lands wherever Phase 3 puts the failure branch — the singleton itself must not grow network code (research Anti-Pattern 2: never embed the URLSession client in the singleton).

---

## Pattern Assignments

### `CarTube/Search/YouTubeSearchService.swift` (service, request-response)

**Analog:** `CarTube/CarTubeApp.swift:55-69` — the only URLSession call site in the repo, plus `Utilities.swift:149-179` for the completion/error shape.

**Networking base pattern to copy** (`CarTubeApp.swift:55-69`):
```swift
func checkNewVersions() {
    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, let url = URL(string: "https://api.github.com/repos/Avangelista/CarTube/releases/latest") {
        let task = URLSession.shared.dataTask(with: url) {(data, response, error) in
            guard let data = data else { return }
            
            if let json = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] {
                ...
            }
        }
        task.resume()
    }
}
```

**Completion/error shape to copy** (`Utilities.swift:149-152,159-178` — `getNowPlaying`, the repo's only `Result`-returning completion; TESTING.md names it the failure-path coverage candidate):
```swift
func getNowPlaying(completion: @escaping (Result<(title: String, artist: String, bundleID: String), Error>) -> Void) {
    ...
    guard let MRMediaRemoteGetNowPlayingInfoPointer = ... else {
        completion(.failure("Error"))
        return
    }
```

**Percent-encoding guard to copy for the query parameter** (`CarPlaySingleton.swift:36-39`):
```swift
func searchVideo(_ search: String) {
    let searchString = YT_SEARCH + search
    guard let safeSearch = searchString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
    loadUrl(safeSearch)
}
```

**Deviations the planner must encode (analog is insufficient as-is):**
1. **No silent `try?`/early-`return` failure paths.** The analog swallows every error (`guard ... else { return }`, `try?`). SRCH-03 requires the caller to *distinguish* HTTP 403 / quota / key-invalid from other failures, so the service needs a typed error surfaced through a `Result` completion (house style per `getNowPlaying`) or a Swift error enum. The repo's existing zero-ceremony error type is `String: LocalizedError` (`CarTube/Extensions/String++.swift:10-12`) — usable for `.failure("quotaExceeded")`-style markers, or a small `SearchError` enum if the planner wants the 403 case testable. Decide once, keep it minimal.
2. **Decode with `Codable`, not `JSONSerialization`.** The analog's dictionary-cast parsing is the pattern to *replace*, not copy — fixture-JSON tests (SRCH-04) need `JSONDecoder` against `SearchResult`. This is the repo's first `Codable` use; no precedent exists to follow (verified by grep).
3. **Key via injection, not direct `Bundle.main` reads.** See Shared Patterns "Info.plist key read" below — the default initializer reads the bundle; a test initializer takes the key (and base URL) as parameters. `TESTING.md` ("What to Mock"): "Network release checks should use a URL protocol stub rather than hitting GitHub" — inject either a `URLSession` (built with a stubbed `URLProtocol`) or the URL string so tests never spend quota.
4. **URL constant convention.** API base URL belongs in `CarTube/Util/Constants.swift` as SCREAMING_SNAKE_CASE next to `YT_HOME`/`YT_EMBED`/`YT_SEARCH` (`Constants.swift:11-13`), not inline in the service.
5. **`import Foundation` only.** The `Search/` group carries no UIKit/WebKit/CarPlay deps (milestone structure + research boundary table). `Constants.swift` (Foundation-only, 13 lines) is the style anchor; do **not** mirror `Utilities.swift`'s `UIKit`/`notify`/`Dynamic` import block.
6. **Quota budget encoded in the API surface, not caller discipline.** SRCH-02: `type=video&maxResults=10`, no pagination parameter exposed, one page per call. The last-query cache is a *separate* holder (service stays stateless) — see next assignment.
7. **Completion vs async/await — decision point.** House convention is completion closures (CONVENTIONS.md "Concurrency"; zero `async`/`await` in repo, verified). After Phase 2's iOS 16 raise, `async` is available and simplifies `XCTest` (`func test...() async throws`). Either is defensible: completion matches every existing call site; async matches test ergonomics. Planner picks one and states it.
8. **Duration needs a second request — flag, don't hide.** `search.list?part=snippet` does not return duration; ROADMAP criterion 1 requires duration in results, which needs a follow-up `videos.list` call (1 unit from the separate 10k pool, per milestone research). Planner decision: two-request shape inside one `search(...)` completion, or Phase 3 ships duration empty and Phase 4 fills it. The phase scope text names only `part=snippet&type=video&maxResults=10` — map this gap explicitly so it isn't discovered at plan time.

---

### `CarTube/Search/SearchResult.swift` (model, transform)

**Analog:** none. First `Codable` type in the repo.

**What to establish (planner encodes as the convention):**
- `struct SearchResult: Codable` with the fields the surface needs: `videoId`, `title`, `channel`, `thumbnail`, `duration`. Nested `CodingKeys`/response envelope types (`SearchResponse { items: [...] }`, snippet/thumbnail nesting) live in the service file or beside it — keep the public surface the flat five-field struct so Phase 4's UI never touches Data API shapes.
- **Dynamic-free, Foundation-only** — the milestone severs the `Dynamic` SPM dependency (Phase 2), and this file proves the new convention. No `UIKit` (no `UIImage`; thumbnail is a `URL`/`String`).
- File header comment in the repo style (`Utilities.swift:1-6`, `Constants.swift:1-6`): file/module name comment block.
- Four-space indent, PascalCase type, camelCase members (CONVENTIONS.md "Naming") — match `Constants.swift`'s minimal layout.

The **anti-analog** to avoid is `JSONSerialization` dictionary-casting (`CarTubeApp.swift:59`): no `as? [String: Any]` chains anywhere in Search code.

---

### Last-query cache (single-slot store)

**Analog:** `CarTubeSingleton`'s `cachedVideo` — the codebase's one precedent for a one-slot buffer with explicit invalidation.

`CarPlaySingleton.swift:14` (state), `:25` (fill on precondition), `:108-115` (get/clear pair):
```swift
private var cachedVideo: String?

    } else if controller == nil {
        self.cachedVideo = urlString
    ...

    func getCachedVideo() -> String? {
        return cachedVideo
    }
    
    func clearCachedVideo() {
        cachedVideo = nil
    }
```

SRCH-02's cache is the same shape at query granularity: hold `(query, results)`; a repeat of the identical query returns the cached page without a network call. Because the service must stay stateless, this is a tiny separate type (or two properties on the Phase 3 entry point that becomes Phase 4's `SearchCoordinator`). Keep the triad shape: store-on-submit, read-before-network, clear-on-new-query. No `UserDefaults` — research state-management table: "results are throwaway, the query is not stored" (avoids the settings three-file contract entirely).

---

### `CarTube/Util/Utilities.swift` (utility, transform — parser test coverage)

**Analog:** itself. `extractYouTubeVideoID` is one of SRCH-04's two named test subjects, and it is currently the cleanest pure function in the repo.

`Utilities.swift:14-24`:
```swift
/// Check if the given string is a valid YouTube URL
func isYouTubeURL(_ url: String) -> Bool {
    return extractYouTubeVideoID(url) != nil
}

/// Given a URL string, extract the YouTube video ID
func extractYouTubeVideoID(_ url: String) -> String? {
    let regex = try! NSRegularExpression(pattern: "(?:youtube(?:-nocookie)?\\.com\\/(?:[^\\/\\n\\s]+\\/\\S+\\/|(?:v|e(?:mbed)?)\\/|\\S*?[?&]v=)|youtu\\.be\\/)([a-zA-Z0-9_-]{11})")
    guard let match = regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)) else { return nil }
    guard let range = Range(match.range(at: 1), in: url) else { return nil }
    return String(url[range])
}
```

Test-first fixture classes to derive from TESTING.md's candidate list: mobile/desktop/watch/embed/youtu.be/shorts URLs, non-YouTube URLs, plain text, empty string, IDs with `-_` characters. Minimal change only if a test forces it — CONVENTIONS.md's *recommended* (not yet applied) improvements are: build the regex once rather than per call, and replace `try!` with a non-failing construction. The function already returns `nil` for no-match, so it needs no signature change to be testable from a test target that compiles the app sources.

---

### `PlayOnCarTube/ShareViewController.swift` (conditional modify — parser dedupe)

**Analog:** itself. The identical regex is duplicated at `ShareViewController.swift:83-88` (`extractVideoID(from:)`), byte-for-byte the same pattern as `Utilities.swift:20-23`.

"Shared URL parsing" in SRCH-04 is satisfied by testing `extractYouTubeVideoID` alone; whether the extension switches to the shared symbol is a **planner decision**, not a requirement: the extension is a separate target (would need the file added to its Sources phase in pbxproj — extra mutation risk for zero Phase 3 value). Default: leave the duplication, note it as tech debt. If deduped, the only edit is replacing the private method body with a call into the shared helper plus a pbxproj target-membership change for `Utilities.swift` — but `Utilities.swift` imports `UIKit`/`notify` (fine for an extension) and will still be mid-severance from Phase 2; **recommend deferring**.

---

### `CarTubeTests/*` (test, first in repo)

**Analog:** none in code. Two out-of-repo anchors:

1. **pbxproj mutation recipe** — Phase 1 `01-01-PLAN.md:74-79` establishes the house method: throwaway ruby script using the installed `xcodeproj` gem (1.28.1), mutate, save, **delete the script** (never committed). Phase 2's plan applies the same recipe. Test-target creation is the biggest pbxproj mutation yet; use the same gem, not hand-editing:
   - new `PBXNativeTarget` `productType = "com.apple.product-type.bundle.unit-test"` (mirroring the two existing `PBXNativeTarget` blocks at `pbxproj:283-316` for shape)
   - its own `PBXSourcesBuildPhase` + `PBXFrameworksBuildPhase` + `PBXResourcesBuildPhase` (fixtures go in Resources; existing phases at `pbxproj:387-421` show the shape)
   - `PBXContainerItemProxy`/`PBXTargetDependency` linking CarTube → tests (CarTube's existing `dependencies` array is at `pbxproj:294-296`)
   - Debug + Release `XCBuildConfiguration`s + a `buildConfigurationList` (copy the shape of any existing target's list, e.g. `pbxproj:285`)
   - new top-level `CarTubeTests` group beside `PlayOnCarTube` in the root group children (`pbxproj:125-137`) and a `CarTubeTests.xctest` product in the Products group (`pbxproj:135-140`)
   - `TEST_HOST`/`BUNDLE_LOADER` only if the tests need the app runtime — pure parser/decoder tests don't; `@testable import CarTube` needs just the dependency. Prefer no TEST_HOST (faster, no simulator-app boot).
2. **Scheme gap — must be handled, nothing to copy.** Verified: `CarTube.xcodeproj/xcshareddata/` **does not exist**; only user-local auto-schemes under `xcuserdata/`. `xcodebuild test -scheme CarTube` will not run a test target that no scheme's TestAction includes. The plan must create a shared scheme (the `xcodeproj` gem writes `xcshareddata/xcschemes/CarTube.xcscheme` with a TestAction naming `CarTubeTests`) or the SRCH-04 verification command has nothing to run. This is the single highest-risk scaffold item — call it out as its own task with its own verify step.

**Verify command shape** (follows Phase 1's verify style, `01-01-PLAN.md:87`):
```bash
xcodebuild -project CarTube.xcodeproj -scheme CarTube -destination 'platform=iOS Simulator,name=iPhone Air' test 2>&1 | tail -5
```

**Fixture loading convention** — resource-by-name, copied from the app's script loading (`CarPlayViewController.swift:52-56`, as quoted in `02-PATTERNS.md`):
```swift
guard let scriptPath = Bundle.main.path(forResource: item, ofType: "js"),
      let scriptSource = try? String(contentsOfFile: scriptPath) else { return }
```
Tests use the same `Bundle(for:)` + `path(forResource:ofType:)` shape (bundle = test bundle, not `Bundle.main`): fixture JSON lives in `CarTubeTests/Fixtures/`, is added to the test target's Resources phase, and is decoded by the same `JSONDecoder` path the service uses — one real captured `search.list` response (redacted key-free; the response never contains the key) covers happy path, plus a minimal 403-error-shaped case and an empty-items case. Keep fixtures small (TESTING.md: "keep fixture JSON/text minimal").

**Naming/layout:** `CarTubeTests/YouTubeSearchServiceTests.swift`, `CarTubeTests/UtilitiesTests.swift`; `final class ...Tests: XCTestCase`; one test method per fixture class; no mocking framework (TESTING.md lists none — and none needed: decoder + parser are pure).

---

### `CarTube.xcodeproj/project.pbxproj` (config)

**Analog:** itself — group structure — plus the ruby recipe above.

- New `Search` group mirrors the existing flat per-directory pattern: `isa = PBXGroup`, children = the two new `.swift` files, `path = Search`, listed inside the `CarTube` group's children array (`pbxproj:141-158`, alongside `CarPlay`, `Util`, `Views`). Each file also needs a `PBXBuildFile` entry and a slot in the CarTube target's `PBXSourcesBuildPhase`.
- All app-source additions go to the **CarTube target only** — not PlayOnCarTube (pattern: every existing Swift file is single-target).
- Test-target scaffold: previous section.
- Remember Phase 2 owns the deployment-target/Dynamic edits concurrently planned against this same file — sequence pbxproj mutations one phase at a time, re-grep before editing (Phase 2's plan already maps exact line numbers that will shift).

### `CarTube/CarTubeApp.swift` (conditional — `YouTubeSearchOn` default)

**Analog:** itself — `registerDefaults()` (`CarTubeApp.swift:44-52`):
```swift
func registerDefaults() {
    UserDefaults.standard.register(defaults: [
        "SponsorBlockOn": false,
        "AgeRestrictBypassOn": false,
        "AdBlockerOn": false,
        "Zoom": 80,
        "ScreenPersistenceOn": true,
        "LockScreenDimmingOn": true
    ])
}
```
If a feature toggle is added this phase: `"YouTubeSearchOn": true` joins this dictionary — but see Shared Patterns for the mandatory three-file contract before deciding the toggle belongs in Phase 3 at all (SRCH-01..04 do not name a user-visible toggle; the quota budget is enforced in code, not a setting). Planner decision: add only if Phase 3 ships any user-facing search entry; otherwise defer to Phase 4.

### `CarTube/Views/Settings.swift` (conditional — toggle row, only if `YouTubeSearchOn` added)

**Analog:** itself — sibling toggle rows (`Settings.swift:38-42`):
```swift
Section(footer: Text("Block ads in videos. If you experience issues with playback, try disabling this option.")) {
    Toggle(isOn: $adBlockerOn) {
        Text("Block Ads (Beta)")
    }
}
```
Follow the row verbatim: `@State` initialized from `UserDefaults.standard.bool(forKey:)` (`Settings.swift:12-17`), write in `saveSettings()` (`Settings.swift:19-27`), footer explains the quota trade-off in plain language. Do not touch the `exitGracefully()` line — Phase 2 owns its replacement.

---

## Shared Patterns

### Info.plist key read (SRCH-01 key consumption)

**Existing usage (both sites):** full-dictionary subscript — `CarTubeApp.swift:56`, `ContentView.swift:42`:
```swift
Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
```
**Designated Phase 3 API** — `01-01-PLAN.md:159` states the build setting is "consumed by Phase 3 via `Bundle.main.object(forInfoDictionaryKey:)`":
```swift
let key = Bundle.main.object(forInfoDictionaryKey: "YOUTUBE_API_KEY") as? String
```
Differences the planner should note: `object(forInfoDictionaryKey:)` reads one key without materializing the dictionary and is Apple's documented accessor for exactly this; it returns `nil` (not the literal `"$(YOUTUBE_API_KEY)"` unresolved string) only when the key is absent — a missing/unsubstituted build setting surfaces as the literal `$(...)` string, so the guard should treat empty, `nil`, *and* a `$(`-prefixed value as "not configured" → immediate degrade path. **Dependency:** the key itself does not exist in `CarTube/Info.plist` until Phase 1 plan 01-01 lands; Phase 3 must not re-add it, only consume it. For testability, read it in the service's default initializer only; tests inject the key directly.

### Settings-key contract (applies only if `YouTubeSearchOn` is added)

Three sites updated together (CONVENTIONS.md "Naming"; verified for every existing key):
1. **Registration** — `CarTubeApp.swift:44-52` (`registerDefaults`)
2. **State + write** — `Settings.swift:12-17` (`@State` init) and `Settings.swift:19-27` (`saveSettings`)
3. **Consumption** — the gate read (for search, the Phase 3 entry point / Phase 4 coordinator)
Exact PascalCase string literal `"YouTubeSearchOn"` in all three. Post-phase grep check: the key must appear in exactly these files, matching how `SponsorBlockOn` etc. behave today.

### Fail-closed degradation (SRCH-03)

**Target:** `CarPlaySingleton.searchVideo` (`CarPlaySingleton.swift:36-39`) — unchanged, called on failure:
```swift
CarPlaySingleton.shared.searchVideo(query)
```
The decision logic guarding it follows the codebase's precondition-check-then-route shape — `loadUrl`'s if/else chain (`CarPlaySingleton.swift:21-28`) and `searchVideo`'s own `guard` are the stylistic templates. Order per research Pattern 3: key missing/invalid → 403/quota → both fall through to `searchVideo(query)`; only an empty *successful* result is a "no results" state (Phase 4's inline row — out of scope here). This chain is fixture-testable without CarPlay if the branch lives in a pure function taking `(key, response)` → `Action`; keep the singleton call as the thin edge.

### Networking + concurrency conventions (applies to the service)

- `URLSession.dataTask` with completion closure; parsing may run on the background queue (`CarTubeApp.swift:57-68` is the exemplar); anything that will touch UI hops to main (Phase 3 has no UI — the service never dispatches to main at all).
- Never embed networking in `CarPlaySingleton` (research Anti-Pattern 2); `Search/` never imports `CarPlay/*`.

### Error surface (applies to service + tests)

- Lightweight: `String: LocalizedError` (`String++.swift:10-12`) or a small enum — no error hierarchy, no alerts from the service layer (alerts are UIKit-adjacent and live with callers).
- The 403/quota/key distinction must survive to the caller as data — that is what makes SRCH-03 testable.

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `CarTube/Search/SearchResult.swift` | model | transform | First `Codable`/`JSONDecoder` type in the repo (verified by grep: zero matches). Convention to establish: flat public struct, Foundation-only, nested API-envelope types private. `JSONSerialization` usage (`CarTubeApp.swift:59`) is the pattern to avoid, not copy. |
| `CarTubeTests/*.swift` (test files) | test | n/a | No test target, no `XCTest` import, no fixtures anywhere (TESTING.md; verified: `xcshareddata/` absent, no `*Tests.swift`). Use standard `XCTestCase` shape; no in-repo precedent. |
| Shared scheme with TestAction | config | n/a | Only user-local auto-schemes exist (`xcuserdata/*/xcschemes/`); `xcodebuild test` needs a scheme whose TestAction includes `CarTubeTests` — must be created (ruby `xcodeproj` gem or Xcode) as part of the test-target scaffold task. |
| `CarTube/Search/YouTubeSearchService.swift` (partially) | service | request-response | URLSession *call shape* has an analog (`CarTubeApp.swift:55-69`) but the analog swallows errors and dictionary-casts — both are precisely what SRCH-03/04 forbid. Treat the analog as structure-only; error typing, Codable decoding, and key injection are all new convention (see deviations 1-3). |

## Metadata

**Analog search scope:** `CarTube/` (all Swift/Obj-C/headers/plists — 21 source files), `PlayOnCarTube/`, `CarTube.xcodeproj/project.pbxproj` (741 lines, 2 targets, group structure), repo root (scripts), `.planning/phases/01-*` + `02-*` (ruby-xcodeproj recipe, resource-loading quote, gate conventions), `.planning/codebase/*` (CONVENTIONS, TESTING), `.planning/research/ARCHITECTURE.md` (milestone structure)
**Files scanned:** 26 source/config files + 5 planning artifacts; grep across all `.swift/.m/.h/.pbxproj` for `Codable|JSONDecoder|async|XCTest|forInfoDictionaryKey|Secrets.xcconfig`
**Pattern extraction date:** 2026-08-18
