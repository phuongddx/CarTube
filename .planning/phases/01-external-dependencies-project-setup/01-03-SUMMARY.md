---
phase: 01-external-dependencies-project-setup
plan: 03
subsystem: infra
tags: [google-cloud, api-key, youtube-data-api, key-restriction, quota-alerting, runbook, external-dependency]

requires:
  - phase: 01-external-dependencies-project-setup/01
    provides: "Proven xcconfig → $(YOUTUBE_API_KEY) → built Info.plist delivery pipe with sentinel value"
  - phase: 01-external-dependencies-project-setup/02
    provides: "Confirmed distribution bundle IDs com.cartube.carplay / com.cartube.carplay.playon and the dated entitlement blocker record"
provides:
  - "docs/runbooks/google-youtube-api-key.md — exact console click-path: dedicated project, enable-before-restrict order, both restriction types naming the future com.cartube.* IDs, quota alerting, Secrets.xcconfig delivery, verification commands, public-by-design note"
  - "Key Decision rows (audio-category rationale incl. residual risk, xcconfig delivery mechanism, dev-key deferral to Phase 3)"
  - "Entitlement branch resolved in STATE.md: still pending (Case-ID 21672656), Phases 3–5 proceed on phone-side mocks"
  - "NOTES.md working notes consumed and deleted (both defaults became durable decisions)"
affects:
  - Phase 03 (search core — reads the key via Bundle.main.object(forInfoDictionaryKey:); blocked on key creation; dev-key project decision lands there)
  - Phase 02 (bundle-ID re-prefix must produce exactly com.cartube.carplay / com.cartube.carplay.playon — the Google restriction already names these)
  - plan 01-03 Task 2 continuation (verify: gcloud restrictions, plutil key extraction, AIza hygiene gate)

actuals:
  tokens: 3775
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "restricted-key provisioning runbook pattern: dedicated project → enable API → create key → both restrictions naming FUTURE bundle IDs → quota alert → gitignored delivery → gcloud/plutil/git-grep verification"

key-files:
  created:
    - docs/runbooks/google-youtube-api-key.md
  modified:
    - .planning/PROJECT.md
    - .planning/STATE.md
  deleted:
    - .planning/phases/01-external-dependencies-project-setup/NOTES.md

key-decisions:
  - "Audio-category entitlement rationale recorded incl. residual risk: the app genuinely plays YouTube audio through the vehicle's system, but an on-screen video surface under an audio entitlement may still draw review scrutiny"
  - "API key delivery via gitignored root Secrets.xcconfig + $(YOUTUBE_API_KEY) Info.plist injection; key is public-by-design inside the IPA, guarded by API + iOS bundle-ID restrictions and quota alerting, rotated via Secrets.xcconfig or CI command-line override"
  - "Google dev-key project deferred to Phase 3; Phase 1 provisions only the shipping key so search work never blocks"
  - "Google iOS application restriction lists the FUTURE com.cartube.* bundle IDs, not the upstream com.avangelista.* strings still in the committed pbxproj — Google matches the signed binary, which will carry the future IDs"

requirements-completed: []  # INFRA-01 stays open: key creation (Task 2 checkpoint) + grant-time profile wiring remain

duration: 17m
completed: 2026-08-18
status: halted
---

# Phase 01 Plan 03: Google API Key Provisioning & Phase 1 Close-Out Summary

Restricted-key provisioning runbook committed naming the future `com.cartube.*` bundle IDs, all three Key Decisions recorded, entitlement branch resolved as still pending — halted at the designed blocking checkpoint: the Google Cloud console actions themselves, which are human-only behind Google login.

## Performance

- **Duration:** ~17 min agent-side (Tasks 1+3, excluding the pending human checkpoint)
- **Started:** 2026-08-18T06:48:54Z
- **Tasks:** 2 of 3 complete (Task 2 is a `checkpoint:human-verify`, gate blocking — awaiting user)
- **Files modified:** 3 (1 created, 2 modified, 1 deleted)

## Accomplishments

- `docs/runbooks/google-youtube-api-key.md` — full click-path runbook: new dedicated project (`cartube-shipping`), enable YouTube Data API v3 (verify ON) **before** key creation (Console mandates an API restriction at creation; restriction requires the API enabled), API restriction to YouTube Data API v3 only, iOS application restriction listing `com.cartube.carplay` + `com.cartube.carplay.playon`, one-application-restriction-type rule, billing-free quota alerting (~80% threshold), delivery into gitignored root `Secrets.xcconfig` only, verification commands (gcloud + plutil + git grep), and the public-by-design honesty note with the rotation remediation path.
- Key Decisions table grew by exactly 3 rows (8→11, asserted against git HEAD baseline): audio-category rationale incl. residual review-scrutiny risk; xcconfig delivery mechanism incl. CI override and IPA-visibility limit; dev-key project deferral to Phase 3.
- Entitlement branch explicitly resolved as **still pending** (submitted 2026-08-18, Case-ID 21672656): Phases 3–5 proceed on phone-side mocks; on-device CarPlay verification happens when the grant lands; grant-wiring runbook pointer retained.
- `NOTES.md` deleted — both planning defaults (bundle-ID choice, dev-key deferral) are now durable records in STATE.md / PROJECT.md.

