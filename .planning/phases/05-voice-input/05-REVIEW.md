---
phase: 05-voice-input
reviewed: 2026-08-19T00:00:00Z
depth: standard
files_reviewed: 15
files_reviewed_list:
  - CarTube.xcodeproj/project.pbxproj
  - CarTube/CarPlay/CarPlayViewController.swift
  - CarTube/CarPlay/MicButton.swift
  - CarTube/Info.plist
  - CarTube/Search/CarTubeShortcuts.swift
  - CarTube/Search/SearchCarTubeIntent.swift
  - CarTube/Speech/SpeechRecognizerService.swift
  - CarTube/Speech/VoiceSearchAvailability.swift
  - CarTube/Views/ContentView.swift
  - CarTube/Views/Debug.swift
  - CarTube/Views/VoiceSearchSetup.swift
  - CarTubeTests/SearchIntentTests.swift
  - CarTubeTests/SilenceTimerTests.swift
  - CarTubeTests/SpeechAvailabilityGateTests.swift
  - CarTubeTests/SpeechRecognizerServiceTests.swift
  - CarTubeTests/VoiceOnboardingStateTests.swift
findings:
  critical: 3
  warning: 5
  info: 2
  total: 10
status: issues_found
---

# Phase 05: Code Review Report

**Reviewed:** 2026-08-19
**Depth:** standard
**Files Reviewed:** 15
**Status:** issues_found

## Narrative Findings (AI reviewer)

### Summary

Voice input is implemented across `SpeechRecognizerService`, `MicButton`, `VoiceSearchAvailability`, the CarPlay glue in `CarPlayViewController`, the phone onboarding screen `VoiceSearchSetup`, and the Siri/App-Intents surface (`CarTubeShortcuts` / `SearchCarTubeIntent`). The unit-level logic (`VoiceSearchAvailability.evaluate`, silence/hard-cap timing, error-code mapping, intent query normalization) is well covered by tests and traced correctly.

The problems are at the **integration seams that no test exercises**: the glue code in `CarPlayViewController` (and its Debug.swift preview twin) calls into `SpeechRecognizerService`/`MicButton` in an order that silently discards the feedback the rest of the system was carefully built to deliver, and the phone onboarding screen has a permission-request ordering bug that can permanently strand a user who denies speech recognition. Both are provable by tracing the code (not conjecture) and are not caught by any existing test, because the tests exercise `SpeechRecognizerService` with plain closures and never route through `MicButton`, and `VoiceOnboardingStateTests` only exercises `evaluate()`/`copy(for:)`, never `enableVoiceSearch()`.

### Critical Issues

### CR-01: Failure hint pill is shown and then immediately hidden on every no-speech / error touch-up

**File:** `CarTube/CarPlay/CarPlayViewController.swift:198-201`
**Also implicated:** `CarTube/Speech/SpeechRecognizerService.swift:199-202`, `:220-240`; `CarTube/CarPlay/MicButton.swift:79-89`, `:143-147`; `CarTube/Views/Debug.swift:244-247` (same pattern in the preview host)

**Issue:**
`stopListening()` is synchronous end-to-end: it calls `finalize(outcome:)`, which — for `.noSpeech`/`.unavailable` — calls `onFailure(outcome)` **before returning**. `CarPlayViewController`'s `onTouchUp` closure is:

```swift
micButton.onTouchUp = { [weak self] in
    self?.speechService?.stopListening()   // synchronously triggers onFailure -> micButton.showHint(...) -> showPill() (pill now visible)
    self?.micButton.setListening(false)    // synchronously calls hidePill(), which immediately re-hides it
}
```

`onFailure` (wired in `refreshMicButtonVisibility`) calls `self.micButton.showHint(hint) { ... }`, which calls `showPill(text:)` and makes `pillBackground` visible **immediately**. Control then returns up the call stack to the very next statement, `self?.micButton.setListening(false)`, whose `else` branch calls `hidePill()`:

