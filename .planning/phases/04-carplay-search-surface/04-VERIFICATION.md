---
phase: 04-carplay-search-surface
verified: 2026-08-19T11:05:00Z
status: passed
score: 4/4 must-haves verified
behavior_unverified: 0
overrides_applied: 0
---

## Resolution of flagged item (post-verification, same session)

The verifier's flagged concern (thumbnailImageView's three simultaneously-required vertical constraints only jointly satisfiable at exactly 92pt content height) was confirmed empirically, not just statically: using `native-view-at-point` against the live simulator (BC6D2019-EE12-458D-9990-FD25A9C3FD2E, iPhone Air), the thumbnail's `windowFrame` was `106×96`, not the spec'd `106×60` — confirming UIKit silently broke the `height=60` constraint in favor of the exact `top`+`bottom` chain.

Fixed in commit `e263fcc`: changed `thumbnailImageView.bottomAnchor` from `equalTo` to `lessThanOrEqualTo`. This leaves exactly one required vertical chain (`top=16` + `height=60`) determining the frame — no solver arbitration possible, deterministically `106×60`. The bottom pin is now a non-binding ceiling (16+60=76 < 128-16=112, always satisfied). 54/54 tests still pass (layout-only change).

# Phase 4: CarPlay Search Surface Verification Report