## Task Commits

1. **Task 1: Author Google key runbook** — `ec6df42` (docs)
2. **Task 2: Create the restricted key and inject it into Secrets.xcconfig** — **NOT COMMITTED (awaiting human checkpoint)**
3. **Task 3: Record Key Decisions, resolve grant-status branch, close out Phase 1 state** — `709ddac` (docs; executed ahead of Task 2 per orchestrator instruction so all agent-side work is committed before the stop)

## Files Created/Modified

- `docs/runbooks/google-youtube-api-key.md` — the console procedure + delivery + verification + honesty sections
- `.planning/PROJECT.md` — three appended Key Decision rows; no pre-existing row altered
- `.planning/STATE.md` — Current Position (Phase 1 complete pending external clocks, next Phase 2), Phase 1 close-out blocker line (still-pending branch + submission date + runbook pointer), new Google-key blocker entry, Session Continuity pointing at the checkpoint
- `.planning/phases/01-external-dependencies-project-setup/NOTES.md` — deleted (defaults consumed)

## Decisions Made

- The Google restriction must list the **future** bundle IDs (`com.cartube.*`) rather than the pbxproj's current `com.avangelista.*` strings: Google validates the bundle ID the shipped binary is signed with, and the App Store build will carry the future IDs (Phase 2 lands the re-prefix).
- Task 3 executed before the Task 2 checkpoint (orchestrator-directed resequencing) so every agent-side task is committed before the human stop.
- Plan summary recorded as `status: halted` rather than `complete` — Task 2's console actions are genuinely outstanding; the continuation agent finalizes after the key exists.

## Deviations from Plan

### Execution-Order Deviation (orchestrator-directed, not a rule trigger)

**Task order 1→3→checkpoint instead of 1→checkpoint→3**
- **Why:** The dispatching orchestrator explicitly instructed: "complete all agent-side tasks first… then STOP and return a structured CHECKPOINT." This avoids a second agent cold-start and leaves the repo in a fully-committed state at the stop. Task 3 has no data dependency on the real key (it depends only on the runbook and the confirmed bundle IDs, both available after Task 1).
- **Effect on Task 3 verify:** the plan's `BEFORE` baseline is computed from `git show HEAD:…` and passed exactly (8→11); the `still pending` branch phrase resolved as expected (submitted this morning, grant cannot have landed).
- **Files:** none beyond the plan's Task 3 list.

**Total deviations:** 1 (execution-order only; no code/behavior deviations)
**Impact on plan:** None — all agent-side acceptance criteria verified green.

## Issues Encountered

None. Task 1 and Task 3 automated verifications passed first try; hygiene gates (`git grep AIza`, `git check-ignore Secrets.xcconfig`) stayed clean throughout.

## What Remains (the checkpoint)

**Task 2 — blocking human checkpoint (Google Cloud Console, login-walled):**
1. Follow `docs/runbooks/google-youtube-api-key.md` top-to-bottom: dedicated project → enable YouTube Data API v3 → create key → BOTH restrictions (API: YouTube Data API v3 only; iOS apps: `com.cartube.carplay` + `com.cartube.carplay.playon`) → quota alert.
2. Paste the key into root `Secrets.xcconfig` replacing `BUILD_TIME_SENTINEL_REPLACE_WITH_REAL_KEY` (the key value never needs to transit chat — editing the file yourself is the preferred path).
3. Report the **Google Cloud project ID** + confirmation both restrictions were set.
4. Continuation agent then runs: `gcloud services api-keys describe` (restrictions check), fresh simulator build + `plutil -extract YOUTUBE_API_KEY raw` (must print the real `AIza…` value), `git grep -nE 'AIza…'` (must stay empty).

**Skip option (presented, not chosen):** the plan allows proceeding fixture-only — keep the sentinel and let CI supply the key later. This leaves local builds without a working key and Phase 3 search development against fixtures until then. Available if the user prefers not to create the Google project today; say "skip — fixture only" to take it.

**After Task 2 closes:** re-summarize this plan as `status: complete`, advance plan counter, mark INFRA-01 progress accordingly (grant-time profile wiring stays open until Apple responds).

## Next Phase Readiness

- Phase 2 (severance/signing) is unblocked now; it does not depend on the Google key.
- Phase 3 search work blocks on the key; the delivery pipe is proven (plan 01-01) so only the value is missing.
- INFRA-01 remains open: submission done + dated, key pending user checkpoint, profile wiring pending Apple grant.

## Self-Check: PASSED

- Files exist: docs/runbooks/google-youtube-api-key.md, .planning/PROJECT.md, .planning/STATE.md — FOUND; NOTES.md — confirmed absent
- Commits ec6df42, 709ddac — FOUND in git log
- Task 3 acceptance: PROJECT.md row delta exactly 3 vs HEAD baseline; STATE.md contains `still pending`; zero AIza matches across tracked files; `git check-ignore -q Secrets.xcconfig` exit 0

---
*Phase: 01-external-dependencies-project-setup*
*Halted at checkpoint: 2026-08-18*
