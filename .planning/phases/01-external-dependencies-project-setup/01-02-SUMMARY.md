# Phase 01 Plan 02: CarPlay Entitlement Application Summary

Apple external clock started: audio-category CarPlay entitlement submitted 2026-08-18 (Case-ID 21672656, App ID `com.cartube.carplay`, team K2TYLYAWMK) with paste-ready request and grant-wiring runbooks committed and a dated STATE.md blocker record replacing the generic seed line.

## Performance

- **Duration:** ~92 min (runbook authoring + user portal submission + record; wall-clock spans the human checkpoint)
- **Tasks:** 3 (2 auto, 1 blocking human checkpoint)
- **Files modified:** 3 (two runbooks created, STATE.md updated)

## What Was Done

- `docs/runbooks/apple-carplay-entitlement-request.md` — prerequisites (paid-tier check, bundle-ID options incl. fallback), portal click path from developer.apple.com/carplay, and paste-ready REQUEST-TEXT-BEGIN/REQUEST-TEXT-END block positioning the app as audio playback of YouTube content through the vehicle's audio system, with zero on-screen-viewing/driver-context wording inside the markers.
- `docs/runbooks/carplay-entitlement-grant-wiring.md` — numbered post-grant sequence (App ID capability → provisioning profile → import → `com.apple.developer.carplay-audio` → auto-signing off → CarPlay Simulator verification) plus the sequencing constraint naming all 7 currently-present ungrantable entitlement keys: signing against a real profile fails until the file holds only grantable keys; key-stripping is Phase 2 (INFRA-02) scope, or a clean entitlements file swap inside the runbook.
- **Checkpoint (Task 2) completed via user action:** submission at developer.apple.com confirmed — Case-ID **21672656**, Apple auto-acknowledgment received; team **K2TYLYAWMK** (Apple Developer Program, paid tier), submitter Doan Phuong; bundle ID **`com.cartube.carplay`** registered as planned; category **audio** selected; App Store URL field left empty (app unpublished — correct); the form's free-text "specific CarPlay features" question was answered with the runbook's REQUEST-TEXT block.
- **Task 3:** STATE.md Blockers/Concerns generic seed line replaced with the dated record (submission date, case ID, category, bundle ID, team, no-SLA re-check note, grant-wiring runbook pointer, Phases 3–5 unblocked via phone-side mocks); Session Continuity and Decisions updated.

## Checkpoint Outcome

| Item | Result |
|------|--------|
| Checkpoint | Task 2 — confirm bundle ID + submit entitlement request (gate: blocking) |
| Outcome | COMPLETE via user action |
| Confirmed bundle ID | `com.cartube.carplay` (share extension `com.cartube.carplay.playon`) |
| Submission date | 2026-08-18 |
| Category | audio |
| Case-ID | 21672656 |
| Team | K2TYLYAWMK (paid Apple Developer Program) |
| App Store URL field | left empty (optional; app not yet published) |
| Form deltas vs runbook | extra free-text question "What specific CarPlay features do you plan to implement?" answered with the runbook REQUEST-TEXT block (research assumption A3 held: minor surprises only) |

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | ab022a0 | docs(01-02): author CarPlay entitlement request + grant-wiring runbooks |
| 2 | — (user action) | Portal submission performed by the user per checkpoint |
| 3 | (this commit) | docs(01-02): record dated entitlement blocker + team correction in STATE.md |

## Verification Evidence

- Task 1 greps green: `developer.apple.com/carplay`, `CarPlay Entitlement Addendum`, `REQUEST-TEXT-BEGIN`/`-END`, marker-scoped wording gate (0 hits for watch/driving/video/driver), `com.apple.developer.carplay-audio`, `Automatically manage signing`, all 7 ungrantable keys — verified in commit ab022a0.
- Task 3 greps green: STATE.md contains `audio`, `carplay-entitlement-grant-wiring`, `Submitted 2026-08-18` pattern, `com.cartube.carplay`, `K2TYLYAWMK`.
- Generic undated seed line no longer present in STATE.md.

## Decisions Made

- Audio-only framing inside the paste block; rationale and residual category-fit risk recorded for the plan 01-03 Key Decision row.
- `com.cartube.carplay` confirmed as the permanent distribution ID before submission (grant attaches to the App ID; a later change orphans it).
- Team-ID correction recorded: the user's team is **K2TYLYAWMK**; U67AKNW8PW in the committed pbxproj is the upstream author's. Phase 2 plan correction already committed separately (6935b2f) — not touched here.

## Deviations from Plan

None for Tasks 1 and 3 — executed as specified. Task 2 was a designed blocking checkpoint, resolved by the user's portal action rather than by the executor.

**One factual correction discovered at the checkpoint (not a plan deviation):** the runbook's prerequisites section names team `U67AKNW8PW` (assumed from the pbxproj); the actual submitting team is `K2TYLYAWMK`. The authoritative record (STATE.md blocker entry + this summary + decision line) carries K2TYLYAWMK; the runbook text was left untouched this plan because it is a completed-step historical artifact and the Phase 2 team correction (6935b2f) already points future work at K2TYLYAWMK.

## Issues Encountered

None beyond the team-ID fact above.

## What Remains (Grant Pending)

- Apple review has no SLA (community-reported days–months). Re-check developer.apple.com periodically for the Case-ID 21672656 outcome.
- When granted: execute `docs/runbooks/carplay-entitlement-grant-wiring.md` (profile + entitlement key + signing changes; sequence against Phase 2's entitlements cleanup).
- Until then: Phases 3–5 proceed against phone-side mocks; on-device CarPlay verification is the only gated work.
- INFRA-01's final clause (provisioning profile wired when granted) closes at grant time — the submission half is done.

## Next Phase Readiness

- Plan 01-03 (API key + remaining external setup) can execute now; nothing in this plan blocks it.
- Phase 2 owns the bundle-ID/entitlements file changes; the grant-wiring runbook is the bridge document.

## Self-Check: PASSED

- Files exist: docs/runbooks/apple-carplay-entitlement-request.md, docs/runbooks/carplay-entitlement-grant-wiring.md, .planning/STATE.md — FOUND
- Commit ab022a0 (Task 1) — FOUND in git log
- Task 3 + SUMMARY commit — created in this plan's final commit

---
*Phase: 01-external-dependencies-project-setup*
*Completed: 2026-08-18*
