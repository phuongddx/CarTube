# Phase 4: CarPlay Search Surface - Pattern Map

**Mapped:** 2026-08-18
**Files analyzed:** 7 (2 new source, 2 modified source, 1 project config, 1 optional test, 1 in-file sub-concern)
**Analogs found:** 6 / 7
**Upstream inputs:** `04-UI-SPEC.md` (token/copy/state authority — no CONTEXT.md exists for this phase), `.planning/research/ARCHITECTURE.md`, Phase 3 plans `03-02-PLAN.md` / `03-03-PLAN.md`

> **Phase 3 dependency note:** `CarTube/Search/` (SearchResult, YouTubeSearchService, SearchError, LastQueryCache, SearchFallback) and `CarTubeTests/` do **not exist yet** in the codebase — Phase 3 is planned but not executed. Phase 4 consumes those shapes as *planned contracts* (pinned in the "Phase 3 Contracts Being Consumed" section below). All excerpt line numbers for Phase 3 artifacts refer to the plan documents, not source files.

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `CarTube/CarPlay/SearchResultsViewController.swift` (NEW) | component (UIKit `UITableViewController` child VC) | event-driven (row tap) + render (results → rows) | `CarPlayViewController.swift` keyboard wiring (L112–119) + `KeyboardView.swift` (visual language, singleton call-back) | partial — wiring/z-order/hiding exact; no `UITableView` exists anywhere in repo |
| `CarTube/Search/SearchCoordinator.swift` (NEW) | service/coordinator (singleton funnel) | request-response (query → results), event-driven degrade | `CarPlaySingleton.swift` singleton shape (L13–14, L21–29) | role-match — shape analog only; the funnel logic itself is new |
| `CarTube/CarPlay/CarPlayViewController.swift` (MODIFIED) | component | event-driven | self — keyboard wiring L112–119, `toggleKeyboard` L277–286, keyboard message handler L288–295 | exact (self-analog) |
| `CarTube/CarPlay/CarPlaySingleton.swift` (MODIFIED) | middleware/facade (≤3 passthroughs) | request-response passthrough | self — `sendInput`/`backspaceInput`/`toggleKeyboard` L86–104 | exact (self-analog) |
| `CarTube.xcodeproj/project.pbxproj` (MODIFIED) | config | — | Phase 3 wiring convention (throwaway ruby gem script, delete after — `03-02-PLAN.md` Task 1 step 3 / Task 2 step 5) | exact (process analog) |
| Thumbnail async load (sub-concern inside `SearchResultsViewController`) | utility (network image fetch) | streaming (network → image view) | **none** — closest is `CarTubeApp.checkNewVersions` `URLSession.dataTask` L55–70 (JSON, not image; completion-based, not async/await) | no analog — decision documented below |
| `CarTubeTests/SearchCoordinatorTests.swift` (optional, recommended) | test | request-response | Phase 3 planned test conventions (`MockURLProtocol`, fixtures — `03-02-PLAN.md` Task 2 step 2) | role-match (planned artifact, not yet in codebase) |

---

## Pattern Assignments

### `CarTube/CarPlay/SearchResultsViewController.swift` (component, event-driven/render)

**Analog:** `CarTube/CarPlay/CarPlayViewController.swift` for wiring; `CarTube/Views/KeyboardView.swift` for in-view behavior conventions.

**File header convention** — every repo Swift file opens with this shape (`KeyboardView.swift` lines 1–7). Use `CarTube` as the module name (newer convention), not the legacy `TrollTubeTest` seen in CarPlay files:

```swift
//
//  SearchResultsViewController.swift
//  CarTube
//
//  Created by <author> on <date>.
//

import UIKit
```

**Child-VC wiring pattern to copy** — `CarPlayViewController.swift` lines 112–118 (keyboard) and 132–134 (splash — full-frame variant). Note the keyboard's fixed computed frame is a deliberate **deviation point** for the overlay (see deviations):

```swift
// Add a view for our keyboard
let keyboardController = UIHostingController(rootView: KeyboardView(width: view.bounds.width))
self.addChild(keyboardController)
self.view.addSubview(keyboardController.view)
keyboardController.view.frame = CGRect(x: Int(view.bounds.origin.x), y: Int(view.bounds.height * 2/5), width: Int(view.bounds.width), height: Int(view.bounds.height * 3/5))
self.keyboardView = keyboardController.view
self.keyboardView.isHidden = true
```

The overlay's spec-mandated form (UI-SPEC z-order block):

