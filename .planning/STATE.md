---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
current_phase: 02
current_phase_name: severance-signing-modernization
status: executing
stopped_at: Completed 02-02-PLAN.md private API scan CI gate; TDD-verified, app-binary compile proof deferred to a matching CI runner per WINDOWS.md entry 4; next up 02-03
last_updated: "2026-08-18T09:57:23.304Z"
last_activity: 2026-08-18
last_activity_desc: 01-03 runbook authored + Key Decisions/branch recorded; awaiting Google Cloud key checkpoint (Task 2)
progress:
  total_phases: 6
  completed_phases: 1
  total_plans: 18
  completed_plans: 5
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-17)

**Core value:** A driver can open any YouTube video on their car screen — by voice, search, or share — with ads and sponsors skipped automatically.
**Current focus:** Phase 02 — severance-signing-modernization

## Current Position

Phase: 02 (severance-signing-modernization) — EXECUTING
Plan: 3 of 4
Status: Ready to execute
Last activity: 2026-08-18 — Phase 02 execution started

Progress: [███░░░░░░░] 28%

## Performance Metrics

**Velocity:**

- Total plans completed: 0
- Average duration: —
- Total execution time: —

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

*Updated after each plan completion*
**Per-Plan Metrics:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 01 P01 | 25m | 2 tasks | 4 files |
| Phase 01 P02 | 95m | 3 tasks | 3 files |
| Phase 01 P03 | 17m | 2 tasks | 3 files |
| Phase 02 P02 | 14min | 2 tasks | 3 files |

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

### Pending Todos

None yet.

### Blockers/Concerns

- **Phase 1 close-out (2026-08-18): CarPlay entitlement still pending** — Submitted 2026-08-18 (Apple Case-ID 21672656, auto-acknowledgment received). Category requested: audio. App ID: `com.cartube.carplay` (registered under team K2TYLYAWMK — Apple Developer Program, paid tier; note: K2TYLYAWMK is the user's actual team, not the upstream U67AKNW8PW from the pbxproj). No SLA (community-reported days–months) — re-check the developer account periodically for the grant notification. When the grant lands, execute docs/runbooks/carplay-entitlement-grant-wiring.md (mind its entitlements-file sequencing constraint against Phase 2). Success-criterion-3 branch resolved as **still pending**: Phases 3–5 proceed on phone-side mocks; on-device CarPlay verification happens when the grant lands.
- **Google shipping key not yet created (external, 2026-08-18)** — Runbook authored and committed (docs/runbooks/google-youtube-api-key.md); the Console actions are human-only behind Google login: dedicated project, enable YouTube Data API v3, create key, both restrictions (API: YouTube Data API v3 only; iOS: com.cartube.carplay + com.cartube.carplay.playon), quota alerting, paste the key into root Secrets.xcconfig (gitignored) replacing the sentinel. On resume: agent verifies via gcloud + plutil + git grep. Phase 3 search work blocks on this; nothing else does.
- 02-02: CarTube.app main executable cannot be compiled locally (Xcode 26.3 SDK 26.2 vs installed simulator runtime 26.5 mismatch, same as 02-01); real-binary proof-of-detection deferred to a CI runner with a matching runtime — logged WINDOWS.md entry 4, workflow committed will run this automatically

## Session Continuity

Last session: 2026-08-18T09:57:15.007Z
Stopped at: Completed 02-02-PLAN.md private API scan CI gate; TDD-verified, app-binary compile proof deferred to a matching CI runner per WINDOWS.md entry 4; next up 02-03
Resume file: None
