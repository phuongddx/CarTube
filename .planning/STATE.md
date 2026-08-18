---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
current_phase: 03
current_phase_name: search-core
status: executing
stopped_at: "All 3 plans of Phase 3 complete (03-03's checkpoint resolved: skip smoke, deferred to Phase 4). Ready for phase-close: code review, regression gate, phase-goal verification, security audit, UAT, transition to Phase 4."
last_updated: "2026-08-18T15:57:56.908Z"
last_activity: 2026-08-18
last_activity_desc: Phase 02 UAT passed (2/2), security threats closed (0 open), transitioned to Phase 03 — Search Core
progress:
  total_phases: 6
  completed_phases: 2
  total_plans: 18
  completed_plans: 9
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-18)

**Core value:** A driver can open any YouTube video on their car screen — by voice, search, or share — with ads and sponsors skipped automatically.
**Current focus:** Phase 03 — search-core

## Current Position

Phase: 03 (search-core) — EXECUTING
Plan: 3 of 3
Status: All plans complete — ready for phase-close pipeline (code review → regression gate → verify → security → UAT → transition)
Last activity: 2026-08-18 — 03-03 Tasks 1-2 + Task 3 steps 1+3 executed and committed

Progress: [█████░░░░░] 50%

## Performance Metrics

**Velocity:**

- Total plans completed: 4
- Average duration: —
- Total execution time: —

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 02 | 4 | - | - |

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

### Pending Todos

None yet.

### Blockers/Concerns

- **CarPlay entitlement GRANTED (2026-08-18)** — Apple assigned the CarPlay Audio App entitlement to team K2TYLYAWMK (Case-ID 21672656, submitted 2026-08-18, App ID `com.cartube.carplay`, audio category). Runbook `docs/runbooks/carplay-entitlement-grant-wiring.md` step 8 done: `com.apple.developer.carplay-audio` = `true` added to `CarTube/CarTube.entitlements` (was bare `<dict/>` since Phase 2). **Remaining steps are human/portal/Xcode-UI actions this agent cannot perform:** (1-5) enable CarPlay on the App ID at developer.apple.com/account → Certificates, IDs & Profiles; (6-7) create + import a new provisioning profile supporting CarPlay; (9-10) in Xcode Signing & Capabilities, turn OFF automatic signing and select the imported profile (confirm `CODE_SIGN_ENTITLEMENTS` still points at `CarTube/CarTube.entitlements` — it does); (11) verify the CarPlay scene connects via CarPlay Simulator (Additional Tools for Xcode). Success-criterion-3 now unblocked pending those manual steps — on-device CarPlay verification can proceed once done.
- **Google shipping key not yet created (external, 2026-08-18)** — Runbook authored and committed (docs/runbooks/google-youtube-api-key.md); the Console actions are human-only behind Google login: dedicated project, enable YouTube Data API v3, create key, both restrictions (API: YouTube Data API v3 only; iOS: com.cartube.carplay + com.cartube.carplay.playon), quota alerting, paste the key into root Secrets.xcconfig (gitignored) replacing the sentinel. On resume: agent verifies via gcloud + plutil + git grep. Phase 3 search work blocks on this; nothing else does.
- Phase 2 closed 2026-08-18: code review (2 of 3 critical findings fixed — idle-timer apply-in-place gap, bundle-ID/signing-team inconsistency; CR-02 HideScrollBar row + 7 warnings + 3 info left as tracked follow-up, see PROJECT.md Active), phase-goal verification passed, UAT 2/2 passed, security 0 threats open. CarPlay-connected end-to-end observation of the idle-timer fix remains deferred until the Phase 1 entitlement lands (see below).
- 03-03 halted at Task 3 step 2 / Task 4: live smoke search and its blocking checkpoint need a human decision (provision cartube-dev key, spend 2 units on the shipping key, or skip smoke entirely) plus review of the 3 new Key Decision rows — see docs/runbooks/google-dev-key.md Section 4 'Status of this section' and PLAN.md Task 4

## Session Continuity

Last session: 2026-08-18T15:57:56.896Z
Stopped at: Halted mid 03-03-PLAN.md: Tasks 1-2 complete + Task 3 steps 1+3 complete; Task 3 step 2 (live smoke) and Task 4 (checkpoint) await human decision
Resume file: none — run `/gsd-execute-phase 3` again to resume the phase-close pipeline (code review, regression gate, verify_phase_goal, security, UAT, transition); all 3 plans are already committed