```swift
resultsController.view.frame = view.bounds
resultsController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
resultsController.view.isHidden = true
view.insertSubview(resultsController.view, belowSubview: screenOffLabel)
```

**Z-order stack being extended** — current `viewDidLoad()` addSubview sequence (`CarPlayViewController.swift` lines 93, 108, 115, 122, 134): `webView` → `noSleepView` (hidden) → `keyboardController.view` (hidden) → `screenOffLabel` → `splash` (temporary). The overlay slots between `keyboardView` and `screenOffLabel`.

**Wiring-position hazard (existing, not new):** `viewDidLoad()` lines 100–101 contain `guard let scriptPath = Bundle.main.path(forResource: "NoSleepEnable", ofType: "js"), ... else { return }` — if that resource load ever fails, everything after it (keyboard, screenOffLabel, splash) is silently never wired. All existing child-VC wiring already sits downstream of this guard; place the results wiring in the same downstream region (do not "fix" the guard — surgical changes only), and prefer the SPEC's `insertSubview(belowSubview: screenOffLabel)` over positional `addSubview` so correctness doesn't depend on statement order.

**Show/hide pattern to copy — with the anti-pattern carved out.** `toggleKeyboard` (`CarPlayViewController.swift` lines 277–286) is the toggle analog, but it is also the anti-pattern for this phase:

```swift
// Show or hide the keyboard
func toggleKeyboard() {
    if keyboardView.isHidden {
        self.keyboardView.isHidden = false
        self.webView.frame.size.height = view.bounds.size.height - self.keyboardView.frame.size.height   // ← search results MUST NOT do this (UI-01)
    } else {
        self.keyboardView.isHidden = true
        self.webView.frame.size.height = view.bounds.size.height                                         // ← nor this
    }
}
```

The overlay's show/hide is `resultsController.view.isHidden` toggling only — zero `webView.frame` mutation, no animation (SPEC: "identical to keyboard toggling" in mechanics, minus the resize). Restoration is free because the webview was never resized.

**In-view action convention to copy** — `KeyboardView.swift` lines 46–59: views call `CarPlaySingleton.shared` directly, never hold parent references:

```swift
func sendKey(key: String) {
    CarPlaySingleton.shared.sendInput(shifted ? key.uppercased() : key)
}

func dismiss() {
    CarPlaySingleton.shared.toggleKeyboard()
}
```

So the overlay's Close button → `CarPlaySingleton.shared.dismissSearchResults()`, row tap → `CarPlaySingleton.shared.loadUrl(YT_EMBED + videoId)` then `dismissSearchResults()`, "Try another search" → `dismissSearchResults()` + `toggleKeyboard()`. (Research `ARCHITECTURE.md` Pattern 1 shows a closure-injection variant `onSelect`/`onCancel`; the KeyboardView direct-call style is the in-repo convention and avoids retaining `CarPlayViewController` — prefer it, but the closure variant is acceptable if the planner prefers testability.)

**Visual language analog** — `KeyboardView.swift` line 29 (the separator color the UI-SPEC inherits):

```swift
.border(Color(UIColor.init(hue: 0, saturation: 0, brightness: 0.2, alpha: 1.0)))
```

All other tokens (fonts, sizes, colors, spacing, row heights, copy, states) are locked by `04-UI-SPEC.md` — that file is the authority, not any code excerpt.

**State model** — `results: [SearchResult]` + `isSearching: Bool` + fallback row state drive the table (research State Management section). Loading entry shows the spinner row from query submit, before network completes.

**Deviation ledger vs. keyboard analog (all deliberate, SPEC-mandated):**
1. `autoresizingMask = [.flexibleWidth, .flexibleHeight]` — keyboard uses a fixed computed frame; the overlay must track `view.bounds` across head-unit sizes.
2. Never resize the webview (UI-01 hard constraint).
3. Keep a typed `resultsController` property (needed to drive table state), vs. keyboard which stores only the plain `UIView` in `keyboardView` and drops the controller reference.
4. `insertSubview(_:belowSubview:)` rather than positional `addSubview`.

---

### `CarTube/Search/SearchCoordinator.swift` (service/coordinator, request-response)

**Analog:** `CarPlaySingleton.swift` — singleton *shape* only. The funnel logic (cache read → service call → fallback decision → presentation) has no in-repo analog; the chain's pure halves were built in Phase 3.

**Singleton shape to mirror** — `CarPlaySingleton.swift` lines 13–19:

