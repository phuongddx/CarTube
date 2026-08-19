---
phase: 05-voice-input
plan: 01
subsystem: voice-input
tags: [speech, avfaudio, avaudioengine, sfspeechrecognizer, uikit, carplay, push-to-talk]

requires:
  - phase: 04-carplay-search-surface
    provides: SearchCoordinator.search(_:) funnel, CarPlaySingleton.submitSearchQuery passthrough, SearchResultsViewController overlay wired below screenOffLabel
provides:
  - Construction-gated push-to-talk SpeechRecognizerService with app-side silence auto-stop
  - VoiceSearchAvailability pure gating function (single source of truth for mic visibility, consumed by 05-02's onboarding screen)
  - MicButton reusable UIKit component (idle/listening/hint states, pulse, pills)
  - CarPlayViewController mic wiring landing on the existing Phase 4 funnel
  - Both VOX-02 purpose strings committed with the first speech code
  - Phone-simulator Voice Search Preview harness (Debug screen)
affects: [05-02-onboarding, 05-03-siri]

actuals:
  tokens: 30000
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "Three-protocol injectable seam (AudioEngineControlling / AudioSessionControlling / RecognitionTaskFactory) hides AVAudioEngine + AVAudioSession + SFSpeechRecognizer behind test doubles, proving the full push-to-talk lifecycle — including silence-timer and teardown-ordering — with zero live audio"
    - "Pure gating enum + evaluate() function (VoiceSearchAvailability) as the single source of truth two independent UI surfaces (CarPlay mic button, later phone onboarding) consume"

key-files:
  created:
    - CarTube/Speech/VoiceSearchAvailability.swift
    - CarTube/Speech/SpeechRecognizerService.swift
    - CarTube/CarPlay/MicButton.swift
    - CarTubeTests/SpeechRecognizerServiceTests.swift
    - CarTubeTests/SpeechAvailabilityGateTests.swift
    - CarTubeTests/SilenceTimerTests.swift
  modified:
    - CarTube/Info.plist
    - CarTube/CarPlay/CarPlayViewController.swift
    - CarTube/Views/Debug.swift
    - CarTube.xcodeproj/project.pbxproj

key-decisions:
  - "SpeechRecognizerService is construction-gated on SFSpeechRecognizer.supportsOnDeviceRecognition (checked at init and re-asserted at startListening()) — a request is never built past a failed gate, so no server-based recognition path exists anywhere (Pitfall 5)."
  - "Built MicButton's full idle/listening/hint surface and CarPlayViewController's complete production wiring (transcript submit, hint display, availability re-check) in Task 1 rather than deferring hint-display wiring to Task 2 — Task 2/3's file lists never include CarPlayViewController.swift, and leaving hints unwired would have made the UI-SPEC's 'Didn't catch that' / 'Voice search unavailable' copy unreachable in the shipped app for this plan."
  - "Added an AudioSessionControlling seam (not explicitly named in the plan's Task 1 prose) alongside the two named protocols, so Task 3's teardown-ordering test (removeTap -> engine stop -> endAudio -> session deactivate) could be asserted via protocol spies rather than against the real AVAudioSession."
  - "onFailure: (VoiceSearchOutcome) -> Void carries noSpeech/unavailable outcomes back to CarPlayViewController so the exact hint pill and a visibility re-check both fire in production, distinct from onSubmit which only ever carries a successful transcript."

patterns-established:
  - "Push-to-talk lifecycle pattern: touch-down configures+activates the audio session, installs the input tap, starts the engine, and launches recognition; touch-up or the silence timer finalize through one shared path (removeTap -> engine stop -> endAudio -> session deactivate) that always emits exactly one outcome per press."

requirements-completed: [VOX-01, VOX-02]

coverage:
  - id: D1
    description: "Holding the mic button starts listening, releasing submits the final transcript through the existing SearchCoordinator.search funnel and the Phase 4 overlay appears"
    requirement: "VOX-01"
    verification:
      - kind: unit
        ref: "CarTubeTests/SpeechRecognizerServiceTests.swift#testFinalTranscriptDeliversExactlyOneSubmitAndRoutesThroughFunnelToOverlay"
        status: pass
      - kind: manual_procedural
        ref: "Deferred to the Debug 'Voice Search Preview' section (Task 3) or a CarPlay-entitled simulator run — no CarPlay entitlement/simulator scene available in this environment"
        status: unknown
    human_judgment: true
    rationale: "The on-CarPlay visual hold-to-talk interaction requires either a CarPlay-entitled simulator scene or the phone-preview harness; the funnel routing itself is unit-proven end to end with a stubbed recognition seam and a real SearchCoordinator."
  - id: D2
    description: "Mic button is visible iff speech authorized AND mic granted AND on-device recognition supported; hidden while the results overlay is visible and restored on dismissal"
    requirement: "VOX-01"
    verification:
      - kind: unit
        ref: "CarTubeTests/SpeechAvailabilityGateTests.swift (7 verdict-row tests: ready/limited/needsOnboarding x2/restricted-denied/denied/partial-grant x2)"
        status: pass
      - kind: automated_ui
        ref: "grep gates: belowSubview screenOffLabel wiring, no webView references in the mic-related methods"
        status: pass
    human_judgment: false
  - id: D3
    description: "Listening state is visible at a glance: fill flips to systemRed, 0.8s autoreverse pulse, 'Listening…' pill from touch-down until session end"
    requirement: "VOX-01"
    verification:
      - kind: automated_ui
        ref: "grep gates on CarTube/CarPlay/MicButton.swift: 56.0, CABasicAnimation, 0.8, 'Listening…', accessibilityLabel 'Voice search'"
        status: pass
      - kind: manual_procedural
        ref: "Live pulse/pill rendering deferred to the Debug Voice Search Preview harness or a device pass"
        status: unknown
    human_judgment: true
    rationale: "Pulse animation and pill layout are visual outcomes a unit test cannot assert; the harness built in Task 3 makes this drivable on the phone simulator."
  - id: D4
    description: "Recognition service is construction-gated on on-device support; no code path falls back to server-based recognition"
    requirement: "VOX-01"
    verification:
      - kind: unit
        ref: "CarTubeTests/SpeechRecognizerServiceTests.swift#testConstructionGateBlocksServiceWhenOnDeviceSupportIsUnavailable"
        status: pass
      - kind: other
        ref: "grep gate: requiresOnDeviceRecognition = true present in CarTube/Speech/SpeechRecognizerService.swift"
        status: pass
    human_judgment: false
  - id: D5
    description: "App-side silence auto-stop: >=1.8s unchanged non-empty transcript or a 10.0s hard cap finalizes exactly as touch-up would; one press = one session, no re-arm while held"
    requirement: "VOX-01"
    verification:
      - kind: unit
        ref: "CarTubeTests/SilenceTimerTests.swift (5 tests: 1.9s finalize, 1.7s no-early-fire, 10.0s hard cap, no re-arm, teardown ordering)"
        status: pass
    human_judgment: false
  - id: D6
    description: "Touch-up (all three UIControl events) stops listening and submits; empty transcript shows the hint pill, never shows the overlay, spends no API call"
    requirement: "VOX-01"
    verification:
      - kind: unit
        ref: "CarTubeTests/SpeechRecognizerServiceTests.swift#testEmptyTranscriptOnSessionEndNeverSubmits"
        status: pass
    human_judgment: false
  - id: D7
    description: "Recognition failures map to spec copy (kAFAssistantErrorDomain 1110/1700/1101/1107/1100, kLSRErrorDomain 102/201) with a visibility re-check"
    requirement: "VOX-01"
    verification:
      - kind: unit
        ref: "CarTubeTests/SpeechAvailabilityGateTests.swift (error-mapping tests covering the full Pitfall-6 table + unknown-domain default)"
        status: pass
    human_judgment: false
  - id: D8
    description: "Audio session coexists with webview playback (.playAndRecord + .mixWithOthers + .defaultToSpeaker, active only while listening); interruption .began stops listening without auto-resume"
    requirement: "VOX-01"
    verification:
      - kind: unit
        ref: "CarTubeTests/SilenceTimerTests.swift#testTeardownOrderingRemoveTapEngineStopEndAudioSessionDeactivate"
        status: pass
      - kind: manual_procedural
        ref: "Webview-audio-survival-during-recording on a real head unit is a 05-VALIDATION.md Manual-Only row (research assumption A2)"
        status: unknown
    human_judgment: true
    rationale: "WebKit's interaction with a same-app audio-session category change is undocumented by Apple; the session lifecycle and interruption handling are unit-proven, but real webview-audio coexistence needs a device pass."
  - id: D9
    description: "Both purpose strings committed in the same commit as the first speech code"
    requirement: "VOX-02"
    verification:
      - kind: unit
        ref: "plutil -extract NSMicrophoneUsageDescription/NSSpeechRecognitionUsageDescription raw CarTube/Info.plist"
        status: pass
    human_judgment: false
  - id: D10
    description: "CarPlaySingleton gains zero new methods across all three tasks; the transcript rides the existing submitSearchQuery passthrough"
    requirement: "VOX-01"
    verification:
      - kind: other
        ref: "git diff HEAD~3 -- CarTube/CarPlay/CarPlaySingleton.swift (0 lines across all three task commits)"
        status: pass
    human_judgment: false
  - id: D11
    description: "The mic surface is drivable on the phone simulator via a Debug 'Voice Search Preview' section embedding the production MicButton and real service"
    requirement: "VOX-01"
    verification:
      - kind: other
        ref: "grep gates: 'Voice Search Preview' and 'MicButton' present in CarTube/Views/Debug.swift; full xcodebuild build succeeds"
        status: pass
      - kind: manual_procedural
        ref: "Visual confirmation on the phone simulator (button renders, pulses, submits) not run interactively this session"
        status: unknown
    human_judgment: true
    rationale: "The harness's build-time and grep-gate proof is automated; whether it actually looks/feels right needs a human glance at the simulator."

duration: 45min
completed: 2026-08-19
status: complete
---

# Phase 05 Plan 01: End-to-End Push-to-Talk Voice Search Summary

**Construction-gated on-device SpeechRecognizerService (AVAudioEngine + SFSpeechRecognizer, zero server-recognition fallback) with an app-side silence timer, a pure VoiceSearchAvailability gate, and a 56pt MicButton wired into the CarPlay screen's existing Phase 4 search funnel — plus both VOX-02 purpose strings and a phone-simulator preview harness.**

## Performance

- **Duration:** 45 min
- **Completed:** 2026-08-19
- **Tasks:** 3
- **Files modified:** 10 (6 created, 4 modified)

## Accomplishments

- Hold-to-talk on the CarPlay mic button now runs the entire voice path — availability gate, audio session, engine tap, on-device recognition, finalization — and lands the spoken query on the existing `SearchCoordinator.search` → Phase 4 overlay funnel, with zero changes to `CarPlaySingleton`'s surface.
- `SpeechRecognizerService` is construction-gated on `supportsOnDeviceRecognition`: no `SFSpeechAudioBufferRecognitionRequest` is ever built past a failed gate, and the full Pitfall-6 error taxonomy (`kAFAssistantErrorDomain`/`kLSRErrorDomain`) maps every recognition failure to `noSpeech` or `unavailable` — never to a silent server-recognition fallback.
- Buffer-based recognition never self-finalizes (Apple's documented behavior); a repeating 0.3s app-side timer now finalizes on ≥1.8s of unchanged non-empty transcript or a 10.0s hard cap, through the exact same teardown path as touch-up (`removeTap → engine stop → endAudio → session deactivate`), with an `AVAudioSession.interruptionNotification` observer that stops listening without auto-resuming.
- `MicButton` (idle `#1C1C1E` / listening `systemRed` fill, 0.8s pulse, "Listening…" pill, "Didn't catch that" / "Voice search unavailable" hint pills) and `VoiceSearchAvailability.evaluate` (pure, no UIKit) are both reusable contracts 05-02's onboarding screen and 05-03's Siri intent build on.
- `CarTube/Views/Debug.swift` gained a "Voice Search Preview" section embedding the production `MicButton` and a real `SpeechRecognizerService`, so the whole mic surface is exercisable on the phone simulator regardless of the pending CarPlay entitlement.

## Task Commits

Each task was committed atomically:

1. **Task 1: End-to-end push-to-talk — one path (funnel, gate, purpose strings)** - `9054ec3` (feat)
2. **Task 2: Availability matrix + error taxonomy + hint pills** - `4a34bdc` (test)
3. **Task 3: Silence timer + lifecycle hardening + phone-simulator harness** - `93693cd` (feat)

_Note: tasks were TDD-flagged but each produced a single production-quality commit per the plan's own action text ("GREEN → single commit" / "GREEN → commit"), rather than separate RED/GREEN commits — tests were written and run to green before each commit, verified via the automated verify gates below._

## Files Created/Modified

- `CarTube/Speech/VoiceSearchAvailability.swift` - Pure `VoiceSearchState` enum + `evaluate(speechStatus:micStatus:onDeviceSupported:)` matching Pattern 3 verbatim, plus the on-device support probe; imports Speech/AVFAudio only
- `CarTube/Speech/SpeechRecognizerService.swift` - Construction-gated push-to-talk service: `AudioEngineControlling`/`AudioSessionControlling`/`RecognitionTaskFactory` protocols + real implementations, the full lifecycle (start/stop/finalize), silence timer, interruption observer, and the Pitfall-6 `mapError` table
- `CarTube/CarPlay/MicButton.swift` - 56pt circular `UIButton`-owning `UIView`: idle/listening/hint states, `CABasicAnimation` pulse, "Listening…" pill, `showHint(_:onDismiss:)` for the two failure hints
- `CarTube/CarPlay/CarPlayViewController.swift` - `micButton`/`speechService` properties, insertion below `screenOffLabel`, touch-down/up wiring, `refreshMicButtonVisibility()` called from `viewDidLoad`/`viewWillAppear`/`showSearchResults`/`dismissSearchResults`
- `CarTube/Info.plist` - `NSMicrophoneUsageDescription` + `NSSpeechRecognitionUsageDescription` with the exact UI-SPEC copy
- `CarTube/Views/Debug.swift` - "Voice Search Preview" section + `VoiceSearchPreviewHost` (`UIViewRepresentable` embedding the production `MicButton`)
- `CarTubeTests/SpeechRecognizerServiceTests.swift` - Funnel routing (stub → `onSubmit` → `SearchCoordinator` `[loading, results]`), construction gate, empty-transcript no-submit; shared test doubles (`FakeAudioEngineControlling`, `FakeAudioSessionControlling`, `FakeRecognitionRequest`, `FakeRecognitionTaskFactory`, `CallRecorder`)
- `CarTubeTests/SpeechAvailabilityGateTests.swift` - Full availability matrix (7 verdict rows), Pitfall-6 error-mapping table, empty-session and mid-session-failure `onFailure` routing
- `CarTubeTests/SilenceTimerTests.swift` - 1.9s finalize, 1.7s no-early-fire, 10.0s hard cap, no-re-arm, and teardown-ordering (via `CallRecorder` spies)
- `CarTube.xcodeproj/project.pbxproj` - New `Speech` group + 6 new source/test files wired into the `CarTube`/`CarTubeTests` targets; the recurring `xcodeproj` gem `dstSubfolder = PlugIns` drop (documented since Phase 2) was restored after each of the three wiring passes

## Decisions Made

- `SpeechRecognizerService` construction-gated on `supportsOnDeviceRecognition`, re-asserted at `startListening()` — see key-decisions in frontmatter for the full rationale (Pitfall 5).
- Built the complete `MicButton` hint surface and `CarPlayViewController` wiring in Task 1 (the tracer task) rather than splitting hint-display wiring into a later task whose file list never includes `CarPlayViewController.swift` — see key-decisions in frontmatter.
- Added an `AudioSessionControlling` seam beyond the two protocols the plan's Task 1 prose named explicitly, so Task 3's teardown-ordering test could assert `removeTap → engine stop → endAudio → session deactivate` via protocol spies instead of the real `AVAudioSession`.
- `onFailure: (VoiceSearchOutcome) -> Void` is a distinct closure from `onSubmit`, carrying only `noSpeech`/`unavailable` outcomes back to the caller so hint-pill copy and the availability re-check both fire correctly in production.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Comment accidentally embedded the banned legacy error-domain symbol as prose**
- **Found during:** Task 2 (running the negative grep gate `! grep -rq 'SFSpeechRecognizerErrorDomain' CarTube/Speech/`)
- **Issue:** An explanatory comment on `mapError` read "...never on the legacy SFSpeechRecognizerErrorDomain constants..." — the grep gate matches the symbol name anywhere in the file, including comments, and doesn't distinguish code from prose
- **Fix:** Reworded the comment to describe the same fact without naming the literal symbol
- **Files modified:** `CarTube/Speech/SpeechRecognizerService.swift`
- **Verification:** Negative grep gate passes; full suite still green
- **Committed in:** `4a34bdc` (Task 2 commit)

**2. [Rule 3 - Blocking] `xcodeproj` gem dropped `dstSubfolder = PlugIns` from the Embed Foundation Extensions build phase on all three wiring passes**
- **Found during:** Tasks 1, 2, and 3 (each `project.save` call)
- **Issue:** Same recurring `xcodeproj` gem quirk documented since Phase 2/3/4 — every `project.save` silently strips this attribute from the `PBXCopyFilesBuildPhase`, which the gem doesn't recognize
- **Fix:** Restored the line by hand immediately after each wiring pass, before running any build/test
- **Files modified:** `CarTube.xcodeproj/project.pbxproj`
- **Verification:** `grep -n dstSubfolder` confirmed present before each commit; `BUILD SUCCEEDED` on the full scheme after Task 3
- **Committed in:** `9054ec3`, `4a34bdc`, `93693cd` (each task's own commit)

---

**Total deviations:** 2 auto-fixed (1 Rule-1 comment fix, 1 Rule-3 recurring tooling quirk restored 3x)
**Impact on plan:** Both fixes necessary for correctness (a passing negative grep gate; a correctly-configured extension-embedding build phase). No scope creep — no behavior changed beyond what the plan specified.

## Issues Encountered

- No CarPlay entitlement/simulator scene is available in this environment (same standing blocker as Phases 3-4), so the on-CarPlay visual pass (hold mic → pulse/pill → release → overlay) could not be executed here. This is explicitly the plan's own entitlement contingency: the Debug "Voice Search Preview" section (Task 3) makes the identical `MicButton` + `SpeechRecognizerService` pair drivable on the phone simulator, and the funnel/gate/timer/error-mapping logic is fully unit-proven (23 new tests, 77/77 total passing) independent of any live audio or CarPlay hardware.
- The `xcodeproj` gem's `project.save` re-created the `Speech` `PBXGroup` without a `path` attribute on the first wiring pass, producing "Build input files cannot be found" for both new Speech/ files; fixed by setting `path = Speech` on the group in a follow-up gem invocation before the first test run (documented as a new instance of the established gem-quirk pattern, not a new class of problem).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `VoiceSearchAvailability.evaluate` and `VoiceSearchState` are ready for 05-02's phone onboarding screen to consume as-is (same pure function, same enum).
- `MicButton` and `SpeechRecognizerService`'s `onSubmit`/`onFailure` seams are a stable contract; 05-03's Siri intent calls `SearchCoordinator.shared.search(_:)` directly and does not need to touch either.
- The 3-passthrough `CarPlaySingleton` milestone cap remains fully spent from Phase 4 — this plan added zero new singleton surface, confirmed by a zero-diff check across all three task commits.
- Two Manual-Only rows from 05-VALIDATION.md remain open pending the CarPlay entitlement's remaining Xcode-signing steps: live listening-state visibility on a real car screen, and webview-audio survival during recording on a real head unit (research assumption A2). Both are otherwise fully covered by unit tests and the phone-preview harness.

## Self-Check: PASSED

- All `key-files.created` verified present on disk via successful `xcodebuild build`/`test` runs referencing them
- `git log --oneline --grep="05-01"` — not used as the grep key since task commits used `feat(05-01)`/`test(05-01)` subjects; verified instead via `git log --oneline -3` showing `9054ec3`, `4a34bdc`, `93693cd` in sequence on this branch
- All task-level `<acceptance_criteria>` re-verified: purpose strings (plutil), funnel/gate/timer tests (23 new, 0 failures), `requiresOnDeviceRecognition = true` / `.mixWithOthers` / `.defaultToSpeaker` / `notifyOthersOnDeactivation` / `endAudio` present, MicButton copy/dimension/animation greps, zero `CarPlaySingleton.swift` diff across all three commits, `VoiceSearchAvailability.swift` imports no UIKit, no legacy `SFSpeechRecognizerErrorDomain` string anywhere under `CarTube/Speech/`
- Plan-level `<verification>` re-run: full `xcodebuild test` on the `CarTube` scheme — **77/77 tests passing**, `BUILD SUCCEEDED`

---
*Phase: 05-voice-input*
*Completed: 2026-08-19*
