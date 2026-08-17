---
phase: 5
slug: voice-input
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-18
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (CarTubeTests target from Phase 3) |
| **Config file** | CarTube.xcodeproj shared scheme (TestAction from 03-01) |
| **Quick run command** | `xcodebuild test -project CarTube.xcodeproj -scheme CarTube -destination 'platform=iOS Simulator,name=iPhone Air' -only-testing:CarTubeTests 2>&1 | tail -3` |
| **Full suite command** | `xcodebuild test -project CarTube.xcodeproj -scheme CarTube -destination 'platform=iOS Simulator,name=iPhone Air' 2>&1 | tail -3` |
| **Estimated runtime** | ~90–150 seconds |

---

## Sampling Rate

- **After every task commit:** quick run (targeted -only-testing where the task added tests)
- **After every plan wave:** full suite
- **Before `$gsd-verify-work`:** full suite green + purpose-string build gate + speech-import boundary gate
- **Max feedback latency:** 150 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|--------|
| 05-xx-T1 (SpeechRecognizerService) | 05-01 | 1 | VOX-01 | availability gate | Service constructed only when `supportsOnDeviceRecognition == true`; never server-recognition fallback | unit | fixture-based: availability-gating logic + error mapping tests pass via xcodebuild -only-testing | ⬜ pending |
| 05-xx-T2 (silence timer) | 05-01 | 1 | VOX-01 | — | Silence timer logic (~1.8s no-transcript-change → finalize; 10s cap) testable with injected clock/protocol | unit | injected-clock tests for the timer state machine | ⬜ pending |
| 05-xx-T3 (mic button wiring) | 05-01/02 | 1–2 | VOX-01 | — | Button hidden unless authorized+available; visible listening state; z-order below screenOffLabel | source+build | grep gates (visibility condition, accessibilityLabel "Voice search") + build | ⬜ pending |
| 05-xx-T4 (purpose strings) | 05-02 | 2 | VOX-02 | crash-on-request | `NSMicrophoneUsageDescription` + `NSSpeechRecognitionUsageDescription` in Info.plist BEFORE first speech code runs | build | `plutil -extract NSMicrophoneUsageDescription raw CarTube/Info.plist` non-empty (same for speech key) — fails the task if either missing | ⬜ pending |
| 05-xx-T5 (onboarding states) | 05-02 | 2 | VOX-02 | — | Not-determined → prompt flow; denied → copy + Settings deep-link; authorized-but-unsupported → limited copy | unit+source | state-mapping unit tests + copy-string grep gates from 05-UI-SPEC | ⬜ pending |
| 05-xx-T6 (Siri intent) | 05-03 | 3 | VOX-03 | — | App Shortcut phrase with app-name token compiles (AppIntentsMetadataExtractor gate is the build itself); parameterless fallback exists | build+unit | xcodebuild build passes metadata extraction (phrase validator runs at build); intent unit test: perform() routes query → SearchCoordinator seam | ⬜ pending |
| 05-xx-T7 (no-dead-ends) | 05-03 | 3 | VOX-01/SC4 | — | Denied/unsupported → mic hidden, typed + Siri paths intact | unit | coordinator state tests: all denial paths leave funnel callable | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `CarTubeTests/SpeechAvailabilityGateTests.swift` — availability + error-mapping stubs
- [ ] `CarTubeTests/SilenceTimerTests.swift` — injected-clock timer state machine stubs
- [ ] `CarTubeTests/VoiceOnboardingStateTests.swift` — permission-state → UI-state mapping stubs
- [ ] `CarTubeTests/SearchIntentTests.swift` — intent parameter resolution stubs
- [ ] Purpose-string build gate: plutil extraction of both keys as a task-level `<automated>` (no framework needed)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Siri runtime phrase capture (arbitrary String → $query) | VOX-03 | No Siri on simulator; runtime capture unverified on iOS 16/17 (research A1) | On device: trigger Siri, speak full phrase with a novel query, confirm results overlay appears on CarPlay (or phone fallback note); record outcome — parameterless fallback is the mitigation |
| Webview audio survival during recording | VOX-01 | WebKit × audio-session interaction on real head unit undocumented (research A2) | On device with CarPlay: play video, hold mic, speak — confirm playback continues (`.mixWithOthers` path) or note pause degradation; record |
| Live listening state visibility (2.5.14) | VOX-01 | Visual/runtime behavior on car screen | Device: press-and-hold mic — confirm pulsing accent + "Listening…" pill visible; release → "Searching…" overlay |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Manual-Only coverage
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 150s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