```swift
class CarPlaySingleton {
    static let shared = CarPlaySingleton()
    private var controller: CarPlayViewController?
    private var cachedVideo: String?
    ...
}
```

New-code deviation (milestone convention, iOS 16 floor, decided in Phase 3 patterns): `@MainActor final class SearchCoordinator` with `static let shared`. The existing singleton is a plain class — do not retrofit `@MainActor` onto `CarPlaySingleton`; only the new coordinator is actor-isolated.

**Controller-nil edge handling to be aware of (do not replicate blindly):** `loadUrl` (`CarPlaySingleton.swift` lines 21–29) buffers into `cachedVideo` when `controller == nil` and alerts when CarPlay is absent:

```swift
/// Load a YouTube URL string into the player
func loadUrl(_ urlString: String) {
    if AVExternalDevice.currentCarPlay() == nil {
        UIApplication.shared.alert(body: "CarPlay not connected.", window: .main)
    } else if controller == nil {
        self.cachedVideo = urlString
    } else {
        controller?.loadUrl(urlString)
    }
}
```

The coordinator reuses this behavior *by calling* `loadUrl`/`searchVideo` — it must not re-implement the guard. For `showSearchResults`, the analogous nil-controller behavior is simply a no-op (`controller?.` optional chaining, matching `sendInput` L86–88) — results are ephemeral and re-fetchable; do not add a results cache in the singleton.

**Degrade edge (the Phase 3 caller contract, wired here):** `03-03-PLAN.md` Task 2 pins `SearchFallback.decide(...)` → `.degradeToWebviewSearch` executed by calling the existing `CarPlaySingleton.searchVideo(_:)` (`CarPlaySingleton.swift` lines 34–39):

```swift
/// Search for a YouTube video in the player
func searchVideo(_ search: String) {
    let searchString = YT_SEARCH + search
    guard let safeSearch = searchString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
    loadUrl(safeSearch)
}
```

**Coordinator funnel shape (from research Pattern 3 + Phase 3 artifacts):** `search(query)` → `LastQueryCache.cachedResults(for:)` → miss: `YouTubeSearchService.search(query:)` (async, background decode) → hop to MainActor → `SearchFallback.decide(Result)` → `.showResults` → `CarPlaySingleton.shared.showSearchResults(results)`; `.showNoResults` → overlay empty row; `.degradeToWebviewSearch` → `CarPlaySingleton.shared.searchVideo(query)` + fallback row + ≤2s auto-dismiss.

**Boundary rule (from Phase 3 grep gates):** Phase 3 gates assert zero `CarPlaySingleton` references under `CarTube/Search/` — `SearchCoordinator.swift` is the sanctioned exception (the "thin edge" the Phase 3 caller contract reserved). Phase 4's verification must scope that grep to exclude `SearchCoordinator.swift`; the service, model, cache, and fallback files stay Foundation-only and singleton-free.

**Timer/auto-dismiss analog** — `CarPlayViewController.showWarningLabel` lines 233–243 (`Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false)`) and the splash timer lines 137–145. The ≤2.0s fallback auto-dismiss mirrors these; on `@MainActor`, `Task.sleep(for: .seconds(2))` is the modern equivalent — either is in-convention.

---

### `CarTube/CarPlay/CarPlayViewController.swift` (modified — component, event-driven)

**Analog:** itself. Three insertion sites:

1. **Child-VC wiring** — extend the block at lines 112–118 (excerpted above). Add the `resultsController` property beside `keyboardView` (line 17 region: `private var keyboardView: UIView = UIView()`), then the wiring block per the SPEC z-order. Pure Swift; no bridging-header, header, or ObjC changes.

2. **Show/dismiss methods** — mirror `toggleKeyboard` (L277–286) minus the webview resize:

```swift
func showSearchResults(_ results: [SearchResult]) {
    resultsController.update(results)          // or set state + reloadData
    resultsController.view.isHidden = false
}

func dismissSearchResults() {
    resultsController.view.isHidden = true
}
```

3. **No JS message-handler change needed** — the `keyboard` handler (L288–295) stays untouched; the overlay is driven from Swift, not JavaScript.

**Swift/ObjC interop: none.** The file's WebKit private-API surface (`_simulateTextEntered` via `Headers/WebView+Additions.h`) is unrelated and untouched. Phase 4 adds zero Objective-C, zero headers, zero hooks.

---

### `CarTube/CarPlay/CarPlaySingleton.swift` (modified — middleware, request-response passthrough)

