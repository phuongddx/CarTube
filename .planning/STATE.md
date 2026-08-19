---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
current_phase: 06
current_phase_name: TestFlight Submission Package
status: planning
stopped_at: Completed 05-03-PLAN.md
last_updated: "2026-08-19T08:27:08.580Z"
last_activity: 2026-08-19
last_activity_desc: Phase 03 complete, transitioned to Phase 04
progress:
  total_phases: 6
  completed_phases: 5
  total_plans: 18
  completed_plans: 15
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-18)

**Core value:** A driver can open any YouTube video on their car screen — by voice, search, or share — with ads and sponsors skipped automatically.
**Current focus:** Phase 05 — voice-input

## Current Position

Phase: 06 — TestFlight Submission Package
Plan: Not started
Status: Ready to plan
Last activity: 2026-08-19 — Phase 05 complete, transitioned to Phase 06

Progress: [████████░░] 83%

## Performance Metrics

**Velocity:**

- Total plans completed: 12
- Average duration: —
- Total execution time: —

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 02 | 4 | - | - |
| 03 | 3 | - | - |
| 04 | 2 | - | - |
| 05 | 3 | - | - |

*Updated after each plan completion*
**Per-Plan Metrics:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 01 P01 | 25m | 2 tasks | 4 files |
| Phase 01 P02 | 95m | 3 tasks | 3 files |
| Phase 01 P03 | 17m | 2 tasks | 3 files |
| Phase 02 P02 | 14min | 2 tasks | 3 files |
| Phase 02 P03 | 22min | 3 tasks | 7 files |
| Phase 02 P04 | 24min | 2 tasks | 3 files |
| Phase 03 P01 | 18min | 2 tasks | 4 files |
| Phase 03 P02 | 15min | 2 tasks | 10 files |
| Phase 04 P01 | 55min | 2 tasks | 9 files |
| Phase 04 P02 | 20min | 2 tasks | 4 files |
| Phase 05 P01 | 45min | 3 tasks | 10 files |
| Phase 05 P02 | 15min | 2 tasks | 3 files |
| Phase 05 P03 | 35min | 3 tasks | 4 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Roadmap: Horizontal-layer phase order (external deps → severance → search core → UI → voice → submission) follows research dependency order; severance precedes search (same files touched)
- Roadmap: INFRA-01 (CarPlay entitlement) isolated in Phase 1 — external clock started day 1; phases 3–5 develop behind phone-side mocks until granted
- Phase 1: User's actual Apple team is K2TYLYAWMK (paid Apple Developer Program), not the upstream author's U67AKNW8PW from the pbxproj — CarPlay entitlement Case-ID 21672656 submitted 2026-08-18 under team K2TYLYAWMK with App ID com.cartube.carplay, category audio
- [Phase ?]: xcconfig secret injection attached at project level (Debug+Release baseConfigurationReference) — no target-level definition, so layering is unambiguous
- [Phase ?]: Fresh-clone failure is intentional and documented: missing root Secrets.xcconfig fails build with 'Unable to open base configuration reference file'; CI bypasses disk via xcodebuild YOUTUBE_API_KEY=... override
- [Phase ?]: CarPlay entitlement submitted 2026-08-18 (Case-ID 21672656, audio category, App ID com.cartube.carplay) under user's actual team K2TYLYAWMK — not upstream U67AKNW8PW from pbxproj
- [Phase ?]: Entitlement request framed as audio playback of YouTube via vehicle audio system; on-screen/driver wording excluded from paste block, residual category-fit risk deferred to plan 01-03
- [Phase ?]: Google iOS key restriction lists the future com.cartube.carplay + com.cartube.carplay.playon IDs (what the signed App Store build carries), not the upstream com.avangelista.* strings still in the pbxproj
- [Phase ?]: Phase 2: strings-scan gate marker array holds exactly the 15 removed-symbol strings; the 4 survivor strings (_simulateTextEntered, _hasSleepDisabler, hasBlankedScreen, lockstate) are excluded by design so surviving features never fail their own gate
- [Phase ?]: CI gate workflow (private API scan) has zero continue-on-error steps; the scan script exit code is the only thing that can fail the job
- [Phase ?]: 02-03: registerForUnlockNotification deleted (not kept) — its only caller (restoreBrightness) died with the brightness trio; the warning label self-hides via its own timer, so nothing needs the unlock event. Resolves the PATTERNS.md planner decision point; corroborated by scan-private-apis.sh's own header comment (written in 02-02) already documenting com.apple.springboard.lockstate as removed by plan 02-03.
- [Phase ?]: 02-03: Settings.saveSettings() now applies configuration in place via CarPlaySingleton.applyConfiguration() -> CarPlayViewController.applyConfigurationInPlace() instead of calling exitGracefully()/exit(0); the app no longer quits on Save.
- [Phase ?]: 02-04: Deployment target raised to iOS 16.0 (6 sites), Dynamic SPM package fully removed (5 object types + Package.resolved); restored two unrelated pbxproj attributes (dstSubfolder=PlugIns, spurious empty dependencies array) dropped/added by the xcodeproj gem's save before committing
- [Phase ?]: 02-04: Debug.swift extended with Hook Verification (4 status rows) + Script Re-validation (3 rows); HideScrollBar detection uses IMP-vs-superclass comparison (no original_ companion selector exists for that hook)
- [Phase ?]: 02-04: Local Xcode/simulator SDK mismatch blocking build verification since 02-01 is resolved (iOS 26.3.1 runtime installed) — first real BUILD SUCCEEDED and first actual-binary scan-private-apis.sh pass of Phase 2, run against destination id=F14D9B48-EF6B-4ACD-BB09-2D5951BF5D0A (iPhone 17e)
- [Phase ?]: 03-01: BUNDLE_LOADER-only test linking failed against this Xcode toolchain's Debug-dylib split (CarTube trampoline + CarTube.debug.dylib); switched to TEST_HOST + BUNDLE_LOADER=$(TEST_HOST), the plan's own sanctioned fallback
- [Phase ?]: 03-01: xcodeproj gem's new_target left PRODUCT_NAME unset on CarTubeTests configs (bare .xctest product path collided with CarTube's own output) — added PRODUCT_NAME = $(TARGET_NAME) explicitly
- [Phase ?]: 03-01: repeated Phase 2 fix — restored dstSubfolder=PlugIns and removed spurious empty dependencies array the xcodeproj gem's save introduced on unrelated targets
- [Phase ?]: 03-02: Fixture loading via Bundle(for:).path(forResource:ofType:) without inDirectory: — xcodeproj gem's flat group-reference resource wiring puts fixtures at test bundle root regardless of pbxproj group nesting
- [Phase ?]: 03-02: Custom percent-encoding CharacterSet (.urlQueryAllowed minus &=+) for query values — the default set leaves & unescaped in a value, corrupting multi-word queries containing an ampersand
- [Phase ?]: 03-02: Repeated the 03-01 xcodeproj gem quirk fix (restored dstSubfolder=PlugIns on the Embed Foundation Extensions phase) on both gem invocations this plan; a spurious empty dependencies array recurred only on the first
- [Phase ?]: 03-02: SearchError distinguishes apiKeyMissing/apiKeyInvalid/quotaExceeded/other(String) so the SRCH-03 degrade decision (plan 03-03) reads typed data, never string-matches
- [Phase ?]: 03-03: LastQueryCache (actor, single-slot, exact-string match, no UserDefaults) built and tested (6 tests) — SRCH-02's cache half
- [Phase ?]: 03-03: SearchFallback.decide pure function built and tested (6 tests) — every SearchError kind degrades to webview search; only empty success is showNoResults; caller contract documents CarPlay singleton's searchVideo(query) as the Phase-4-wired edge, in comments only (zero executable CarPlay references in Search/)
- [Phase ?]: 03-03: docs/runbooks/google-dev-key.md authored (cartube-dev project, mirrors shipping-key runbook) and 3 Key Decision rows appended to PROJECT.md (no Phase 3 search toggle, parser-dedupe deferred, dev-key project separation) — all Outcome: Pending
- [Phase ?]: 04-01: submitSearchQuery(_:) on CarPlaySingleton individually marked @MainActor (not the whole class) to bridge synchronously into the @MainActor-isolated SearchCoordinator.shared.search(_:) — compiler's own suggested fix, honors the patterns doc's 'do NOT retrofit @MainActor onto CarPlaySingleton' rule since only one bridging method is annotated
- [Phase ?]: 04-01: .fallback state and MessageCell.configureFallback() are implemented for switch-exhaustiveness but unreachable this plan — SearchCoordinator's degrade branch calls degrade(query) then dismissOverlay() immediately; 04-02 wires the fallback-row presentation with its own auto-dismiss timer
- [Phase ?]: 04-01: visual end-to-end pass (keyboard submit -> overlay -> tap -> play -> dismiss) deferred to 04-02's phone-preview harness — no CarPlay entitlement/simulator scene available in this environment; funnel is fully unit-proven (46/46 tests) instead
- [Phase ?]: 04-02: SearchCoordinator generation guard checked at top of run() means a superseded query issues zero network requests (stronger than late-response discard); autoDismissDelay is an injectable Duration seam (default .seconds(2)) so tests avoid awaiting real wall-clock time
- [Phase 05]: 05-01: SpeechRecognizerService is construction-gated on SFSpeechRecognizer.supportsOnDeviceRecognition (checked at init and re-asserted at startListening()) with an audio-engine + audio-session + recognition-task-factory seam trio plus an injectable clock -- a request is never built past a failed gate, so no server-based recognition path exists anywhere. — Research Pitfall 5 verified that requiresOnDeviceRecognition alone fails silently to server recognition when unsupported; the three-protocol seam design lets the full push-to-talk lifecycle (including the 1.8s/10.0s silence timer and teardown ordering) be proven with zero live audio in CarTubeTests.
- [Phase 05]: 05-01: Built MicButton's full idle/listening/hint surface and CarPlayViewController's complete wiring (transcript submit, hint display, availability re-check) in Task 1 rather than splitting hint-display wiring into Task 2 -- Task 2 and Task 3 touch neither CarPlayViewController.swift nor add new MicButton API, only pinning behavior with tests (SpeechAvailabilityGateTests, SilenceTimerTests) and hardening SpeechRecognizerService (Pitfall-6 error table, silence timer, interruption observer). — Task 2/3's file lists never include CarPlayViewController.swift, and CarPlayViewController is the only file wiring the mic button into production -- deferring hint-pill wiring to a later task would have left the UI-SPEC's 'Didn't catch that' / 'Voice search unavailable' hints unreachable in the shipped app for this plan. Building the complete vertical slice in the tracer task (Task 1) keeps VoiceSearchAvailability + MicButton + SpeechRecognizerService as a genuinely finished contract for 05-02/05-03 to build on.
- [Phase 05]: 05-02: VoiceSearchSetup's stateContent renders through a single VoiceSearchSetup.copy(for:) static function driven by VoiceSearchAvailability.evaluate, and VoiceOnboardingStateTests asserts against that same function, not a parallel copy-string reimplementation — Keeps the onboarding screen, its tests, and the CarPlay mic button's gate reading from the identical evaluate() verdict (one source of truth per UI-SPEC/research)
- [Phase 05]: 05-03: The plan's two-phrase Siri design ("Search YouTube for \(\.$query) in \(.applicationName)" + a parameterless fallback) fails real xcodebuild ExtractAppIntentsMetadata on Xcode 26.3 with "Invalid parameter type. AppEntity and AppEnum are the only allowed types for query" -- open-ended String parameters cannot be embedded in an AppShortcut phrase at all. Fixed by shipping only the parameterless phrase; requestValueDialog covers query capture as a Siri follow-up, fully preserving VOX-03's zero-setup goal. — Confirmed via a real xcodebuild build failure and corroborated by an identical error on Apple Developer Forums thread 770037 -- this disproves research's Assumption A1 (String phrase params, MEDIUM-confidence community belief) as a hard build-time constraint. The fallback phrase is exactly the contingency 05-RESEARCH.md Pattern 2 already designed for this scenario.

