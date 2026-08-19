---
phase: 05-voice-input
verified: 2026-08-19T14:10:00Z
status: passed
score: 4/4 must-haves verified (1 via accepted override)
behavior_unverified: 0
overrides_applied: 1
overrides:
  - must_have: "User can say 'Search YouTube for X' via a Siri App Shortcut with zero setup, and it produces results on the CarPlay screen"
    reason: "Xcode 26.3's appintentsmetadataprocessor rejects any AppShortcut phrase with an open-ended String parameter (error: 'Invalid parameter type. AppEntity and AppEnum are the only allowed types for query'), independently reproduced during verification. Only AppEntity/AppEnum-typed parameters can appear in a phrase — this is a hard SDK constraint, not a workaround. The shipped design (parameterless trigger phrase + requestValueDialog follow-up question) preserves zero-setup, in-process, on-the-same-funnel behavior; the only user-visible difference is a two-turn Siri conversation instead of one-turn."
    accepted_by: "PhuongDoan"
    accepted_at: "2026-08-19T08:25:56Z"
gaps: []
gaps_resolved:
  - truth: "User can say 'Search YouTube for X' via a Siri App Shortcut with zero setup, and it produces results on the CarPlay screen (ROADMAP Phase 5 Success Criterion 3; VOX-03)"
    status: overridden
    reason: >
      The shipped CarTubeShortcuts.swift ships only the parameterless phrase "Search
      YouTube in \(.applicationName)" — there is no phrase that embeds the query, so
      the literal utterance "Search YouTube for X" does not resolve the query in one
      turn. Saying "Search YouTube" (app-name qualified) triggers the shortcut, then
      SearchCarTubeIntent's requestValueDialog asks "What do you want to search for?"
      as a second turn, and the driver's answer is what reaches SearchCoordinator.
      This is a genuine Xcode/AppIntents SDK constraint, independently reproduced
      during this verification (see verification note below), not a shortcut the
      executor invented — but it is a real deviation from the literal wording of the
      roadmap's own success criterion and REQUIREMENTS.md's VOX-03 description.
      Resolved via developer-accepted override (see `overrides` above).
    artifacts:
      - path: "CarTube/Search/CarTubeShortcuts.swift"
        issue: "Only one phrase ships (parameterless); the plan's must_haves called for a parameterized phrase + parameterless fallback pair"
human_verification:
  - test: "On a real device with Siri, say 'Hey Siri, search YouTube' and confirm Siri's follow-up dialog ('What do you want to search for?') correctly captures the spoken answer and routes it to the CarPlay results overlay (05-VALIDATION.md Manual-Only row A1)"
    expected: "Two-turn conversation completes and results appear on the CarPlay screen"
    why_human: "No Siri exists on the iOS Simulator; this is device-only and already tracked as an open item against the Phase 1 CarPlay-entitlement blocker in STATE.md, not skipped"
  - test: "On a real head unit, hold the mic button and speak while a video is already playing in the webview; confirm audio continues (.mixWithOthers coexistence) instead of pausing (05-VALIDATION.md Manual-Only row A2)"
    expected: "Webview playback survives the recording session"
    why_human: "WebKit × AVAudioSession category-change interaction is undocumented by Apple and cannot be observed without a real head unit; tracked against the Phase 1 dated blocker"
  - test: "On a real CarPlay screen, hold the mic button and visually confirm the red pulse / 'Listening…' pill are glanceable at driving distance/lighting (05-VALIDATION.md row 2.5.14)"
    expected: "Listening state is visible at a glance on real automotive hardware"
    why_human: "Requires a physical head unit or the pending CarPlay entitlement; the phone-simulator Debug harness and unit tests already prove the underlying logic, but glanceability on real hardware needs a human eye"
---

# Phase 5: Voice Input Verification Report