```swift
private func hidePill() {
    hintDismissWorkItem?.cancel()
    hintDismissWorkItem = nil
    pillBackground.isHidden = true   // undoes the pill that was just shown, in the same call stack
}
```

This is deterministic, not a race: on **every** release with an empty/failed transcript, the "Didn't catch that" / "Voice search unavailable" hint is shown and then hidden within the same synchronous call stack, so the driver never sees it. This defeats the core failure-feedback UX this phase was built to deliver, and it is invisible to the current test suite because `SpeechRecognizerServiceTests` / `SpeechAvailabilityGateTests` drive the service with bare closures and never call through `MicButton.setListening(false)` afterward.

**Fix:** Don't unconditionally call `setListening(false)` after `stopListening()`. Either have `MicButton` own the state transition (e.g. `stopListening()` returns/reports the outcome and the caller decides idle vs. hint), or have `showHint`/`showPill` ignore a `hidePill()` call that arrives in the same run-loop turn a hint was just shown, e.g.:

```swift
micButton.onTouchUp = { [weak self] in
    self?.speechService?.stopListening()
    self?.micButton.stopListeningVisuals() // only resets color/pulse, never touches an active hint pill
}
```

### CR-02: Mic button shows "Listening…" (red, pulsing) even when `startListening()` silently failed to start

**File:** `CarTube/Speech/SpeechRecognizerService.swift:159-163`
**Also implicated:** `CarTube/CarPlay/CarPlayViewController.swift:194-197`

**Issue:**
```swift
do {
    try audioSession.activateForRecording()
} catch {
    return   // no onFailure call, isListening stays false — total silence
}
```
If activating the recording session throws (mic busy with another audio session, e.g. an active phone call — a realistic scenario in a car), `startListening()` returns having done nothing and without ever calling `onFailure`. Meanwhile `CarPlayViewController.onTouchDown` runs the next statement unconditionally:
```swift
micButton.onTouchDown = { [weak self] in
    self?.speechService?.startListening()
    self?.micButton.setListening(true)   // always shown, regardless of whether startListening succeeded
}
```
So the button turns red and starts pulsing as if actively listening, while no audio session, tap, or recognition task exists. On release, `stopListening()`'s `guard isListening else { return }` is a no-op (since `isListening` was never set true), so no hint is ever shown either — the driver holds the mic, sees "Listening…", releases, and gets zero explanation for why nothing happened.

A related but slightly different manifestation: if `audioEngine.start()` throws instead, `finalize(outcome: .unavailable)` **does** run and calls `onFailure` synchronously (showing the "Voice search unavailable" pill) — but `CarPlayViewController.onTouchDown`'s next line, `micButton.setListening(true)`, runs immediately after and overwrites that pill with "Listening…", again presenting a false "actively listening" state.

**Fix:** Make `startListening()` report success/failure (return `Bool`, or call `onFailure` on every early-return path) and only flip the button to the listening visual state when it actually succeeded:
```swift
micButton.onTouchDown = { [weak self] in
    guard self?.speechService?.startListening() == true else { return }
    self?.micButton.setListening(true)
}
```

### CR-03: Denying speech recognition on the onboarding screen permanently strands the user in "needs onboarding" — the documented "Open Settings" recovery path is unreachable

**File:** `CarTube/Views/VoiceSearchSetup.swift:109-123`
**Also implicated:** `CarTube/Speech/VoiceSearchAvailability.swift:25-27`