### Pending Todos

None yet.

### Blockers/Concerns

- **CarPlay entitlement GRANTED (2026-08-18)** — Apple assigned the CarPlay Audio App entitlement to team K2TYLYAWMK (Case-ID 21672656, submitted 2026-08-18, App ID `com.cartube.carplay`, audio category). Runbook `docs/runbooks/carplay-entitlement-grant-wiring.md` step 8 done: `com.apple.developer.carplay-audio` = `true` added to `CarTube/CarTube.entitlements` (was bare `<dict/>` since Phase 2). **Remaining steps are human/portal/Xcode-UI actions this agent cannot perform:** (1-5) enable CarPlay on the App ID at developer.apple.com/account → Certificates, IDs & Profiles; (6-7) create + import a new provisioning profile supporting CarPlay; (9-10) in Xcode Signing & Capabilities, turn OFF automatic signing and select the imported profile (confirm `CODE_SIGN_ENTITLEMENTS` still points at `CarTube/CarTube.entitlements` — it does); (11) verify the CarPlay scene connects via CarPlay Simulator (Additional Tools for Xcode). Success-criterion-3 now unblocked pending those manual steps — on-device CarPlay verification can proceed once done.
- **Google shipping key not yet created (external, 2026-08-18)** — Runbook authored and committed (docs/runbooks/google-youtube-api-key.md); the Console actions are human-only behind Google login: dedicated project, enable YouTube Data API v3, create key, both restrictions (API: YouTube Data API v3 only; iOS: com.cartube.carplay + com.cartube.carplay.playon), quota alerting, paste the key into root Secrets.xcconfig (gitignored) replacing the sentinel. On resume: agent verifies via gcloud + plutil + git grep. Phase 3 search work blocks on this; nothing else does.
- Phase 2 closed 2026-08-18: code review (2 of 3 critical findings fixed — idle-timer apply-in-place gap, bundle-ID/signing-team inconsistency; CR-02 HideScrollBar row + 7 warnings + 3 info left as tracked follow-up, see PROJECT.md Active), phase-goal verification passed, UAT 2/2 passed, security 0 threats open. CarPlay-connected end-to-end observation of the idle-timer fix remains deferred until the Phase 1 entitlement lands (see below).
- 03-03 halted at Task 3 step 2 / Task 4: live smoke search and its blocking checkpoint need a human decision (provision cartube-dev key, spend 2 units on the shipping key, or skip smoke entirely) plus review of the 3 new Key Decision rows — see docs/runbooks/google-dev-key.md Section 4 'Status of this section' and PLAN.md Task 4
- 04-02 halted at Task 3 checkpoint (gate=blocking, human-verify): Tasks 1-2 complete (generation guard, fallback wiring, retry tap, phone preview harness, 58/58 tests passing). Task 3 needs a human to walk every overlay state (contingency: Debug > Search Overlay Preview, since CarPlay entitlement's remaining Xcode-signing steps are still pending) and report the resume-signal (approved / defects).

## Session Continuity

Last session: 2026-08-19T05:48:47.952Z
Stopped at: Completed 05-03-PLAN.md
Resume file: None
