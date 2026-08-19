---
phase: 05-voice-input
plan: 02
subsystem: voice-input
tags: [swiftui, speech, avfaudio, onboarding, permissions]

requires:
  - phase: 05-voice-input
    provides: "05-01's VoiceSearchAvailability.evaluate pure gating function + VoiceSearchState enum, consumed as-is by this plan's onboarding screen"
provides:
  - "VoiceSearchSetup.swift — SwiftUI Form onboarding screen: explainer + CTA (needsOnboarding), ready, limited, denied+Open Settings states, all driven by VoiceSearchAvailability.evaluate"
  - "ContentView 'Voice Search' persistent row + first-run auto-present gate on speech status .notDetermined"
  - "VoiceOnboardingStateTests.swift — 5 tests proving the verdict-to-copy mapping via the same VoiceSearchSetup.copy(for:) function the view renders"
affects: [05-03-siri]

actuals:
  tokens: 4200
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "VoiceSearchSetup.copy(for state: VoiceSearchState) -> StateCopy is the single rendering helper both the view body and VoiceOnboardingStateTests call — tests prove the real rendering path, not a parallel reimplementation of the copy strings"
    - "Struct-captured @State mutated from escaping permission-request completion handlers (SFSpeechRecognizer.requestAuthorization / AVAudioSession.requestRecordPermission), both hopped to DispatchQueue.main before touching state"

key-files:
  created:
    - CarTube/Views/VoiceSearchSetup.swift
    - CarTubeTests/VoiceOnboardingStateTests.swift
  modified:
    - CarTube/Views/ContentView.swift
    - CarTube.xcodeproj/project.pbxproj

key-decisions:
  - "VoiceSearchSetup renders every state through a single internal VoiceSearchSetup.copy(for:) static function driven by VoiceSearchAvailability.evaluate; VoiceOnboardingStateTests asserts against that same function instead of re-deriving expected copy independently, keeping the onboarding screen, its tests, and the CarPlay mic button's gate on one source of truth."
  - "First-run auto-present uses SFSpeechRecognizer.authorizationStatus() == .notDetermined directly as the gate in ContentView.onAppear — no UserDefaults flag, matching the research's don't-hand-roll guidance that system permission state is the only truth."
  - "VoiceSearchSetup wraps its own NavigationView (rather than relying on an inherited one) since it is presented as a sheet from ContentView, not pushed via NavigationLink — needed for the inline nav title and toolbar Done button to render inside the modal."

patterns-established:
  - "Onboarding-screen state rendering and CarPlay mic-button visibility now share the identical VoiceSearchAvailability.evaluate() call and VoiceSearchState enum with zero drift possible between the two surfaces."

requirements-completed: [VOX-02]