**Phase Goal:** The driver can search hands-free — push-to-talk with on-device recognition as the fallback for non-Siri users, and a zero-setup Siri phrase — both landing on the finished search funnel
**Verified:** 2026-08-19
**Status:** passed (1 override accepted — see below)
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Driver can push-to-talk from the CarPlay screen: on-device speech recognition, mic button visible only when authorized, a visible listening state, and auto-stop on silence (ROADMAP SC1; VOX-01) | ✓ VERIFIED | `SpeechRecognizerService.swift` construction-gated on `supportsOnDeviceRecognition`, `requiresOnDeviceRecognition = true` grep-confirmed; `MicButton.swift` 56pt/`#1C1C1E`/`systemRed`/0.8s `CABasicAnimation` pulse/'Listening…' pill all present; `VoiceSearchAvailability.evaluate` gates visibility (no UIKit import, pure); `CarPlayViewController` wires touch-down/up, hides mic during overlay, restores on dismissal; silence timer (1.8s/10.0s/0.3s constants) present and unit-tested (`SilenceTimerTests`, 5/5 green). Code-review CR-01 (hint pill shown-then-hidden) and CR-02 (false "Listening…" on silent start failure) independently confirmed fixed in the current source (`stopListeningVisuals()` vs `setListening(false)` split; `startListening()` returns `Bool`), backed by a new regression test `MicButtonTests.testStopListeningVisualsPreservesAnActiveHintPill` that passes. |
| 2 | User completes microphone + speech-recognition permission onboarding on the phone before CarPlay use (both purpose strings present in the first speech commit) (ROADMAP SC2; VOX-02) | ✓ VERIFIED | `Info.plist` has both `NSMicrophoneUsageDescription`/`NSSpeechRecognitionUsageDescription` with exact UI-SPEC copy (plutil-verified). `VoiceSearchSetup.swift` renders all four states (`needsOnboarding`/`ready`/`limited`/`denied`) verbatim from the Copywriting Contract; CR-03 (denying speech permanently stranding the user in `needsOnboarding` because mic permission was never requested) independently confirmed fixed — `enableVoiceSearch()` now unconditionally requests mic permission after the speech callback regardless of outcome. `ContentView` first-run auto-present gated on `SFSpeechRecognizer.authorizationStatus() == .notDetermined`; negative grep confirms zero `requestAuthorization`/`requestRecordPermission` calls anywhere under `CarTube/CarPlay/` — prompts can only originate from the phone. |
| 3 | User can say "Search YouTube for X" via a Siri App Shortcut with zero setup, and it produces results on the CarPlay screen (ROADMAP SC3; VOX-03) | ✓ VERIFIED (override accepted) | `CarTubeShortcuts.swift` ships only `"Search YouTube in \(.applicationName)"` — no phrase embeds `$query`. I independently reproduced the build failure the SUMMARY cites: restoring the plan's original parameterized phrase (`"Search YouTube for \(\.$query) in \(.applicationName)"`) and running a real `xcodebuild build` fails at `ExtractAppIntentsMetadata` with `error: Invalid parameter type. AppEntity and AppEnum are the only allowed types for query` at the exact file/line cited — a genuine, verified Xcode 26.3/iOS 26.2 SDK constraint, not a fabricated excuse. `SearchCarTubeIntent`'s `requestValueDialog` ("What do you want to search for?") is real and unit-tested (`SearchIntentTests`, 5/5 green), so the funnel end (query → `SearchCoordinator.shared.search` → overlay) is proven — but the literal single-utterance "Search YouTube for X" experience the roadmap's own success criterion describes does not exist; it is a two-turn Siri conversation instead. |
| 4 | When speech is unavailable or denied, the mic button is hidden and typed/Siri paths remain fully usable — no dead ends (ROADMAP SC4; VOX-01 interplay) | ✓ VERIFIED | `VoiceSearchAvailability.evaluate` returns `.denied`/`.limited` for every non-ready combination, gating `micButton.isHidden` independent of the Siri intent or the typed-search overlay, neither of which reads voice-availability state at all (`SearchCarTubeIntent.perform()` and the keyboard path call `SearchCoordinator.shared.search`/`SearchCoordinator.search` directly, with no gate). Negative grep confirms zero CarPlay-surface permission prompts. |