**Issue:**
```swift
private func enableVoiceSearch() {
    SFSpeechRecognizer.requestAuthorization { speechStatus in
        DispatchQueue.main.async {
            guard speechStatus == .authorized else {
                refresh()
                return          // <- microphone permission is never requested
            }
            AVAudioSession.sharedInstance().requestRecordPermission { _ in ... }
        }
    }
}
```
If the user denies the speech-recognition system prompt, the mic permission request is skipped entirely, so `AVAudioSession.sharedInstance().recordPermission` remains `.undetermined` forever. `VoiceSearchAvailability.evaluate` checks mic-undetermined **before** speech status:
```swift
switch (speechStatus, micStatus) {
case (.notDetermined, _), (_, .undetermined):
    return .needsOnboarding
...
```
so `evaluate(speechStatus: .denied, micStatus: .undetermined, ...)` returns `.needsOnboarding`, not `.denied` — even though the UI-SPEC (05-UI-SPEC.md, "partial grant treated as denied") explicitly calls for the denied/partial-grant copy and the "Open Settings" CTA in exactly this situation. The onboarding screen keeps showing the "Enable Voice Search" button. Tapping it again calls `SFSpeechRecognizer.requestAuthorization` a second time, but iOS does not re-prompt once a status is decided — it invokes the completion handler immediately with `.denied`, hitting the same early `return` with no visible system dialog and no state change. The user is now stuck: the screen offers only a CTA that visibly does nothing, and the "Open Settings" deep-link that would let them recover is never shown because that copy only renders for `.denied`/`.limited`/`.ready`, not `.needsOnboarding`.

**Fix:** Always attempt to move both permissions forward regardless of the first result, so a real decided state (`.denied`) is reached instead of getting stuck on `.undetermined`:
```swift
private func enableVoiceSearch() {
    SFSpeechRecognizer.requestAuthorization { _ in
        DispatchQueue.main.async {
            AVAudioSession.sharedInstance().requestRecordPermission { _ in
                DispatchQueue.main.async { refresh() }
            }
        }
    }
}
```

### Warnings

### WR-01: Mic button y-position is computed from `view.safeAreaInsets.top` before the view has ever been laid out

**File:** `CarTube/CarPlay/CarPlayViewController.swift:183-192`

**Issue:** `viewDidLoad` runs when `CarPlaySceneDelegate` sets `window.rootViewController = viewController`, which happens **before** `window.makeKeyAndVisible()` (`CarPlaySceneDelegate.swift:19-21`). At that point the view has not been through a layout pass, so `view.safeAreaInsets.top` is very likely `.zero` regardless of the actual CarPlay display's safe area. The mic button frame is computed once, here, and never recalculated (no `viewDidLayoutSubviews` override touches `micButton.frame`), so on any head unit with a non-zero top safe area the button ships pinned at `y = 16` instead of `16pt below the top safe-area edge` as specified.

**Fix:** Recompute (or at least re-apply) the mic button's frame in `viewDidLayoutSubviews()`:
```swift
override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    micButton.frame.origin.y = view.safeAreaInsets.top + 16.0
}
```

### WR-02: `SpeechRecognizerService` has no teardown path if the owner drops its reference mid-session

**File:** `CarTube/Speech/SpeechRecognizerService.swift` (whole class — no `deinit`); `CarTube/CarPlay/CarPlayViewController.swift:232-236`

**Issue:** `refreshMicButtonVisibility()` does `speechService = nil` whenever the availability gate stops returning `.ready` (e.g. `viewWillAppear` re-runs after the user revokes a permission in Settings while the CarPlay screen is active). If this fires while a session is actively listening (`isListening == true`), the strong reference to `SpeechRecognizerService` is dropped without ever calling `stopListening()`/`finalize()`. There is no `deinit` to force cleanup, so `NotificationCenter.default.addObserver(forName: .interruptionNotification, ...)` (`SpeechRecognizerService.swift:269-279`) is never removed — it stays registered indefinitely (weak-captured, so it won't crash, but it's a live leaked registration) — and neither `onSubmit` nor `onFailure` is ever invoked for the abandoned session.

**Fix:** Add a `deinit` that finalizes any in-flight session and always removes the interruption observer:
```swift
deinit {
    if isListening { finalize(outcome: .unavailable) }
    removeInterruptionObserver()
}
```

### WR-03: The availability-gate read is duplicated verbatim in three places

**File:** `CarTube/CarPlay/CarPlayViewController.swift:227-230`, `CarTube/Views/VoiceSearchSetup.swift:129-135`, `CarTube/Views/Debug.swift:111-116`

