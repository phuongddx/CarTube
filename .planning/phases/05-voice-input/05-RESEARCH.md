# Phase 5: Voice Input - Research

**Researched:** 2026-08-18
**Domain:** SFSpeechRecognizer push-to-talk + AppIntents Siri App Shortcut, integrated into the existing CarPlay webview app
**Confidence:** HIGH for Speech framework and audio-session facts (Apple SDK headers + docs fetched this session); MEDIUM for AppIntents runtime phrase behavior (build-time rules verified from Xcode's extractor binary; runtime String-parameter filling needs device verification)

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| VOX-01 | Push-to-talk: on-device recognition, mic button visible only when authorized, visible listening state, auto-stop on silence | Speech API matrix below (§ SFSpeechRecognizer on-device), push-to-talk pattern (§ Audio pipeline), availability-gating state machine; **silence auto-stop needs a custom timer — see Pitfall 2 (UI-SPEC Q3 default is wrong)** |
| VOX-02 | Mic + speech permission onboarding on phone before CarPlay use; both purpose strings in first speech commit | Permission flow (§ Permissions); current Info.plist verified to contain **neither** key (read this session) |
| VOX-03 | "Search YouTube for X" Siri App Shortcut, zero setup, in-process | AppIntents pattern (§ Siri App Shortcut); **UI-SPEC phrase violates a build-time validation rule — see Pitfall 1; corrected phrase syntax provided** |
</phase_requirements>

## Summary

Phase 5 adds two entry surfaces onto Phase 4's finished funnel: a CarPlay push-to-talk mic button backed by on-device `SFSpeechRecognizer`, and a zero-setup Siri App Shortcut. Both terminate in `SearchCoordinator.search(query)` and change nothing in the playback path. The Speech framework facts are stable and fully verified: `supportsOnDeviceRecognition` (iOS 13+) gates the feature, `requiresOnDeviceRecognition` on the request is honored only when that gate passes, and `SFSpeechAudioBufferRecognitionRequest` never finalizes until you call `endAudio()` — silence auto-stop is therefore app-side logic, not a system service. The audio-session rules are equally firm: `.playAndRecord` is nonmixable by default and will interrupt the app's own webview audio unless `.mixWithOthers` is set.

The AppIntents side carried two surprises that the planner must absorb. First, the UI-SPEC's phrase "Search YouTube for ${query}" **fails Xcode's build-time App Shortcuts validation**: every App Shortcut utterance must contain the `${applicationName}` token, and a phrase may reference at most one parameter. The corrected shape is `"Search YouTube for \(\.$query) in \(.applicationName)"`. Second, the iOS 16-available `AppShortcut` initializer takes optional `shortTitle`/`systemImageName` (the non-optional variant is iOS 17+), and whether Siri actually fills an arbitrary open-ended String parameter into the initial utterance at runtime is not runtime-verified in this session — the robust design includes both a parameterized phrase and a parameterless phrase with `requestValueDialog`, so Siri asks a follow-up question when the parameter isn't captured.

**Primary recommendation:** Build `SpeechRecognizerService` exactly on the verified push-to-talk pattern (`AVAudioEngine` input tap → buffer request → `endAudio()` on release/silence-timer, `.playAndRecord` + `.mixWithOthers` + `.defaultToSpeaker` held only while listening); wire the Siri intent with the app-name-corrected phrase set and a parameterless fallback; keep all visibility gating in one pure function that unit tests can drive without a microphone.

## User Constraints (from approved 05-UI-SPEC + PROJECT.md — binding on the planner)

The phase has no CONTEXT.md; these are the approved-design and milestone constraints that function as locked decisions:

- **Mic button:** 56pt circular `UIButton` (`mic.fill`), pinned top-right 16pt/16pt of `CarPlayViewController.view`, inserted **below `screenOffLabel`**, visible iff speech `.authorized` AND mic granted AND `supportsOnDeviceRecognition == true`. Never prompts from CarPlay.
- **States/copy:** exact strings in 05-UI-SPEC Copywriting Contract ("Listening…", "Didn't catch that", "Voice search unavailable", onboarding copy, purpose-string text) — reuse verbatim.
- **Z-order:** `webView → noSleepView → keyboardView → resultsController.view (Phase 4) → micButton → screenOffLabel → splash`. Mic button hidden while results overlay is visible (Q2 default).
- **Interaction:** touch-down starts, touch-up (all three events) stops and submits; audio session held only while listening; empty transcript → hint pill, no API call.
- **Never falls back to server-based recognition** (ARCHITECTURE.md Anti-Pattern 5).
- **No new CarPlaySingleton methods beyond Phase 4's three** (UI-02 cap is a hard milestone rule).
- **Phone onboarding:** SwiftUI Form (`HowTo` style), first-run auto-present when `.notDetermined`, "Enable Voice Search" CTA requests speech then mic, denied state with `UIApplication.openSettingsURLString`, re-read on `scenePhase == .active`.
- **Deployment floor iOS 16.0** (raised in Phase 2) — every API used must exist there (verified matrix below).
- CarPlay entitlement may still be pending — voice work must be testable via phone-side mocks (roadmap note).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Mic capture + speech→text | App process (`SpeechRecognizerService`, AVAudioEngine/Speech) | — | Audio input is hardware-local to the iPhone; framework APIs exist only in the app process |
| Permission onboarding UI | Phone scene (SwiftUI Form) | — | System prompts render on the iPhone only; CarPlay scenes cannot present them (Pitfall 9) |
| Push-to-talk UI | CarPlay scene (UIKit subviews of `CarPlayViewController.view`) | — | The driver-facing control must live on the car screen, per UI-SPEC |
| Availability gating (button visibility) | CarPlay scene, driven by a **pure function** in `Speech/` | — | Logic must be unit-testable without CarPlay hardware; the scene only consumes the verdict |
| Siri phrase → query | AppIntents (`SearchCarTubeIntent`, in-process `perform()`) | — | App Shortcuts run in the app process; no extension target (Anti-Pattern 3) |
| Query → results → playback | Phase 4 `SearchCoordinator` (unchanged) | `CarPlaySingleton` passthroughs | VOX inputs land on the finished funnel; zero funnel changes |

## Standard Stack

All frameworks are system frameworks — **no packages are installed this phase** (Registry Safety: none, matching the UI-SPEC).

### Core

| Framework | Version floor | Purpose | Why Standard / Evidence |
|-----------|---------------|---------|--------------------------|
| Speech (`SFSpeechRecognizer`, `SFSpeechAudioBufferRecognitionRequest`) | iOS 10 (class) / **iOS 13** (on-device props) | On-device speech→text | Availability verified from SDK headers this session `[VERIFIED: iPhoneOS26.2.sdk Speech.framework/Headers/SFSpeechRecognizer.h:161, SFSpeechRecognitionRequest.h:64]`; full usage typechecks clean against an `arm64-apple-ios16.0` target |
| AVFAudio (`AVAudioEngine`, `AVAudioSession`) | iOS 8 (engine) / iOS 10 (`setCategory(_:mode:options:)`) | Mic input tap + session configuration | Tap API verified `[VERIFIED: AVAudioEngine.h:451-475, AVAudioNode.h:81-117]`; category semantics from Apple docs `[CITED: developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/playandrecord]` |
| AppIntents (`AppIntent`, `AppShortcut`, `AppShortcutsProvider`, `@Parameter`) | **iOS 16.0** (framework) | Zero-setup Siri shortcut | All used symbols carry `@available(iOS 16.0, ...)` `[VERIFIED: AppIntents.swiftinterface + sosumi + swiftc typecheck on ios16.0]`; one initializer caveat in Pitfall 3 |

### Supporting

| Framework | Version floor | Purpose | When to Use |
|-----------|---------------|---------|-------------|
| UIKit (`UIApplication.openSettingsURLString`) | iOS 8 | Denied-state deep link | Phone onboarding denied copy |
| Combine/NotificationCenter | iOS 13 | Interruption observation | Optional hardening; see Pitfall 4 |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `SFSpeechRecognizer` (classic) | `SpeechAnalyzer`/`DictationTranscriber` (iOS 26+) | Newer API is iOS 26-only and the sample "doesn't run in the iOS Simulator" `[CITED: /documentation/speech/recognizing-speech-in-live-audio]` — incompatible with the iOS 16 floor; classic API is the correct choice |
| AppIntents App Shortcut | SiriKit `INIntent` + Intents extension | Separate process can't reach `SearchCoordinator`/CarPlay; requires user setup; rejected (Anti-Pattern 3) |
| `AVAudioSession.requestRecordPermission` (deprecated iOS 17) | `AVAudioApplication.requestRecordPermission()` (iOS 17+) | The modern API is 17+ `[VERIFIED: sosumi]`; on a 16.0 floor use the deprecated one (works, deprecation warning only) or gate with `if #available(iOS 17, *)` |
| `AVCaptureDevice.requestAccess(for: .audio)` | — | Same TCC permission; used by Apple's newest sample. Either is acceptable; pick one and stay consistent |

**Installation:** none — system frameworks only.

## Package Legitimacy Audit

> No external packages this phase (system frameworks only). Audit not applicable.

**Packages removed:** none. **Packages flagged:** none.

## Architecture Patterns

### System Architecture Diagram

```
ENTRY SURFACES
  "Hey Siri, search YouTube for X in CarPlay"        touch-down on mic button (CarPlay)
          │                                                   │
  ┌───────▼────────────────┐                    ┌─────────────▼──────────────┐
  │ SearchCarTubeIntent    │                    │ MicButton (UIKit, top-right│
  │ @Parameter query:String│                    │ of CarPlayViewController)  │
  │ perform() in-process   │                    └─────────────┬──────────────┘
  └───────┬────────────────┘                                 │
          │ query: String                                    │ start/stop
          │                    ┌─────────────────────────────▼──────────────┐
          │                    │ SpeechRecognizerService                     │
          │                    │  gate: speechAuth ∧ micAuth ∧ onDevice      │
          │                    │  AVAudioEngine input tap ─┐                 │
          │                    │  .playAndRecord+.mixWithOthers (held only  │
          │                    │  while listening)          │                │
          │                    │  endAudio() on touch-up OR silence timer   │
          │                    └───────────┬────────────────┴───────────────┘
          │                                │ final transcript String
          ▼                                ▼
  ┌─────────────────────────────────────────────────────────────────────────┐
  │ SearchCoordinator.search(query)   ← PHASE 4 FUNNEL, UNCHANGED           │
  │  cache → YouTubeSearchService → SearchFallback.decide → overlay/webview │
  └─────────────────────────────────────────────────────────────────────────┘
          │                                    ▲
          ▼                                    │ dismiss + reveal
  CarPlaySingleton.showSearchResults / searchVideo (existing 3 passthroughs only)

PHONE SURFACE (VOX-02, before any CarPlay use)
  ContentView ── "Voice Search" row ── VoiceSearchSetup (Form)
      first-run auto-present when speech status == .notDetermined
      CTA: SFSpeechRecognizer.requestAuthorization → mic permission
      denied → "Open Settings" deep link; re-read on scenePhase == .active
```

### Recommended Project Structure

```
CarTube/
├── CarPlay/
│   ├── CarPlayViewController.swift   # +micButton property, insertSubview below screenOffLabel,
│   │                                 #  show/hide gating hook, no webview changes
│   └── MicButton.swift               # NEW — 56pt UIButton + listening/hint pills, pulse animation
├── Speech/                           # NEW group — mirrors ARCHITECTURE.md plan
│   ├── SpeechRecognizerService.swift # engine + request + session lifecycle
│   └── VoiceSearchAvailability.swift # NEW — pure gating function (unit-testable)
├── Search/                           # Phase 3/4 group
│   ├── SearchCoordinator.swift       # unchanged this phase
│   ├── SearchCarTubeIntent.swift     # NEW — AppIntent + @Parameter query
│   └── CarTubeShortcuts.swift        # NEW — AppShortcutsProvider
└── Views/
    ├── ContentView.swift             # + "Voice Search" row + first-run auto-present
    └── VoiceSearchSetup.swift        # NEW — phone permission onboarding Form
```

### Pattern 1: Push-to-talk lifecycle (verified against SDK headers)

**What:** One press = one recognition session. Touch-down configures and activates the audio session, starts the engine tap, and opens a buffer request; touch-up (or the silence timer) calls `endAudio()` and deactivates.

**When to use:** exactly this phase's mic button.

**Example** (annotated, every API verified):

```swift
// Sources: Speech.framework headers + developer.apple.com/documentation/speech (fetched 2026-08-18)
let session = AVAudioSession.sharedInstance()
// .playAndRecord is NONMIXABLE by default and interrupts other nonmixable sessions
// (Apple: "activating your session will interrupt any other audio sessions which are
//  also nonmixable. To allow mixing for this category, use the mixWithOthers option.")
try session.setCategory(.playAndRecord, mode: .default,
                        options: [.mixWithOthers, .defaultToSpeaker])
try session.setActive(true)

let request = SFSpeechAudioBufferRecognitionRequest()
request.shouldReportPartialResults = true   // default is true; needed for the silence timer
request.requiresOnDeviceRecognition = true  // honored ONLY if recognizer.supportsOnDeviceRecognition
//                                            == true — gate before ever starting (see Pitfall 5)

let inputNode = engine.inputNode
let format = inputNode.outputFormat(forBus: 0)
inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
    request.append(buffer)                  // recognizer analyzes continuously
}
engine.prepare()
try engine.start()

recognitionTask = recognizer.recognitionTask(with: request) { result, error in
    if let result, result.isFinal { /* final transcript → SearchCoordinator.search */ }
    if let error { /* hint pill "Voice search unavailable"; re-check availability */ }
}

// Stop (touch-up or silence):
inputNode.removeTap(onBus: 0)
engine.stop()
request.endAudio()   // REQUIRED: "The speech recognizer continuously analyzes the audio you
                     // appended, stopping only when you call the endAudio() method."
try? session.setActive(false, options: .notifyOthersOnDeactivation)
```

### Pattern 2: Siri App Shortcut with parameter + fallback (iOS 16-safe)

```swift
// Sources: AppIntents.swiftinterface (iOS 16 availability) + Xcode AppIntentsMetadataExtractor
// validation rules (fetched 2026-08-18); swiftc -target arm64-apple-ios16.0.0 typecheck passed
struct SearchCarTubeIntent: AppIntent {
    static var title: LocalizedStringResource = "Search YouTube"

    @Parameter(title: "Query",
               requestValueDialog: "What do you want to search for?")
    var query: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        SearchCoordinator.shared.search(query)
        return .result(dialog: "Showing results on your CarPlay screen.")
    }
}

struct CarTubeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SearchCarTubeIntent(),
            phrases: [
                // EVERY utterance must contain the applicationName token (build-time rule);
                // at most ONE parameter per phrase (build-time rule).
                "Search YouTube for \(\.$query) in \(.applicationName)",
                "Search YouTube in \(.applicationName)"      // fallback: Siri asks requestValueDialog
            ],
            shortTitle: "Search YouTube",                     // non-optional init is iOS 17+; this
            systemImageName: "magnifyingglass"                // optional-arg init is the 16.0 one
        )
    }
}
```

The parameterless phrase makes VOX-03 robust: when Siri doesn't capture the query into the utterance, it prompts with `requestValueDialog` (verified supported since iOS 16 — value prompts are core AppIntents, WWDC22 10170). The CarPlay-absent case lands in the existing `CarPlaySingleton.loadUrl` "CarPlay not connected" alert path; the returned `IntentDialog` tells the driver what happened.

### Pattern 3: Pure availability gating

```swift
// Speech/VoiceSearchAvailability.swift — no UIKit imports; the single source of truth for
// button visibility AND onboarding-screen state (same inputs, two consumers)
enum VoiceSearchState { case needsOnboarding, ready, limited, denied }

static func evaluate(speechStatus: SFSpeechRecognizerAuthorizationStatus,
                     micStatus: AVAudioSession.RecordPermission,
                     onDeviceSupported: Bool) -> VoiceSearchState {
    switch (speechStatus, micStatus) {
    case (.notDetermined, _), (_, .undetermined):
        return .needsOnboarding          // first-run sheet
    case (.authorized, .granted) where onDeviceSupported:
        return .ready                    // mic button visible
    case (.authorized, .granted):
        return .limited                  // authorized but no on-device model — button hidden,
                                         //   copy: "Voice search is limited on this device"
    default:
        return .denied                   // includes .restricted and partial grants (spec: partial = denied)
    }
}
```

### Anti-Patterns to Avoid

- **Server-based recognition fallback:** leaving `requiresOnDeviceRecognition` unset silently sends driver audio to Apple. Forbidden (Anti-Pattern 5, privacy labels, PITFALLS P9).
- **Growing CarPlaySingleton for voice:** speech service lives outside; the scene talks to it directly. The 3-method cap holds.
- **Prompting from the CarPlay scene:** `requestAuthorization`/mic prompts present on the iPhone; the visibility gate means the button never exists in a `.notDetermined` state, so the prompt can never originate from the car.
- **Holding the audio session open between presses:** session active only while listening (spec hard constraint; also the voice-app guideline in P9).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Speech→text | Whisper/3rd-party ASR | `SFSpeechRecognizer` on-device | System, offline, free, no privacy-label burden |
| Siri invocation plumbing | SiriKit INIntent + extension + donation | AppIntents App Shortcut | Zero setup, in-process, compile-time phrases |
| Silence detection | Full VAD / audio-level DSP | Partial-result-gap timer (see Pitfall 2) | `shouldReportPartialResults` + timestamp since last changed result is sufficient for ≤2s stop; DSP is over-engineering |
| Permission state tracking | Manual UserDefaults flags | The system status APIs (`SFSpeechRecognizer.authorizationStatus()`, `AVAudioSession.sharedInstance().recordPermission`) | System state is the only truth (Settings changes externally); UI-SPEC already mandates re-read on `scenePhase == .active` |

**Key insight:** every piece of persistent state this phase needs (both permissions, on-device support) is queryable synchronously from the system — no new UserDefaults keys at all.

## Runtime State Inventory

> Not a rename/refactor/migration phase — section omitted per protocol.

## Common Pitfalls

### Pitfall 1: The UI-SPEC phrase fails App Shortcuts build validation (CRITICAL — spec correction)

**What goes wrong:** The approved UI-SPEC specifies phrase "Search YouTube for ${query}". Xcode's App Shortcuts validation rejects it at build: the extractor enforces (strings extracted from `AppIntentsMetadataExtractor` binary this session `[VERIFIED: Xcode 26.3 Toolchains/XcodeDefault.xctoolchain/usr/lib/AppIntentsMetadataExtractor.framework]`):
- `"Invalid Utterance. Every App Shortcut utterance should have one '${applicationName}' in it."` (rule id `invalidUtteranceAppName`)
- `"Multiple parameters detected in phrase. A single phrase can only use a single parameter."` (rule id `invalidUtteranceMultipleParams`)

**How to avoid:** Use `"Search YouTube for \(\.$query) in \(.applicationName)"` (one parameter + the name token = legal). Include the parameterless `"Search YouTube in \(.applicationName)"` as the always-works fallback. This changes only the phrase strings — the spec's copy "You can also say 'Hey Siri, search YouTube for …'" remains honest because the app-name token is what the *user* speaks naturally at the end. **Flag to the user in the plan: the phrase must include the app name — spec text amended, meaning preserved.**

### Pitfall 2: "System end-of-speech detection" does not exist for buffer requests — UI-SPEC Q3 default is wrong

**What goes wrong:** UI-SPEC Q3 assumed "System end-of-speech detection finalizes recognition (typically ≤2s of silence; no custom timer)". Verified fact: buffer-based recognition **never finishes until you call `endAudio()`** — `"The speech recognizer continuously analyzes the audio you appended, stopping only when you call the endAudio() method. You must call endAudio() explicitly"` `[VERIFIED: developer.apple.com/documentation/speech/sfspeechaudiobufferrecognitionrequest]`, and `finish()`'s header: `"For audio-buffer–based recognition, recognition does not finish until this method is called"` `[VERIFIED: SFSpeechRecognitionTask.h:62]`.

**How to avoid:** Implement silence detection yourself: track the timestamp of the last *changed* partial transcript (`result.bestTranscription.formattedString` differs from previous). When ≥1.5–2.0s elapse with no change AND at least one word was recognized, finalize exactly as touch-up would (remove tap → stop engine → `endAudio()` → submit). Cap the session at ~10s as a hard backstop. One press = one session; no re-arm while held (spec). Present this as the corrected Q3 default in the plan.

### Pitfall 3: iOS 16 initializer/deprecation mismatches

- `AppShortcut(intent:phrases:shortTitle:systemImageName:)` with **non-optional** shortTitle/systemImageName is **iOS 17+**; the iOS 16 initializer takes optionals and is deprecated *from* 17 (usable, warning-free at 16) `[VERIFIED: sosumi init page + swiftinterface 9636-9641]`.
- `AVAudioSession.requestRecordPermission` is deprecated in iOS 17 → `AVAudioApplication.requestRecordPermission()` (17+) `[VERIFIED: sosumi]`. On the 16.0 floor use the deprecated one; optionally branch with `if #available(iOS 17, *)`.
- Both typecheck clean against `arm64-apple-ios16.0` (verified with swiftc this session).

### Pitfall 4: Recording interrupts the webview's own audio

**What goes wrong:** `.playAndRecord` is nonmixable by default — activating it changes the app's single `AVAudioSession`, and WebKit media plays through that same session. Setting a category while active "results in an immediate change" `[VERIFIED: setCategory docs]`. Result without `.mixWithOthers`: the video's audio pauses the moment listening starts.

**How to avoid:** always `.mixWithOthers` (+ `.defaultToSpeaker` so playback doesn't jump to the earpiece). Whether webview audio *fully* survives the category change is **not documented by Apple** — needs the on-device checkpoint (see Open Questions Q2). If it still ducks/pauses: acceptable degradation (the driver is about to search), and the overlay hides the video anyway; on session teardown use `.notifyOthersOnDeactivation` so WebKit resumes cleanly. Also observe `AVAudioSession.interruptionNotification` → `.began` → stop listening, never auto-resume unless `.shouldResume` `[CITED: handling-audio-interruptions]`.

### Pitfall 5: `requiresOnDeviceRecognition = true` does NOT fail loudly when unsupported

**What goes wrong:** Setting the request flag when `supportsOnDeviceRecognition == false` is not an error path — the docs say the request "only honors this setting if" the recognizer supports it `[VERIFIED: SFSpeechRecognitionRequest.h:62]`, i.e. recognition silently proceeds **server-based**, sending driver audio off-device — exactly what Anti-Pattern 5 forbids, invisible in testing.

**How to avoid:** gate at construction: never create the request unless the recognizer passes. The visibility gate (Pattern 3) already encodes this; the service must assert it again at `start()` and bail to the "Voice search unavailable" hint if support was withdrawn (spec: button hides on next visibility check).

### Pitfall 6: The `nil` recognizer and error paths people forget

- `SFSpeechRecognizer(locale:)` returns nil when the locale is unsupported — and `init()` returns nil if the default language fails too. Treat nil as `limited` state.
- Error taxonomy for the result handler `[VERIFIED: SFSpeechRecognitionTask.h:84-99]` — map to spec copy:
  - `kAFAssistantErrorDomain` **1110** "no speech recognized" → **"Didn't catch that"** hint, no API call
  - `kAFAssistantErrorDomain` **1700** not authorized, **1101/1107** connection invalid/interrupted, **1100** earlier instance still active → **"Voice search unavailable"** + availability re-check
  - `kLSRErrorDomain` **102** assets not installed → on-device model missing → treat as `limited`/unavailable, never fall back to server
  - `kLSRErrorDomain` **201** Siri/Dictation disabled on device → unavailable
- Legacy symbol names (`SFSpeechRecognizerErrorDomain`, `kSFSpeechRecognizerErrorCode…`) **do not exist** in the modern SDK (verified: they don't compile) — match on error *codes/domains* as strings or use the header table, don't reference legacy constants.

### Pitfall 7: Permission prompts at drive time (P9 carry-forward)

Already mitigated by design: phone-first onboarding, button gated on `.authorized`+granted, `scenePhase` re-read. One addition: the first-run auto-present must fire only from the **phone scene's** `ContentView` appear — never from CarPlay scene activation.

## Code Examples

### Availability + permission orchestration (phone CTA, VOX-02)

```swift
// Order per UI-SPEC: speech first, then mic. Both purpose strings ship in the same
// commit or the app crashes/exits on request (verified docs: missing speech key =
// crash; missing mic key = "the app exits").
func enableVoiceSearch() {
    SFSpeechRecognizer.requestAuthorization { speechStatus in
        DispatchQueue.main.async {
            guard speechStatus == .authorized else { self.state = .denied; return }
            AVAudioSession.sharedInstance().requestRecordPermission { micGranted in
                DispatchQueue.main.async {
                    self.state = micGranted ? .ready : .denied
                }
            }
        }
    }
}
```

Callbacks arrive off-main (both docs warn) — marshal before touching UI, matching the app's existing main-queue discipline.

### Silence-timed finalize (corrected VOX-01 auto-stop)

```swift
private var lastTranscriptChange = Date()
private var lastTranscript = ""

// inside the resultHandler, before the isFinal check:
let text = result.bestTranscription.formattedString
if text != lastTranscript {
    lastTranscript = text
    lastTranscriptChange = Date()
}
// A repeating 0.3s timer (started with the tap) checks:
//   Date().timeIntervalSince(lastTranscriptChange) >= 1.8 && !lastTranscript.isEmpty
//     → finalizeAndSubmit()   // identical path as touch-up
//   elapsed >= 10.0 → finalizeAndSubmit()   // hard cap
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| SiriKit custom intents + Intents extension | AppIntents in-process, zero-setup App Shortcuts | iOS 16 (2022) | No extension target, no user setup; the deployment raise makes it free |
| Phrase params: predefined entities only | Open-ended String params in phrases (claimed iOS 16.4) | iOS 16.4 (2023) — **[ASSUMED], not verified this session** | Plan must include the parameterless fallback regardless (see Open Questions Q1) |
| `requestRecordPermission` on AVAudioSession | `AVAudioApplication.requestRecordPermission` | iOS 17 (2023) | Branch or accept deprecation on the 16 floor |
| `SFSpeechRecognizer` | `SpeechAnalyzer`/`DictationTranscriber` | iOS 26 | Not usable at iOS 16 floor; classic API remains fully supported |

**Deprecated/outdated:** nothing in the chosen stack is removed at iOS 16–26; the deprecated-in-17 items are soft deprecations with working behavior.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Siri fills an arbitrary open-ended String into a phrase parameter at runtime on iOS 16.4+ | Pattern 2, State of the Art | If wrong: parameterized phrase never captures the query. Mitigated by the parameterless phrase + `requestValueDialog` fallback — worst case the driver answers one follow-up. Device checkpoint should confirm which path fires |
| A2 | With `.playAndRecord + .mixWithOthers`, WKWebView media audio keeps playing (or at worst ducks) | Pitfall 4 | If wrong: audio pauses during listening. Degradation acceptable; verify on device (Open Question Q2) |
| A3 | The phone's microphone is the capture device during a CarPlay session (car mic not exposed to apps) | Architecture | If wrong (no capture): recognition fails into "Voice search unavailable". Standard CarPlay behavior; verify at the entitlement-era device pass |
| A4 | Simulator can exercise `SFSpeechRecognizer` end-to-end (classic API) enough for CI state-machine tests | Validation Architecture | If wrong: recognition tests are device-manual; state-machine/availability/intent tests remain simulator-runnable since they never start the engine |
| A5 | Silence-detection via partial-result-change timestamps reliably finalizes within ~2s | Code Examples | If flaky: hard 10s cap bounds the session; tune constant on device |

## Open Questions

1. **Does Siri capture an arbitrary spoken string into `\(\.$query)` on iOS 16/17?**
   - What we know: the interpolation compiles at 16.0; build validation allows one param + app-name token; WWDC22/23 say phrase params are for *predefined* values; community practice suggests 16.4 added String support.
   - What's unclear: the runtime behavior on the actual device/OS matrix.
   - Recommendation: ship both phrases (Pattern 2); at first on-device checkpoint, speak the full phrase and observe which path fills `query`. If only the follow-up fires, VOX-03 still succeeds (Siri asks, driver answers) — no code change needed.
2. **Webview audio vs. recording session on a real head unit**
   - What we know: category semantics (verified); mixing option exists.
   - What's unclear: WebKit's internal session interaction with a same-app category change during CarPlay playback.
   - Recommendation: checkpoint task on the phase's device-verification day; accepted degradation is audio pause.
3. **Siri availability for testing**: Siri is not usable on the simulator; App Shortcuts Preview (Xcode 15+) tests phrase *matching* only, not runtime parameter filling. Siri-path verification is device-manual — schedule it with the entitlement-era device pass.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode | build/test | ✓ | 26.3 (Build 17C529) | — |
| iPhone simulator (test destination) | XCTest runs | ✓ | iPhone Air, iOS 26.3/26.5 runtimes; one booted | — |
| macOS | Xcode host | ✓ | 26.5.2 | — |
| Physical device + Siri | VOX-03 runtime, phrase capture | ✗ | — | Parameterless-phrase fallback; device checkpoint deferred to entitlement grant |
| CarPlay head unit / CarPlay Simulator | on-car mic button verification | ✗ (entitlement pending, Phase 1) | — | Phone-side preview harness pattern (Phase 4's Debug screen) extended with voice-state previews |
| On-device speech model (device locale) | on-device recognition | device-dependent | — | Visibility gate hides button (`limited` copy) when `supportsOnDeviceRecognition == false` |

**Missing dependencies with no fallback:** none blocking implementation and simulator-testable verification; device/CarPlay verification rides the existing entitlement contingency (roadmap note).

**Codebase preconditions verified this session (Phase 2/3/4 must have landed):** deployment target still reads `IPHONEOS_DEPLOYMENT_TARGET = 14.0` in all 6 configs today `[VERIFIED: CarTube.xcodeproj/project.pbxproj]`; `CarTube/Info.plist` contains **no** `NSMicrophoneUsageDescription`/`NSSpeechRecognitionUsageDescription` `[VERIFIED: read]`; no `import Speech`/`import AppIntents` anywhere yet; `CarTube/Search/` does not exist yet (Phase 3/4 artifacts). If Phases 3–4 are unexecuted at Phase 5 start, their plans' artifacts are hard preconditions.

## Validation Architecture

> `workflow.nyquist_validation` is enabled (config read this session).

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (target `CarTubeTests`, created in Phase 3; scheme `CarTube` shared) |
| Config file | none (scheme-based; Phase 3 wires the TestAction) |
| Quick run command | `xcodebuild -project CarTube.xcodeproj -scheme CarTube -destination 'platform=iOS Simulator,name=iPhone Air' test` |
| Full suite command | same (single target) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| VOX-01 | Availability gating: every (speechStatus × micStatus × onDevice) combination → correct `VoiceSearchState` | unit | `xcodebuild test … -only-testing:CarTubeTests/VoiceSearchAvailabilityTests` | ❌ Wave 0 |
| VOX-01 | Service lifecycle: start→stop emits exactly one transcript; empty transcript → `.empty` outcome, no search call | unit (protocol-mocked engine/request seams) | `xcodebuild test … -only-testing:CarTubeTests/SpeechRecognizerServiceTests` | ❌ Wave 0 |
| VOX-01 | Silence timer: unchanged partial for ≥1.8s (injected clock) triggers finalize; hard cap at 10s; re-arm suppressed | unit | same file as above | ❌ Wave 0 |
| VOX-03 | Intent parameter resolution: query trim/normalize; empty→ error path; perform() routes into SearchCoordinator (funnel spy) | unit | `xcodebuild test … -only-testing:CarTubeTests/SearchCarTubeIntentTests` | ❌ Wave 0 |
| VOX-02 | Purpose strings present in built app Info.plist | build-gate (script/grep on build products) | `grep` against the built `.app/Info.plist` in the verification step | ❌ Wave 0 |
| VOX-01/03 | Real mic + real Siri + CarPlay scene | manual-only (no mic capture in CI; Siri absent on simulator) | checkpoint:human-verify at device pass | n/a |

Justification for manual-only rows: `SFSpeechRecognizer` requires live audio and the recognizer service; Siri invocation requires a device. All *logic* around them is unit-tested via seams (clock injection for the silence timer, protocol doubles for engine/request, funnel spy for the intent).

### Sampling Rate

- **Per task commit:** `xcodebuild test -project CarTube.xcodeproj -scheme CarTube -destination 'platform=iOS Simulator,name=iPhone Air' test` (full run is fast; single target)
- **Per wave merge:** same + `strings` private-API gate from Phase 2 (voice adds no private symbols; keep the gate green)
- **Phase gate:** full suite green + purpose-string build-gate + device checklist (mic button states, Siri phrase, permission flows) executed at the entitlement-era device pass

### Wave 0 Gaps

- [ ] `CarTubeTests/VoiceSearchAvailabilityTests.swift` — pure gating matrix (VOX-01)
- [ ] `CarTubeTests/SpeechRecognizerServiceTests.swift` — lifecycle + silence-timer with injected clock/seams (VOX-01)
- [ ] `CarTubeTests/SearchCarTubeIntentTests.swift` — parameter resolution + funnel spy (VOX-03)
- [ ] Purpose-string build-gate step (grep on built Info.plist) (VOX-02)
- [ ] Test-target membership for the 3 new files via the Phase 3/4 ruby-gem-script convention, then delete the script

## Security Domain

> `security_enforcement: true`, ASVS level 1 (config verified this session).

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | no accounts |
| V3 Session Management | no | none |
| V4 Access Control | no | none |
| V5 Input Validation | **yes** | transcript and Siri `query` are user input → both route into the existing funnel; trim/normalize in the intent before `search()`; the funnel's existing validation (Phase 3/4) applies unchanged. Reject empty/whitespace (spec: no API call spent) |
| V6 Cryptography | no | none |
| V9 Communications (adjacent) | **yes (by omission)** | on-device recognition only — never enable server-based recognition (Anti-Pattern 5); `requiresOnDeviceRecognition = true` + construction gate |

### Known Threat Patterns for Speech/AppIntents stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Voice audio leaving the device | Information Disclosure | `requiresOnDeviceRecognition = true`, gated on `supportsOnDeviceRecognition`; no server fallback |
| Missing purpose string → crash at permission request | Denial of Service | Both keys committed in the first speech commit (build-gate above) |
| Permission prompt while driving (safety, not security) | — | Phone-first onboarding; visibility gate prevents CarPlay-originated prompts |
| Prompt/permission state drift after Settings changes | — | Status re-read on `scenePhase == .active`; system APIs are the only state |

## Sources

### Primary (HIGH confidence)

- Apple Speech framework SDK headers (iPhoneOS26.2.sdk, read this session): `SFSpeechRecognizer.h` (supportsOnDeviceRecognition L161, authorization L93-112, recognitionTask L192), `SFSpeechRecognitionRequest.h` (requiresOnDeviceRecognition L62-64), `SFSpeechRecognitionTask.h` (finish() L65, error table L84-99), `SFSpeechRecognitionTaskHint.h` (.search = 2)
- developer.apple.com/documentation/speech (via sosumi fetch): SFSpeechRecognizer, asking-permission-to-use-speech-recognition, SFSpeechAudioBufferRecognitionRequest ("You must call endAudio() explicitly"), shouldReportPartialResults, isFinal, supportsOnDeviceRecognition, requiresOnDeviceRecognition
- AppIntents.swiftinterface (iPhoneOS26.2.sdk, read this session): AppShortcutPhrase interpolation members (L1140-1150), AppShortcut inits (L9632-9645), AppShortcutPhraseToken (L1130-1138), AppShortcutsProvider (L4748-4755)
- Xcode 26.3 `AppIntentsMetadataExtractor` binary strings (read this session): `invalidUtteranceAppName`, `invalidUtteranceMultipleParams` validation rules
- developer.apple.com/documentation/avfaudio (via sosumi): playAndRecord category (nonmixable-by-default), mixWithOthers, setCategory(_:mode:options:) (immediate change while active), setActive error conditions, requestRecordPermission (deprecated 17), AVAudioApplication (17+), recordPermission statuses, handling-audio-interruptions
- WWDC22 10170 + WWDC23 10102/10103 transcripts (fetched): zero-setup confirmation, phrase parameter semantics ("not open-ended values"), phrase limits (10 shortcuts / 1000 phrases / app-name required), flexible matching (17+, free on rebuild)
- swiftc typecheck runs this session: full intent + phrases + speech usage compiled clean against `arm64-apple-ios16.0.0`
- Codebase files read this session: `CarTube/Info.plist` (no purpose strings), `CarPlayViewController.swift`, `CarPlaySingleton.swift`, `CarPlaySceneDelegate.swift`, `ContentView.swift`, `HowTo.swift`, `project.pbxproj` (deployment 14.0 ×6)

### Secondary (MEDIUM confidence)

- iOS 16.4 "String parameters in App Shortcut phrases" — community-held belief; could not be confirmed against an Apple source this session → logged as A1 with a design that doesn't depend on it

### Tertiary (LOW confidence)

- none used

## Metadata

**Confidence breakdown:**
- Speech stack (recognizer, request, session, permission): HIGH — SDK headers + official docs + compile verification, all this session
- AppIntents surface (APIs, availability, build rules): HIGH for compile-time facts; MEDIUM for runtime phrase-capture (A1)
- Audio/webview coexistence: MEDIUM — category semantics verified; WebKit interaction undocumented (A2)
- Pitfalls 1–2 (spec corrections): HIGH — both derived from verified tool/SDK behavior

**Research date:** 2026-08-18
**Valid until:** 2026-09-18 (stable platform APIs; re-verify A1/A2 only at device checkpoints)
