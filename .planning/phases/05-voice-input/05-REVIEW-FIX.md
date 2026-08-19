---
phase: 05-voice-input
fixed_at: 2026-08-19T06:43:42Z
review_path: .planning/phases/05-voice-input/05-REVIEW.md
iteration: 1
findings_in_scope: 8
fixed: 8
skipped: 0
status: all_fixed
---

# Phase 05: Code Review Fix Report

**Fixed at:** 2026-08-19T06:43:42Z
**Source review:** .planning/phases/05-voice-input/05-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 8 (Critical: 3, Warning: 5 — Info findings IN-01/IN-02 excluded per fix_scope=critical_warning)
- Fixed: 8
- Skipped: 0

**Verification:** all commits produced in an isolated git worktree
(`.claude/worktrees/rf-05-88924-1787120616`, branch `gsd-reviewfix/05-88924`, fast-forwarded
into `gsd/v1.0-milestone` on cleanup). After every commit, each touched Swift file was checked
with `swift -frontend -parse` (syntax-only, since intermediate commits intentionally leave the
new `MicButtonTests.swift`/pbxproj registration on disk ahead of the WR-04 commit that makes them
buildable). The full `xcodebuild test` suite (target `CarTubeTests`, destination iPhone 17
simulator) was run once at the true end state, after all 6 commits landed: **91/91 tests passed**,
including 4 new `MicButtonTests` cases.

Note on commit grouping: CR-01, CR-02, and WR-05 all touch the same `onTouchDown`/`onTouchUp`/
`MicButton(...)` construction lines in `CarPlayViewController.swift` and `Debug.swift`'s preview
host, and are causally interdependent (CR-01's fix calls a method added by WR-05's follow-on
`stopListeningVisuals()`; CR-02's fix requires `SpeechRecognizerService.startListening()` to
return `Bool`). Splitting them into three commits would have produced two commits that don't
compile in isolation, so they were fixed and committed together as one atomic, compilable unit.
Likewise WR-03 (duplicated availability-gate read) is a single logical change spanning three
files by the review's own description ("Also implicated" lists all three) and was committed as
one unit. Every other finding is its own standalone commit.

## Fixed Issues

### CR-01: Failure hint pill is shown and then immediately hidden on every no-speech / error touch-up

**Files modified:** `CarTube/CarPlay/MicButton.swift`, `CarTube/CarPlay/CarPlayViewController.swift`, `CarTube/Views/Debug.swift`
**Commit:** `19caf05` (combined with CR-02, WR-05 — see grouping note above)
**Applied fix:** Added `MicButton.stopListeningVisuals()`, which resets the button's idle
color/pulse without touching the pill. `CarPlayViewController.onTouchUp` and `Debug.swift`'s
`VoiceSearchPreviewHost.onTouchUp` now call `stopListeningVisuals()` instead of
`setListening(false)` after `stopListening()`, so a hint pill shown synchronously by `onFailure`
during `stopListening()` survives the caller's follow-up visual reset.

### CR-02: Mic button shows "Listening…" even when `startListening()` silently failed to start