coverage:
  - id: D1
    description: "VoiceSearchSetup Form renders explainer + CTA (needsOnboarding), ready, limited, and denied+Open Settings states with exact UI-SPEC copy verbatim"
    requirement: "VOX-02"
    verification:
      - kind: unit
        ref: "CarTubeTests/VoiceOnboardingStateTests.swift (5 tests: needsOnboarding, ready, limited, denied x2, partial-grant)"
        status: pass
      - kind: other
        ref: "grep gates: 'Enable Voice Search', 'Voice search is ready', 'Voice search is limited on this device', limited body, 'Voice search is off', 'Open Settings', 'openSettingsURLString', 'recognized on your device' all present verbatim in CarTube/Views/VoiceSearchSetup.swift"
        status: pass
    human_judgment: true
    rationale: "Visual layout, wrapping, and the Form's on-device appearance (accent color rendering, spacing) are not asserted by unit tests or grep gates — a human glance at the phone simulator confirms the SwiftUI Form actually looks correct, per the phase's Manual-Only convention (no CarPlay/Siri device pass required for this plan's phone-only surface)."
  - id: D2
    description: "'Enable Voice Search' CTA requests speech authorization then mic permission on completion, both callbacks marshaled to main before updating state"
    requirement: "VOX-02"
    verification:
      - kind: other
        ref: "grep gates: 'requestAuthorization' and 'requestRecordPermission' present in CarTube/Views/VoiceSearchSetup.swift; source inspection confirms DispatchQueue.main.async wraps both completion bodies"
        status: pass
    human_judgment: false
  - id: D3
    description: "Onboarding screen consumes VoiceSearchAvailability.evaluate as its sole verdict source (no parallel status logic) and refreshes on scenePhase == .active"
    requirement: "VOX-02"
    verification:
      - kind: other
        ref: "grep count of 'VoiceSearchAvailability.evaluate' in CarTube/Views/VoiceSearchSetup.swift >= 1; .onChange(of: scenePhase) calls refresh() which re-invokes the same evaluate() call"
        status: pass
    human_judgment: false
  - id: D4
    description: "ContentView gains a persistent 'Voice Search' row (same Section as How to Use/Settings) presenting VoiceSearchSetup as a sheet, plus a first-run auto-present gate on speech status .notDetermined from the phone scene's onAppear"
    requirement: "VOX-02"
    verification:
      - kind: other
        ref: "grep gates: 'Voice Search', 'VoiceSearchSetup', 'isPresented', 'notDetermined', 'onAppear' all present in CarTube/Views/ContentView.swift; xcodebuild build succeeds"
        status: pass
    human_judgment: false
  - id: D5
    description: "Zero permission prompts can ever originate from the CarPlay scene — no requestAuthorization/requestRecordPermission call exists anywhere under CarTube/CarPlay/"
    requirement: "VOX-02"
    verification:
      - kind: other
        ref: "negative grep: `grep -rn 'requestAuthorization\\|requestRecordPermission' CarTube/CarPlay/ --include='*.swift'` returns no matches"
        status: pass
    human_judgment: false

duration: 15min
completed: 2026-08-19
status: complete
---

# Phase 05 Plan 02: Phone Voice Onboarding Summary

**SwiftUI VoiceSearchSetup Form rendering all four VoiceSearchAvailability states (needsOnboarding/ready/limited/denied) through one copy-mapping function, wired into ContentView with a persistent row and a system-status-only first-run auto-present gate.**

## Performance

- **Duration:** 15 min
- **Completed:** 2026-08-19
- **Tasks:** 2
- **Files modified:** 3 (2 created, 1 modified) + project.pbxproj wiring

## Accomplishments

- `VoiceSearchSetup.swift` ships the complete VOX-02 phone onboarding screen: the exact UI-SPEC explainer paragraph, an "Enable Voice Search" CTA (accent `#FF3B30`, not system blue) that requests speech authorization then mic permission with both completions marshaled to `DispatchQueue.main`, and ready/limited/denied state rendering — all sourced from a single `VoiceSearchSetup.copy(for state: VoiceSearchState) -> StateCopy` function driven by 05-01's `VoiceSearchAvailability.evaluate`.
- The denied state deep-links via `UIApplication.openSettingsURLString`; the screen re-evaluates on `scenePhase == .active` so a Settings change made externally is picked up on return, with zero UserDefaults-based permission caching.
- `ContentView` gained a persistent "Voice Search" row (same Section as How to Use/Settings/Debug) presenting `VoiceSearchSetup` as a sheet, plus a first-run auto-present gate on `ContentView.onAppear` keyed directly off `SFSpeechRecognizer.authorizationStatus() == .notDetermined` — the phone scene only; a negative grep confirms zero `requestAuthorization`/`requestRecordPermission` calls anywhere under `CarTube/CarPlay/`.
- `VoiceOnboardingStateTests.swift` adds 5 tests proving the verdict→copy mapping (needsOnboarding, ready, limited, denied via both speech-denied and mic-denied paths, and partial-grant collapsing to denied) by calling `VoiceSearchAvailability.evaluate` directly and asserting against the same `copy(for:)` helper the view renders — not a parallel reimplementation.

## Task Commits

Each task was committed atomically:

1. **Task 1: VoiceSearchSetup Form — all four states, CTA permission orchestration, Settings deep-link** - `65aed90` (feat)
2. **Task 2: ContentView wiring — first-run auto-present gate + persistent 'Voice Search' row** - `b688735` (feat)

## Files Created/Modified

- `CarTube/Views/VoiceSearchSetup.swift` - Onboarding `Form`: explainer section + state section (CTA/ready/limited/denied), `copy(for:)` static mapping helper, `enableVoiceSearch()` orchestration, `refresh()` re-evaluation on `scenePhase`
- `CarTubeTests/VoiceOnboardingStateTests.swift` - 5 tests: needsOnboarding→CTA, ready→ready copy, limited→limited copy, denied (speech-denied and mic-denied)→denied copy+Open Settings, partial-grant→denied
- `CarTube/Views/ContentView.swift` - `import Speech`, `showVoiceSetup` state, "Voice Search" row, `.sheet(isPresented:)`, `.onAppear` first-run gate
- `CarTube.xcodeproj/project.pbxproj` - `VoiceSearchSetup.swift` wired into the `CarTube` target's `Views` group; `VoiceOnboardingStateTests.swift` wired into the `CarTubeTests` target's group; restored `dstSubfolder = PlugIns` dropped by the `xcodeproj` gem's `project.save` (same recurring quirk documented since Phase 2)

## Decisions Made

- `VoiceSearchSetup.copy(for:)` is the single rendering helper both the view body and the test file call — see key-decisions in frontmatter for full rationale.
- First-run gate reads `SFSpeechRecognizer.authorizationStatus()` directly with no UserDefaults flag — system state is the only truth (research's Don't-Hand-Roll table).
- `VoiceSearchSetup` wraps its own `NavigationView` since it is sheet-presented, not pushed via `NavigationLink` like `HowTo`/`Settings`/`Debug`.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The `xcodeproj` gem's `project.save` again dropped `dstSubfolder = PlugIns` from the `Embed Foundation Extensions` build phase (same recurring quirk documented in Phases 2-5/01) — restored by hand immediately after the wiring pass, verified via `grep -n dstSubfolder` before running any build/test.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- VOX-02 is complete: phone-first permission onboarding exists, first-run auto-presents once and never again regardless of outcome, a persistent row provides later access, denied recovery deep-links to Settings, and the limited variant renders distinctly from denied — all backed by the same `VoiceSearchAvailability.evaluate` the CarPlay mic button consumes.
- Zero prompts possible from the CarPlay surface — grep-proven negative match across `CarTube/CarPlay/`.
- 05-03 (Siri) can proceed independently — it calls `SearchCoordinator.shared.search(_:)` directly and does not depend on anything this plan added beyond the already-shipped `VoiceSearchAvailability`.
- Two Manual-Only rows remain open from 05-01, unaffected by this plan: live listening-state visibility on a real car screen, and webview-audio survival during recording — both pending the CarPlay entitlement's remaining Xcode-signing steps.

## Self-Check: PASSED

- `[ -f CarTube/Views/VoiceSearchSetup.swift ]` and `[ -f CarTubeTests/VoiceOnboardingStateTests.swift ]` both confirmed present on disk
- `git log --oneline --all --grep="05-02"` returns both task commits: `65aed90`, `b688735`
- All task-level `<acceptance_criteria>` re-verified: `VoiceOnboardingStateTests` 5/5 green via `-only-testing:CarTubeTests/VoiceOnboardingStateTests`; every UI-SPEC copy string grep-gate passes; `VoiceSearchAvailability.evaluate` count >= 1; no `exit(0)`; ContentView row/sheet/first-run greps pass; negative grep confirms zero `requestAuthorization`/`requestRecordPermission` under `CarTube/CarPlay/`
- Plan-level `<verification>` re-run: full `xcodebuild test` on the `CarTube` scheme — **82/82 tests passing**, `BUILD SUCCEEDED`

---
*Phase: 05-voice-input*
*Completed: 2026-08-19*