**Analog:** itself — the `sendInput`/`backspaceInput`/`goHome`/`goBack`/`toggleKeyboard` block, lines 86–104:

```swift
/// Send keyboard input to the web view
func sendInput(_ input: String) {
    controller?.sendInput(input)
}

/// Send a backspace to the web view
func backspaceInput() {
    controller?.backspaceInput()
}

// Go back to the homepage on the web view
func goHome() {
    controller?.goHome()
}

// Go back
func goBack() {
    controller?.goBack()
}

/// Toggle the web view keyboard
func toggleKeyboard() {
    controller?.toggleKeyboard()
}
```

**The ≤3 additions (cap is a hard milestone rule — research Pattern 2 / Anti-Pattern 2):**

```swift
func showSearchResults(_ results: [SearchResult]) {
    controller?.showSearchResults(results)
}

func dismissSearchResults() {
    controller?.dismissSearchResults()
}

func submitSearchQuery(_ query: String) {
    SearchCoordinator.shared.search(query)
}
```

Copy the exact shape: one-line body, `controller?.` optional chaining, no state, no guards, no alerts. Keep the `///` doc-comment style on the new methods. Placement: in the same method block, after `toggleKeyboard`. No stored properties are added — results live in the overlay; the query lives in the coordinator.

---

### `CarTube.xcodeproj/project.pbxproj` (modified — config)

**Analog:** the Phase 3 wiring convention (`03-02-PLAN.md` Task 1 step 3, Task 2 step 5): add new files to the CarTube/CarTubeTests targets via a **throwaway ruby gem script, then delete the script**; re-grep the pbxproj before editing because earlier phases shift line numbers; verify both targets build afterward. `SearchResultsViewController.swift` joins the `CarPlay` group; `SearchCoordinator.swift` joins the `Search` group (created in Phase 3). New files are plain source additions — no resources, no frameworks, no entitlements, no Info.plist keys this phase (Registry Safety: no new dependencies).

---

### `CarTubeTests/SearchCoordinatorTests.swift` (optional test — recommended for the funnel)

**Analog:** Phase 3's planned test infrastructure — `MockURLProtocol` (request-recording `URLProtocol` stub) + `Bundle(for:)` fixture loading (`03-02-PLAN.md` Task 2 step 2, Task 1 step 4). The coordinator's testable seam is the funnel minus the singleton edge: inject the service/cache, assert the decision reached per fixture outcome (cache-hit zero-request, quota → degrade decision, empty → no-results). The singleton calls themselves are the thin edge and stay untested, matching Phase 3's pure-core/thin-edge split.

---

## Shared Patterns

### Singleton facade (cross-surface command routing)
**Source:** `CarPlaySingleton.swift` lines 13–19, 86–104 — `static let shared`, `private var controller`, one-line `controller?.` passthroughs.
**Apply to:** `SearchCoordinator` (same `static let shared` shape, `@MainActor`), both singleton additions, and every overlay action (UI never retains `CarPlayViewController`).

### Opaque hidden child-VC overlay
**Source:** `CarPlayViewController.swift` lines 112–118 (keyboard), 132–134 (splash full-frame), `toggleKeyboard` L277–286.
**Apply to:** `SearchResultsViewController` wiring + show/dismiss. `isHidden` toggling, no animation, no webview mutation (UI-01).

### Tap → playback is one hop
**Source:** `CarPlayApp.swift` lines 31–36 — `CarPlaySingleton.shared.loadUrl(YT_EMBED + id)`; `Constants.swift` line 11 — `let YT_EMBED = "https://m.youtube.com/watch?v="`.
**Apply to:** overlay row tap. No new URL constants needed; no new navigation code path into the webview.

### Main-thread discipline
**Source:** `Alert++.swift` lines 19–29 (`DispatchQueue.main.async` around every UI touch); CONVENTIONS.md concurrency rules (decode may run background; UI returns to main).
**Apply to:** coordinator — service result hops to `@MainActor` before any `showSearchResults`/`searchVideo` call. With `@MainActor` on the coordinator this is structural, not manual dispatch.

### Timer-based transient UI
**Source:** `CarPlayViewController.swift` lines 233–243 (`showWarningLabel`, 3.0s non-repeating timer), 137–145 (splash fade).
**Apply to:** the fallback-row ≤2.0s auto-dismiss (dismiss overlay when the webview fallback navigation commits, or at 2.0s — whichever first).