**Files modified:** `CarTube/Speech/SpeechRecognizerService.swift`, `CarTube/CarPlay/CarPlayViewController.swift`, `CarTube/Views/Debug.swift`
**Commit:** `19caf05` (combined with CR-01, WR-05 — see grouping note above)
**Applied fix:** `SpeechRecognizerService.startListening()` now returns `@discardableResult Bool`,
returning `false` on every early-return path (audio session activation failure, audio engine
start failure) and `true` only once a session is fully underway. Both `onTouchDown` call sites
(`CarPlayViewController`, `Debug.swift`'s preview host) now guard on the return value and only
call `setListening(true)` when the session actually started. Existing test call sites that ignore
the return value (`SpeechRecognizerServiceTests`, `SpeechAvailabilityGateTests`,
`SilenceTimerTests`) needed no changes thanks to `@discardableResult`.

### CR-03: Denying speech recognition strands the user in "needs onboarding" with no recovery path

**Files modified:** `CarTube/Views/VoiceSearchSetup.swift`
**Commit:** `35ac598`
**Applied fix:** `enableVoiceSearch()` now always requests microphone permission after the speech
authorization callback returns, regardless of the speech result, exactly as suggested in the
review. This guarantees `AVAudioSession.recordPermission` reaches a real decided state so
`VoiceSearchAvailability.evaluate` can return `.denied` (with its "Open Settings" CTA) instead of
getting stuck on `.needsOnboarding`.

## Warnings — Fixed

### WR-01: Mic button y-position computed before first layout pass

**Files modified:** `CarTube/CarPlay/CarPlayViewController.swift`
**Commit:** `e050301`
**Applied fix:** Added `override func viewDidLayoutSubviews()` that re-applies
`micButton.frame.origin.y = view.safeAreaInsets.top + 16.0` on every layout pass, so a non-zero
top safe area on the actual head unit is picked up instead of the `.zero` value read in
`viewDidLoad` before `window.makeKeyAndVisible()`.

### WR-02: `SpeechRecognizerService` has no teardown path if the owner drops its reference mid-session

**Files modified:** `CarTube/Speech/SpeechRecognizerService.swift`
**Commit:** `e8c99cc`
**Applied fix:** Added `deinit` that finalizes any in-flight session (`finalize(outcome: .unavailable)`
if `isListening`) and always removes the interruption observer, exactly as suggested.

### WR-03: The availability-gate read is duplicated verbatim in three places

**Files modified:** `CarTube/Speech/VoiceSearchAvailability.swift`, `CarTube/CarPlay/CarPlayViewController.swift`, `CarTube/Views/VoiceSearchSetup.swift`, `CarTube/Views/Debug.swift`
**Commit:** `766e2c2`
**Applied fix:** Added `VoiceSearchAvailability.currentState()` as the single hoisted helper and
switched all three call sites (`CarPlayViewController.refreshMicButtonVisibility`,
`VoiceSearchSetup.currentState`, `Debug.currentVoiceSearchState`) to call it instead of
duplicating the four-line sequence.

### WR-04: `MicButton` has no unit test coverage

**Files modified:** `CarTubeTests/MicButtonTests.swift` (new), `CarTube/CarPlay/MicButton.swift`, `CarTube.xcodeproj/project.pbxproj`
**Commit:** `552db9b`
**Applied fix:** Added `CarTubeTests/MicButtonTests.swift` with 4 tests covering pill
show/hide/dismiss transitions, including a direct regression guard for CR-01
(`testStopListeningVisualsPreservesAnActiveHintPill`, mirroring the exact fixed call order
`CarPlayViewController.onTouchUp` now uses) and a test documenting `setListening(false)`'s
existing hide-on-call contract. Widened `MicButton.pillBackground` from `private` to internal so
`@testable import CarTube` can assert on it. Registered the new file in
`CarTube.xcodeproj/project.pbxproj` (`PBXFileReference`, `PBXBuildFile`, group membership, and
the `CarTubeTests` `PBXSourcesBuildPhase`) so it's part of the `CarTubeTests` build target — all 4
new tests pass in the full suite run.

### WR-05: `MicButton.init(frame:)` silently discards the caller-supplied width/height

**Files modified:** `CarTube/CarPlay/MicButton.swift`, `CarTube/CarPlay/CarPlayViewController.swift`, `CarTube/Views/Debug.swift`
**Commit:** `19caf05` (combined with CR-01, CR-02 — see grouping note above)
**Applied fix:** Added `convenience init(origin: CGPoint)` that constructs the fixed 56x56 frame
internally, making the fixed-size contract explicit. Updated both call sites
(`CarPlayViewController.viewDidLoad`, `Debug.swift`'s `VoiceSearchPreviewHost.makeUIView`) to use
`MicButton(origin:)` instead of passing a width/height that would have been silently ignored.
The original `override init(frame:)` is left intact for `UIView`/`NSCoding` compatibility.

## Skipped Issues

None — all 8 in-scope findings (3 critical, 5 warning) were fixed. Info findings IN-01 and IN-02
were intentionally excluded per `fix_scope=critical_warning`.

---

_Fixed: 2026-08-19T06:43:42Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
