---
phase: 04-carplay-search-surface
reviewed: 2026-08-19T00:00:00Z
depth: deep
files_reviewed: 10
files_reviewed_list:
  - CarTube.xcodeproj/project.pbxproj
  - CarTube/CarPlay/CarPlaySingleton.swift
  - CarTube/CarPlay/CarPlayViewController.swift
  - CarTube/CarPlay/SearchResultsViewController.swift
  - CarTube/Search/DurationFormatter.swift
  - CarTube/Search/SearchCoordinator.swift
  - CarTube/Views/Debug.swift
  - CarTube/Views/KeyboardView.swift
  - CarTubeTests/DurationFormatterTests.swift
  - CarTubeTests/SearchCoordinatorTests.swift
findings:
  critical: 1
  warning: 4
  info: 3
  total: 8
status: issues_found
---

# Phase 04: Code Review Report

**Reviewed:** 2026-08-19T00:00:00Z
**Depth:** deep
**Files Reviewed:** 10
**Status:** issues_found

## Summary

Reviewed the CarPlay native search-results overlay and its wiring to the Phase 3 search backend (`SearchCoordinator`, `YouTubeSearchService`, `SearchFallback`, `LastQueryCache` were read for cross-boundary context but are out of this phase's file scope and not re-flagged here). `SearchCoordinator`'s generation-guard, fallback-before-degrade ordering, and cache-hit short-circuit are all correctly implemented and match their test coverage — traced the full call chain from `KeyboardView.submitSearch()` → `CarPlaySingleton.submitSearchQuery` → `SearchCoordinator.search`/`run` → `presenter`/`degrade`/`dismissOverlay` closures and found the concurrency/actor-isolation boundaries sound.

The one blocker is a genuine, always-reproducible functional defect: `KeyboardView`'s `typedQuery` mirror buffer introduced in this phase is never cleared, so every search after the first one is submitted with stale text prepended. This was not caught by `SearchCoordinatorTests` because those tests construct `SearchCoordinator` directly and never exercise `KeyboardView`. The remaining findings are lower-severity coupling/robustness issues in the new `CarPlayViewController` wiring (an unguarded force-unwrap fed by API-sourced data, and a fragile toggle-based keyboard reopen).

`DurationFormatter` and its tests are correct and match the ISO-8601 subset actually returned by the Data API. `project.pbxproj` changes are structurally consistent (every new file has matching `PBXFileReference`/`PBXBuildFile`/Sources-phase entries) and no secrets are committed (`Secrets.xcconfig` is gitignored).

## Critical Issues

### CR-01: `typedQuery` is never reset, so every search after the first concatenates onto old text

**File:** `CarTube/Views/KeyboardView.swift:40, 56-70`
**Issue:** `KeyboardView` is created once in `CarPlayViewController.viewDidLoad()` via a `UIHostingController` whose visibility is only toggled (`keyboardView.isHidden`); the SwiftUI view and its `@State` never get recreated for the life of the CarPlay session. `typedQuery` is appended to on every keypress (`sendKey`) and trimmed on backspace, but nothing ever sets it back to `""`:

```swift
func submitSearch() {
    dismiss()
    CarPlaySingleton.shared.submitSearchQuery(typedQuery)
}
```

After the first search is submitted, `typedQuery` still holds the full previously-typed string. The next time the keyboard is opened and the user types a new query, keystrokes are appended onto the old string (`typedQuery.append(input)`), and the *concatenation* of the old and new query is what gets submitted to `SearchCoordinator`. The same problem occurs if the user opens the keyboard, types something, and dismisses it via the chevron key without searching — the abandoned text is never cleared and reappears prepended to the next query. This is a 100%-reproducible logic bug for the second and every subsequent search in a session, and it went untested because `SearchCoordinatorTests` never exercises `KeyboardView` (it constructs `SearchCoordinator` directly with fixture queries).
**Fix:** Clear the buffer wherever the keyboard is closed (covers both the explicit dismiss chevron and the submit path, since `submitSearch()` calls `dismiss()`):
```swift
func dismiss() {
    CarPlaySingleton.shared.toggleKeyboard()
    typedQuery = ""
}
```

## Warnings

### WR-01: `onSelect` feeds API-sourced `videoId` into a force-unwrapped `URL(string:)`

**File:** `CarTube/CarPlay/CarPlayViewController.swift:161-163` (call site), `CarTube/CarPlay/CarPlayViewController.swift:300-305` (crash site)
**Issue:** The new `onSelect` closure wired up in this phase does:
```swift
onSelect: { [weak self] videoId in
    CarPlaySingleton.shared.loadUrl(YT_EMBED + videoId)
    ...
}
```
`videoId` originates from `SearchItemEnvelope.ID.videoId`, decoded straight from the YouTube Data API JSON response, with no sanitization. `loadUrl(_:)` does:
```swift
func loadUrl(_ urlString: String) {
    let youtubeURL = URL(string: urlString)!
    ...
}
```
`loadUrl`'s force-unwrap predates this phase, but this phase adds the first call site that feeds it untrusted, network-sourced data instead of an app-internal constant string. If the API ever returns a `videoId` containing characters `URL(string:)` can't parse as-is (e.g. certain unicode, or a malformed/adversarial response if the API key or endpoint were ever compromised/mocked), this force-unwrap crashes the app on the CarPlay display.
**Fix:** Guard instead of force-unwrapping, or percent-encode the video ID before concatenation:
```swift
func loadUrl(_ urlString: String) {
    guard let youtubeURL = URL(string: urlString) else { return }
    webView.load(URLRequest(url: youtubeURL))
}
```

### WR-02: `onRetry` assumes the keyboard is already hidden — `toggleKeyboard()` is a toggle, not a "show"

**File:** `CarTube/CarPlay/CarPlayViewController.swift:168-171`
**Issue:**
```swift
onRetry: { [weak self] in
    CarPlaySingleton.shared.dismissSearchResults()
    CarPlaySingleton.shared.toggleKeyboard()
}
```
This only behaves correctly because, in the sole current entry point (`KeyboardView.submitSearch()` → `dismiss()` → `toggleKeyboard()` hides the keyboard synchronously *before* `submitSearchQuery` is even called), the keyboard is guaranteed hidden by the time results can show. But `Debug.runRealFunnelIfKeyConfigured()` calls `SearchCoordinator.shared.search(...)` directly, bypassing that dismiss step entirely; if that debug action is triggered while genuinely connected to CarPlay (the comment in `Debug.swift` only says it no-ops on the phone screen, not that it's safe when a controller is attached) and the keyboard happens to be visible, tapping "retry" on an empty-results row would hide the keyboard instead of showing it. The coupling relies on an undocumented invariant about caller state rather than an explicit API.
**Fix:** Expose an explicit `showKeyboard()` (idempotent) alongside the existing toggle, and call that from `onRetry` instead of relying on toggle semantics.

### WR-03: Unused `[weak self]` capture in all three `resultsController` closures

**File:** `CarTube/CarPlay/CarPlayViewController.swift:161-172`
**Issue:** `onSelect`, `onClose`, and `onRetry` each capture `[weak self]` but never reference `self` in their bodies — every call goes through `CarPlaySingleton.shared` instead. This produces a compiler warning ("variable 'self' was never used") and signals boilerplate copied from a pattern that did need `self` elsewhere.
**Fix:** Drop the unused capture lists:
```swift
onSelect: { videoId in
    CarPlaySingleton.shared.loadUrl(YT_EMBED + videoId)
    CarPlaySingleton.shared.dismissSearchResults()
},
```

### WR-04: Keyboard show/hide + webview-resize logic duplicated between `toggleKeyboard()` and the JS message handler

**File:** `CarTube/CarPlay/CarPlayViewController.swift:308-316` vs `330-339`
**Issue:** `toggleKeyboard()` and `userContentController(_:didReceive:)` both independently set `keyboardView.isHidden` and resize `webView.frame.size.height` by `keyboardView.frame.size.height`. This isn't newly introduced by this phase, but the new `resultsController` overlay now also depends on keyboard-visibility state being consistent (per WR-02), which raises the cost of the two code paths drifting apart. A future change to one (e.g. accounting for safe-area insets) silently won't apply to the other.
**Fix:** Factor both into a single `private func setKeyboardVisible(_ visible: Bool)` helper used by both call sites.

## Info

### IN-01: Magic number `8` for max displayed results has no named constant

**File:** `CarTube/CarPlay/SearchResultsViewController.swift:100`
**Issue:** `results.isEmpty ? 1 : min(results.count, 8)` hardcodes the display cap inline with no explanation of why 8 (vs. the API's `maxResults=10` in `YouTubeSearchService`).
**Fix:** `private static let maxDisplayedResults = 8` with a one-line comment on the rationale (e.g. CarPlay list scroll ergonomics).

### IN-02: `Debug.swift`'s `forceScriptOn` alert text doesn't reflect the actual pattern used elsewhere in the file for user-facing failure copy

**File:** `CarTube/Views/Debug.swift:141-145`
**Issue:** Minor inconsistency only, no functional defect: `forceScriptOn` always claims success ("...is now enabled and the CarPlay webview reloaded in place") even though `applyConfiguration()` silently no-ops if `resultsController`/`controller` is nil (no CarPlay attached), which can mislead a developer testing on the phone screen alone.
**Fix:** Gate the alert on `CarPlaySingleton.shared.getCPVC() != nil`, or reword to "will apply next time CarPlay is connected" when not attached.

### IN-03: `SearchCoordinatorTests` never exercises the `KeyboardView` → `CarPlaySingleton.submitSearchQuery` path

**File:** `CarTubeTests/SearchCoordinatorTests.swift` (whole file)
**Issue:** All tests construct `SearchCoordinator` directly with injected closures, which is good for isolating the funnel logic, but it means CR-01 (a real, user-facing bug in the actual production call path) has zero test coverage anywhere in the suite.
**Fix:** Not blocking this review, but worth a follow-up: an XCTest (or manual UAT step) that drives `KeyboardView.submitSearch()` twice in sequence and asserts the second submitted query doesn't contain the first query's text.

---

_Reviewed: 2026-08-19T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_