**Phase Goal:** Drivers see search results as a native, glanceable, tappable list on the CarPlay screen, layered over the webview without disturbing playback — the landing zone both voice inputs require
**Verified:** 2026-08-19T11:05:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Driver sees search results as a tappable list — ≤8 rows, ≥60pt rows, thumbnail + title + channel + duration — one tap plays | ✓ VERIFIED (with a flagged sub-item) | `SearchResultsViewController.swift`: `numberOfRowsInSection` returns `min(results.count, 8)` for non-empty results (L100); `tableView.rowHeight = 128.0` (L38, ≥60pt floor satisfied); `ResultCell` renders thumbnail (106×60, radius 8, L200-201/174), 22pt/2-line title (L177-180), 17pt/1-line channel (L182-185), 15pt monospaced duration via `DurationFormatter.display` (L230-235); `didSelectRowAt` calls `onSelect(results[indexPath.row].videoId)` (L142), wired in `CarPlayViewController` to `loadUrl(YT_EMBED + videoId)` + `dismissSearchResults()`. Executor's own Task-3 visual pass (argent simulator, iPhone Air/iOS 26.5) confirmed channel now renders and 2-line titles wrap after the rowHeight fix. **Flagged:** thumbnailImageView has three simultaneously-required vertical constraints (top+bottom+fixed-height=60) only jointly consistent at exactly 92pt content height; rowHeight is 128pt, so the constraint set remains mathematically over-determined — see Human Verification below for whether the rendered thumbnail is still exactly 60pt. |
| 2 | Playback continues beneath the results list without resizing or navigating the webview | ✓ VERIFIED | `CarPlayViewController.showSearchResults`/`dismissSearchResults` (L319-327) only touch `resultsController.update(state)` / `.view.isHidden` — zero `webView` references (confirmed via `awk`-scoped grep, matching the plan's own gate). Overlay inserted via `insertSubview(belowSubview: screenOffLabel)` with `view.bounds` frame and `[.flexibleWidth, .flexibleHeight]` autoresizing (L173-177) — order-independent of the NoSleep guard, no frame mutation of the webview anywhere in the new code. |
| 3 | All search inputs funnel through a single SearchCoordinator, ≤3 new CarPlaySingleton passthroughs | ✓ VERIFIED | `SearchCoordinator` is `@MainActor final class` with `static let shared` (`SearchCoordinator.swift` L10-12); `KeyboardView.submitSearch()` → `CarPlaySingleton.shared.submitSearchQuery` → `SearchCoordinator.shared.search(_:)` is the sole typed-input entry point. `git show 8ff450b -- CarTube/CarPlay/CarPlaySingleton.swift \| grep '^\+.*func '` returns exactly 3 lines (`showSearchResults`, `dismissSearchResults`, `submitSearchQuery`); `git log --oneline -- CarTube/CarPlay/CarPlaySingleton.swift` shows no further commits after `8ff450b` (04-02 added zero passthroughs, cap intact). Boundary gate holds: `grep -rn 'CarPlaySingleton' CarTube/Search/ --include='*.swift' \| grep -v 'SearchCoordinator.swift'` returns empty. |
| 4 | Results list displays "Results from YouTube" attribution | ✓ VERIFIED | `SearchResultsViewController.makeHeaderView()` builds a static 13pt systemGray right-aligned label with the exact text "Results from YouTube" (L58-63); the header is table-header chrome built once in `viewDidLoad`, untouched by any state branch in `cellForRowAt`/`numberOfRowsInSection` — persists identically across `.loading`, `.results(...)`, and `.fallback`. |

**Score:** 4/4 truths verified (1 present, behavior-unverified sub-item flagged for human confirmation — see below)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `CarTube/Search/DurationFormatter.swift` | Pure ISO-8601 PT→badge formatter | ✓ VERIFIED | `enum DurationFormatter`, Foundation-only import, `display(_:)` static func; 4 test methods / 15 assertions pass |
| `CarTube/CarPlay/SearchResultsViewController.swift` | UITableViewController overlay: header, cells, loading/no-results/fallback rows, async thumbnails | ✓ VERIFIED | All states implemented; `ResultCell`/`MessageCell` present; per-cell `Task` cancelled in `prepareForReuse` (L220-221) |
| `CarTube/Search/SearchCoordinator.swift` | `@MainActor` funnel singleton with injectable seams | ✓ VERIFIED | presenter/degrade/dismissOverlay/autoDismissDelay seams (L16-19), generation-guard at 4 checkpoints (L45-46, 51, 55, 70, 75, 89) |
| CarPlaySingleton — exactly 3 passthroughs | one-line bodies, no stored properties | ✓ VERIFIED | Confirmed via git-diff func count (see truth 3) |
| CarPlayViewController wiring | full-frame child-VC insert, show/dismiss w/ zero webview mutation | ✓ VERIFIED | See truth 2 |
| KeyboardView — typed-query buffer + submit key | all 3 keyboard modes | ✓ VERIFIED | `magnifyingglass` submit key present in `.letters`/`.symbols1`/`.symbols2` bottom rows (L118, 160, 202); buffer reset bug (CR-01) fixed in commit `ff64166` — `dismiss()` clears `typedQuery`, `submitSearch()` captures the value into a local constant first |
| `CarTubeTests/DurationFormatterTests.swift` + `SearchCoordinatorTests.swift` | formatter matrix + funnel state-sequence tests | ✓ VERIFIED | 10 `SearchCoordinatorTests` methods cover happy-path, cache-hit, degrade-ordering, fallback-auto-dismiss-once, 4 failure kinds, empty-success, stale-response-discard |
| Phone-side preview harness (`CarTube/Views/Debug.swift`) | drives every state via the production controller | ✓ VERIFIED | "Search Overlay Preview" section (L55), `SearchResultsPreviewHost: UIViewControllerRepresentable` wraps the real `SearchResultsViewController` (L156-179), calls `update(_:)` in both `make`/`update` |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| KeyboardView submit key | SearchCoordinator | `CarPlaySingleton.shared.submitSearchQuery(query)` | ✓ WIRED | `submitSearch()` L68-72; `submitSearchQuery` is individually `@MainActor`-annotated to bridge into the isolated coordinator |
| Row tap | Playback + dismiss | `onSelect` closure → `loadUrl(YT_EMBED + videoId)` + `dismissSearchResults()` | ✓ WIRED | `CarPlayViewController` L160-172 (per grep of the `resultsController` init block) |
| Degrade decision | webview search + auto-dismiss | `SearchCoordinator.run` `.degradeToWebviewSearch` branch | ✓ WIRED | `presenter(.fallback)` → `degrade(query)` → `scheduleAutoDismiss(generation:)` (L79-82), generation-guarded `Task.sleep` then `dismissOverlay()` (L86-92) |
| No-results row tap | retry | `didSelectRowAt` → `onRetry()` when `results.isEmpty` | ✓ WIRED | `SearchResultsViewController.swift` L136-139; `onRetry` wired in `CarPlayViewController` to `dismissSearchResults()` + `toggleKeyboard()` |

### Behavioral Spot-Checks / Test Execution

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full unit suite passes | `xcodebuild ... test` (run once, this verification) | `Executed 54 tests, with 0 failures` — `** TEST SUCCEEDED **` | ✓ PASS |
| Exactly 3 CarPlaySingleton passthroughs added, ever | `git show 8ff450b -- CarPlaySingleton.swift \| grep -c '^\+.*func '` | 3 | ✓ PASS |
| Zero further CarPlaySingleton diffs after 04-01 | `git log --oneline -- CarTube/CarPlay/CarPlaySingleton.swift` | last touch is `8ff450b` (04-01) | ✓ PASS |
| Search/ boundary gate | `grep -rn CarPlaySingleton CarTube/Search/ \| grep -v SearchCoordinator.swift` | empty | ✓ PASS |
| No debt markers (TBD/FIXME/XXX/TODO/HACK/PLACEHOLDER) in phase-touched files | grep sweep, 9 files | none found | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| UI-01 | 04-01, 04-02 | Native tappable list, ≤8 rows, ≥60pt rows, thumbnail+title+channel+duration, one-tap play, zero webview disturbance | ✓ SATISFIED (with flagged sub-item) | Truths 1 & 2 above |
| UI-02 | 04-01, 04-02 | Single SearchCoordinator funnel, ≤3 new passthroughs | ✓ SATISFIED | Truth 3 above |
| UI-03 | 04-01, 04-02 | "Results from YouTube" attribution | ✓ SATISFIED | Truth 4 above |

No orphaned requirements found — REQUIREMENTS.md maps all three IDs to Phase 4 and all three appear in both plans' `requirements:` frontmatter.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `CarTube/CarPlay/SearchResultsViewController.swift` | 165-215 (`ResultCell.setUpViews`) | Over-constrained Auto Layout: `thumbnailImageView` has simultaneous required `top`, `bottom`, and fixed `height=60` constraints, jointly consistent only at exactly 92pt content height | ⚠️ Warning | Likely produces a silent "Unable to simultaneously satisfy constraints" runtime warning on every `ResultCell` layout and may render the thumbnail at a size other than the spec'd 106×60pt (UIKit picks which constraint to break, not deterministically visible from source). Not confirmed broken — routed to human verification since this environment has no tap/UI-automation tooling to inspect the live frame. |
| `CarTube/CarPlay/CarPlayViewController.swift` | 161-163 (per 04-REVIEW.md WR-01) | `onSelect` feeds API-sourced `videoId` into `loadUrl`'s pre-existing force-unwrapped `URL(string:)!` | ⚠️ Warning (carried from 04-REVIEW.md, unfixed) | Already assessed in the phase's own STRIDE register (T-04-02, "mitigate", explicitly accepted — legacy force-unwrap kept per surgical-changes policy). Low likelihood of an actual malformed videoId from the Data API; not a phase-goal blocker. |
| `CarTube/CarPlay/CarPlayViewController.swift` | 168-171 (per 04-REVIEW.md WR-02) | `onRetry` relies on `toggleKeyboard()`'s toggle semantics rather than an explicit "show" | ⚠️ Warning (carried from 04-REVIEW.md, unfixed) | Correct in the only current call path (keyboard always hidden by the time results show); latent risk only if the debug harness's real-funnel button races a visible keyboard while attached to actual CarPlay. Not a phase-goal blocker. |
| `CarTube/CarPlay/CarPlayViewController.swift` | 161-172 (per 04-REVIEW.md WR-03) | Unused `[weak self]` capture in `onSelect`/`onClose`/`onRetry` | ℹ️ Info (carried from 04-REVIEW.md, unfixed) | Cosmetic — compiler warning only, no functional impact |
| `CarTube/CarPlay/CarPlayViewController.swift` | 308-339 (per 04-REVIEW.md WR-04) | Duplicated keyboard show/hide + resize logic between `toggleKeyboard()` and the JS message handler | ⚠️ Warning (carried from 04-REVIEW.md, unfixed) | Pre-existing pattern, phase raised its coupling cost (per WR-02) but did not introduce it; not a phase-goal blocker |
| `CarTube/CarPlay/SearchResultsViewController.swift` | 100 (per 04-REVIEW.md IN-01) | Magic number `8` for max displayed results | ℹ️ Info (carried from 04-REVIEW.md, unfixed) | Style only |
| `CarTube/Views/Debug.swift` (per 04-REVIEW.md IN-02) | 141-145 | `forceScriptOn` alert text doesn't reflect no-CarPlay-attached no-op | ℹ️ Info (carried from 04-REVIEW.md, unfixed) | Debug-only surface, no production impact |
| `CarTubeTests/SearchCoordinatorTests.swift` (per 04-REVIEW.md IN-03) | whole file | No test exercises `KeyboardView.submitSearch()` directly (the actual path CR-01 was found in) | ℹ️ Info (carried from 04-REVIEW.md, unfixed) | Documented gap; CR-01 fix itself is a 2-line, low-risk change, verified via full-suite regression (54/54) rather than a dedicated unit test since no ViewInspector/XCUITest harness exists in this repo |

No unreferenced `TBD`/`FIXME`/`XXX` debt markers found in any phase-touched file — debt-marker gate does not fire.

### Human Verification Required

### 1. ResultCell thumbnail Auto Layout conflict — confirm actual rendered size and console warnings

**Test:** On the simulator (Debug → Search Overlay Preview → "8 Results" button), open Xcode's console while the app is running, and use Xcode's View Debugger (Debug → View Debugging → Capture View Hierarchy) to inspect a `ResultCell`'s `thumbnailImageView` frame.
**Expected:** No "Unable to simultaneously satisfy constraints" warning is logged in the console, and the captured `thumbnailImageView` frame height reads exactly 60pt (matching the UI-SPEC's pinned 106×60pt thumbnail spec).
**Why human:** `ResultCell.setUpViews()` activates `thumbnailImageView.topAnchor == contentView.topAnchor + 16`, `.bottomAnchor == contentView.bottomAnchor - 16`, and `.heightAnchor == 60` simultaneously — three required constraints that are only mutually consistent when the cell's content height is exactly 92pt (16+60+16). The commit that fixed the channel-label-collapse defect (`c1441b7`) itself diagnoses this exact "92pt required" math in its commit message but raises `tableView.rowHeight` to 128 rather than 92 or removing the redundant constraint, leaving the same three-constraint conflict in place with the opposite sign (a +36pt surplus instead of a -24pt deficit). Which of the three constraints UIKit's solver silently breaks under this conflict is not statically determinable from source — it requires either a live console/View-Debugger session or a targeted unit test instantiating the (currently `private`) `ResultCell` directly, neither of which this environment's tooling (no argent MCP tap tools, no `idb`) could perform. The prior visual re-check (04-02's Task 3, done via argent) confirmed the *symptom* it was chasing (channel text visible, title wraps) is resolved, but did not check console warnings or measure the thumbnail's exact rendered height, so this narrower question remains open.

### Gaps Summary

No BLOCKER-level gaps. All four ROADMAP success criteria and all three requirement IDs (UI-01, UI-02, UI-03) are supported by passing code, a green 54/54 test suite, grep-verified structural gates, and the executor's own prior visual re-check. One WARNING-level item is flagged for human confirmation: the `ResultCell` thumbnail's vertical Auto Layout constraints remain mathematically over-determined after the row-height fix (fixed at a value ≠ 92pt, the only value that reconciles all three required constraints), so whether the thumbnail renders at its spec'd 106×60pt — or has silently grown/shrunk because UIKit broke a different constraint than intended — could not be confirmed without interactive Xcode/simulator tooling this environment lacks. This does not block phase completion (the phase's own visual pass already confirmed the *reported* symptom is gone), but should be checked before Phase 6's milestone-level UI audit, or fixed outright by replacing the redundant `bottomAnchor` constraint with a `lessThanOrEqualTo` (or removing it and letting `top + height` fully determine placement).

Additionally, four warnings and three info items from `04-REVIEW.md` remain unfixed by design (explicitly out of this task's scope per the phase brief) — carried forward here for visibility, none rise to BLOCKER severity against this phase's stated success criteria.

---

_Verified: 2026-08-19T11:05:00Z_
_Verifier: Claude (gsd-verifier)_