### Header comment + naming
**Source:** `KeyboardView.swift` lines 1–7 (header), `Constants.swift` (SCREAMING_SNAKE_CASE URLs), CONVENTIONS.md Naming.
**Apply to:** both new files. New-code error handling follows CONVENTIONS.md "Recommended for new code": guard optionals, no force-unwraps in new paths (the legacy `URL(string:)!` in `loadUrl` stays untouched).

---

## No Analog Found

| File/Concern | Role | Data Flow | Reason | Planner Guidance |
|------|------|-----------|--------|------------------|
| Thumbnail async load (rows of `SearchResultsViewController`) | utility (image fetch) | streaming | No image loading, no `UIImageView` remote content, no `UITableView`/cell-reuse code exists anywhere in the repo. Closest networking (`CarTubeApp.checkNewVersions`, `URLSession.dataTask` + JSON) is completion-based JSON, superseded by Phase 3's async/await decision. | Per-cell `Task { }` in `cellForRowAt` calling `URLSession.shared.data(from:)` (async/await, matching the Phase 3 decision); `#1C1C1E` placeholder fill per SPEC; cancel the task in `prepareForReuse` (≥8 rows on one screen makes reuse cancellation cheap correctness, not speculative abstraction); guard the `URL?` (thumbnail is `URL?` on `SearchResult`) — no force-unwrap; no third-party image library (Registry Safety gate); an `NSCache` for decoded images is optional — omit unless scroll-refetch is observed. |
| `UITableViewController` + custom cell + table header | component | render | No table view, no custom `UITableViewCell`, no `tableHeaderView` usage in repo. | Hand-roll per `04-UI-SPEC.md` Component Inventory (rows 1–6) — plain style, opaque black, `UITableView.automaticDimension` with 60pt floor / 68pt default, `min(results.count, 8)` rows, Close-button header. System fonts/colors/SF Symbols only. |
| SearchCoordinator funnel logic | service | request-response | Only the shape analog (`CarPlaySingleton`) exists; the chain is new. | Every link except the singleton edge is a built Phase 3 artifact — compose them per the funnel shape above; keep the singleton calls as the only untested thin edge. |

---

## Phase 3 Contracts Being Consumed (planned, not yet in codebase)

Pinned from `03-02-PLAN.md` / `03-03-PLAN.md` — Phase 4 code compiles against these exact surfaces:

| Contract | Shape | Consumed by |
|----------|-------|-------------|
| `SearchResult` | flat `Codable` struct: `videoId: String, title: String, channel: String?, thumbnail: URL?, duration: String?` — Foundation-only | overlay rows (thumbnail placeholder/`duration` nil → hidden label, row keeps ≥60pt per SPEC partial-state row) |
| `YouTubeSearchService` | `func search(query: String) async throws -> [SearchResult]`; stateless, injectable URLSession | coordinator |
| `SearchError` | `apiKeyMissing / apiKeyInvalid / quotaExceeded / other(String)` | coordinator (feeds `SearchFallback.decide`) |
| `LastQueryCache` | `actor`; `cachedResults(for:) / store(query:results:) / clear()` | coordinator (between submit and service) |
| `SearchFallback` | pure `decide(Result<[SearchResult], SearchError>, query:) -> SearchOutcomeAction { showResults, showNoResults, degradeToWebviewSearch }`; caller contract names `CarPlaySingleton.shared.searchVideo(query)` as the degrade edge | coordinator (Phase 4 wires the edge) |
| `CarTubeTests/MockURLProtocol` + fixtures | URLProtocol stub with request recording | optional coordinator tests |

**Boundary carry-forward:** Phase 3's grep gate "no `CarPlaySingleton` under `CarTube/Search/`" must be scoped in Phase 4 to exclude `SearchCoordinator.swift` — it is the documented exception (the thin edge). All other Search/ files remain Foundation-only and singleton-free.

---

## Metadata

**Analog search scope:** `CarTube/CarPlay/`, `CarTube/Views/`, `CarTube/Extensions/`, `CarTube/Util/`, `CarTube/` root (`CarTubeApp.swift`), `.planning/phases/03-search-core/`, `.planning/research/`, `.planning/codebase/`
**Files scanned:** 18 source/docs (3 CarPlay, 7 Views, 2 Extensions, 2 Util, CarTubeApp, 3 Phase 3 plans, research ARCHITECTURE) + UI-SPEC
**Pattern extraction date:** 2026-08-18
**Design authority:** `04-UI-SPEC.md` — where any excerpt and the SPEC disagree, the SPEC wins