**Score:** 3/4 truths verified (0 present-but-behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `CarTube/Info.plist` | Both purpose strings | ✓ VERIFIED | plutil-extractable, exact copy |
| `CarTube/Speech/VoiceSearchAvailability.swift` | Pure gate enum + evaluate() | ✓ VERIFIED | No UIKit import; `currentState()` hoisted per WR-03 fix |
| `CarTube/Speech/SpeechRecognizerService.swift` | Construction-gated push-to-talk service | ✓ VERIFIED | Gate, silence timer, error mapping, `deinit` teardown (WR-02) all present |
| `CarTube/CarPlay/MicButton.swift` | 56pt mic button + pill + pulse | ✓ VERIFIED | All dimensions/animations/copy grep-confirmed; `stopListeningVisuals()`/`init(origin:)` (CR-01/WR-05) present |
| `CarPlayViewController` wiring | Visibility gate, touch events, overlay interplay | ✓ VERIFIED | `refreshMicButtonVisibility` called from viewDidLoad/viewWillAppear/showSearchResults/dismissSearchResults; `viewDidLayoutSubviews` re-applies y-position (WR-01) |
| `CarTube/Views/Debug.swift` | Voice Search Preview section | ✓ VERIFIED | `VoiceSearchPreviewHost` embeds production `MicButton` + real service |
| `CarTubeTests/SpeechRecognizerServiceTests.swift`, `SpeechAvailabilityGateTests.swift`, `SilenceTimerTests.swift`, `MicButtonTests.swift` | Unit coverage | ✓ VERIFIED | All present, all green in full suite run |
| `CarTube/Views/VoiceSearchSetup.swift` | Onboarding Form, all 4 states | ✓ VERIFIED | Verbatim copy, CTA orchestration, Settings deep-link, scenePhase refresh |
| `ContentView` wiring | Persistent row + first-run gate | ✓ VERIFIED | `showVoiceSetup`, `.sheet`, `onAppear` `.notDetermined` gate |
| `CarTubeTests/VoiceOnboardingStateTests.swift` | Verdict→copy mapping tests | ✓ VERIFIED | 5/5 tests present and green |
| `CarTube/Search/SearchCarTubeIntent.swift` | AppIntent, normalize/resolve/perform | ✓ VERIFIED | `@MainActor perform()`, honest empty-query dialog, exactly one import |
| `CarTube/Search/CarTubeShortcuts.swift` | AppShortcutsProvider: parameterized + parameterless phrases | ⚠️ PARTIAL | Only the parameterless phrase ships — see gap above; build-legal and functional, but not the two-phrase design the plan specified |
| `CarTubeTests/SearchIntentTests.swift` | Parameter resolution + funnel-spy tests | ✓ VERIFIED | 5/5 tests present and green |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `MicButton.onTouchDown` | `SpeechRecognizerService.startListening()` | touch-down closure, gated on return value (CR-02 fix) | ✓ WIRED | `CarPlayViewController.swift:192-195` |
| Touch-up / silence timer | `CarPlaySingleton.shared.submitSearchQuery` | `finalize()` → `onSubmit` → singleton passthrough | ✓ WIRED | Zero diff on `CarPlaySingleton.swift` across the entire phase (`git diff` from before 05-01 to HEAD = 0 lines) |
| `VoiceSearchAvailability.evaluate` | `CarPlayViewController.refreshMicButtonVisibility` | `currentState()` helper | ✓ WIRED | Called from viewDidLoad/viewWillAppear/showSearchResults/dismissSearchResults |
| `VoiceSearchAvailability.evaluate` | `VoiceSearchSetup` state rendering | same `currentState()` helper | ✓ WIRED | One source of truth confirmed (WR-03 fix hoisted the read) |
| Recognition error | `MicButton.showHint` → visibility re-check | `onFailure` closure | ✓ WIRED | `mapError` table confirmed exhaustive against Pitfall 6; hint-then-hide bug (CR-01) fixed and regression-tested |
| Siri utterance | `SearchCarTubeIntent.perform()` → `SearchCoordinator.shared.search` | AppShortcut → requestValueDialog → resolve() | ⚠️ PARTIAL | Funnel routing itself is wired and unit-proven; the phrase-level "single utterance with embedded query" link does not exist (see gap) |

### Anti-Patterns Found

None. Scanned all phase-5-modified source files (`Speech/`, `CarPlay/MicButton.swift`, `CarPlay/CarPlayViewController.swift`, `Views/Debug.swift`, `Views/VoiceSearchSetup.swift`, `Views/ContentView.swift`, `Search/SearchCarTubeIntent.swift`, `Search/CarTubeShortcuts.swift`) for TBD/FIXME/XXX/TODO/HACK/PLACEHOLDER/empty-implementation patterns — zero matches in phase-5 code. (One pre-existing "hacky" comment in `ContentView.swift` predates this phase by years, unrelated to voice input.)

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|--------------|--------|----------|
| VOX-01 | 05-01, 05-03 | Push-to-talk, on-device recognition, gated visibility, listening state, silence auto-stop | ✓ SATISFIED | Truth 1 + Truth 4 above |
| VOX-02 | 05-01, 05-02 | Phone-first mic/speech permission onboarding, both purpose strings | ✓ SATISFIED | Truth 2 above |
| VOX-03 | 05-03 | Zero-setup Siri App Shortcut producing results on CarPlay | ✓ SATISFIED (override accepted) | Funnel and zero-setup nature intact; single-utterance phrase capture is blocked by a hard Xcode/AppIntents SDK constraint — two-turn design accepted by developer PhuongDoan on 2026-08-19 |

No orphaned requirements: REQUIREMENTS.md maps VOX-01/02/03 to Phase 5, and all three appear in at least one plan's `requirements` frontmatter field.

### Code Review Fix Verification

05-REVIEW.md found 3 critical + 5 warning issues; 05-REVIEW-FIX.md claims all 8 fixed. Independently re-verified by reading the current source (not the fix report's prose):

| Finding | Claimed Fix | Independently Confirmed |
|---------|-------------|--------------------------|
| CR-01 (hint shown-then-hidden) | `stopListeningVisuals()` added, touch-up uses it instead of `setListening(false)` | ✓ Confirmed in `MicButton.swift`/`CarPlayViewController.swift`; new regression test passes |
| CR-02 (false "Listening…" on silent failure) | `startListening()` returns `Bool`, callers gate on it | ✓ Confirmed in `SpeechRecognizerService.swift`/`CarPlayViewController.swift` |
| CR-03 (permission-denial stranding) | mic permission always requested regardless of speech result | ✓ Confirmed in `VoiceSearchSetup.swift` |
| WR-01 (safe-area y-position) | `viewDidLayoutSubviews()` re-applies position | ✓ Confirmed |
| WR-02 (no teardown on drop) | `deinit` added | ✓ Confirmed |
| WR-03 (duplicated gate read) | `VoiceSearchAvailability.currentState()` hoisted | ✓ Confirmed, all 3 call sites use it |
| WR-04 (no MicButton tests) | `MicButtonTests.swift` added | ✓ Confirmed, 4 tests, wired into target, all green |
| WR-05 (ignored frame size) | `init(origin:)` convenience initializer | ✓ Confirmed, call sites updated |

### Behavioral Spot-Checks / Test Execution

Full suite re-run in this verification session (not trusted from SUMMARY claims): `xcodebuild test` on scheme `CarTube`, iPhone Air simulator — **91/91 tests passed**, `TEST SUCCEEDED`.

Independent reproduction of the Siri-phrase build constraint: temporarily restored the plan's original two-phrase design in `CarTubeShortcuts.swift`, ran `xcodebuild build` — reproduced the exact failure `error: Invalid parameter type. AppEntity and AppEnum are the only allowed types for query` at `CarTubeShortcuts.swift:9`. Reverted via `git checkout`; confirmed working tree clean and a subsequent full test run returned to 91/91 passing.

## Gaps Summary

Three of four Phase 5 success criteria are cleanly verified with independently-reproduced evidence, and the code-review's 8 findings are all genuinely fixed in the current source (not just claimed).

The one gap: the roadmap's Success Criterion 3 and REQUIREMENTS.md's VOX-03 both describe a single-utterance Siri experience — "say 'Search YouTube for X'" — but the shipped `CarTubeShortcuts.swift` only registers a parameterless phrase ("Search YouTube"), making the actual experience a two-turn Siri conversation (trigger phrase, then a follow-up question). This was independently verified in this session to be a real, current Xcode/AppIntents SDK constraint (open-ended `String` parameters cannot be embedded in an `AppShortcut` phrase at all — only `AppEntity`/`AppEnum` can) rather than an invented shortcut. The plan's own research had already designed the parameterless-fallback contingency for exactly this scenario, and the executor disclosed the deviation transparently in the SUMMARY rather than silently shipping a broken build.

**This looks intentional and well-evidenced.** To accept this deviation, add to VERIFICATION.md frontmatter:

```yaml
overrides:
  - must_have: "User can say 'Search YouTube for X' via a Siri App Shortcut with zero setup, and it produces results on the CarPlay screen"
    reason: "Xcode 26.3's appintentsmetadataprocessor rejects any AppShortcut phrase with an open-ended String parameter (error: 'Invalid parameter type. AppEntity and AppEnum are the only allowed types for query'), independently reproduced during verification. Only AppEntity/AppEnum-typed parameters can appear in a phrase — this is a hard SDK constraint, not a workaround. The shipped design (parameterless trigger phrase + requestValueDialog follow-up question) preserves zero-setup, in-process, on-the-same-funnel behavior; the only user-visible difference is a two-turn Siri conversation instead of one-turn."
    accepted_by: "<pending — requires developer decision>"
    accepted_at: "<pending>"
```

Until that override is accepted, this phase should not be considered fully closed against its own roadmap contract — though the underlying capability (funnel routing, build-legality, zero external setup) is solid and unit-proven.

The three device-only Manual-Only rows (Siri runtime phrase capture, webview-audio survival during recording, live listening-state glanceability on real hardware) are correctly tracked as open against the pre-existing Phase 1 CarPlay-entitlement blocker in STATE.md — consistent with Phase 3/4 precedent — and are not counted as phase-5 gaps, but are listed under human verification for completeness.

---

_Verified: 2026-08-19_
_Verifier: Claude (gsd-verifier)_