**Issue:** The exact same four-line sequence (`SFSpeechRecognizer.authorizationStatus()` + `AVAudioSession.sharedInstance().recordPermission` + `VoiceSearchAvailability.probeOnDeviceSupport()` + `VoiceSearchAvailability.evaluate(...)`) is copy-pasted in `CarPlayViewController.refreshMicButtonVisibility`, `VoiceSearchSetup.currentState`, and `Debug.currentVoiceSearchState`. Any future change to how the live status is read (e.g. adding a locale parameter, or an additional guard) has to be made in three places or the surfaces drift apart — which directly contradicts the file's own comment about being "the single source of truth."

**Fix:** Hoist this into a single static helper, e.g. `VoiceSearchAvailability.currentState() -> VoiceSearchState`, and call it from all three sites.

### WR-04: `MicButton` has no unit test coverage

**File:** `CarTubeTests/` (no `MicButtonTests.swift` exists)

**Issue:** `MicButton`'s pill show/hide/dismiss logic — exactly the code implicated in CR-01 — is untested. `SilenceTimerTests`, `SpeechAvailabilityGateTests`, and `SpeechRecognizerServiceTests` all drive `SpeechRecognizerService` with bare closures and never touch `MicButton.setListening`/`showHint`, so the show-then-immediately-hide regression in CR-01 has no test that would catch it (or prevent a regression once fixed).

**Fix:** Add a `MicButtonTests.swift` that asserts `pillBackground.isHidden`/`alpha` state transitions across `setListening(true)` → `showHint(...)` → `setListening(false)` sequences, mirroring the exact call order `CarPlayViewController` uses.

### WR-05: `MicButton.init(frame:)` silently discards the caller-supplied width/height

**File:** `CarTube/CarPlay/MicButton.swift:30-34`

**Issue:**
```swift
override init(frame: CGRect) {
    super.init(frame: CGRect(x: frame.origin.x, y: frame.origin.y, width: Self.diameter, height: Self.diameter))
    ...
}
```
Every caller (`CarPlayViewController.swift:187-192`, `Debug.swift:226`) happens to pass `56x56` today, so this is currently harmless, but the public initializer signature promises to honor the `frame` argument and silently ignores two of its four fields. A future caller passing a different size gets no error and no warning — just a quietly-wrong button size.

**Fix:** Either drop the `width`/`height` from the call sites entirely (`MicButton(origin: CGPoint)`) to make the fixed-size contract explicit in the API, or actually honor the passed size instead of hardcoding `Self.diameter`.

### Info

### IN-01: Redundant condition in `startListening()`

**File:** `CarTube/Speech/SpeechRecognizerService.swift:157`

**Issue:** `guard isAvailable, taskFactory.isOnDeviceSupported else { return }` checks the same underlying fact twice — `isAvailable` is set once in `init` from `taskFactory.isOnDeviceSupported` (`SpeechRecognizerService.swift:152`) and never re-evaluated, so both operands are always equal for the lifetime of the instance.

**Fix:** `guard isAvailable else { return }` is sufficient and clearer about intent (the "construction gate," per the accompanying comment).

### IN-02: Unnecessary `Task { @MainActor in ... }` wrapping around an already-main-thread call

**File:** `CarTube/CarPlay/CarPlayViewController.swift:241-243`, `CarTube/Views/Debug.swift:230-232`

**Issue:** Every call path that invokes `onSubmit` (`finalize()` from `stopListening()`, the silence timer, the interruption observer, or the async-but-main-dispatched recognizer callback) already runs on the main thread. Wrapping `CarPlaySingleton.shared.submitSearchQuery(transcript)` in a fresh `Task { @MainActor in ... }` adds an unnecessary hop to the next run-loop turn instead of calling it directly.

**Fix:** Call `CarPlaySingleton.shared.submitSearchQuery(transcript)` directly in the `onSubmit` closure; drop the `Task { @MainActor in ... }` wrapper.

---

_Reviewed: 2026-08-19_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
