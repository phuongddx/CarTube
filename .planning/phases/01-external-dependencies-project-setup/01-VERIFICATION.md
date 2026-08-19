---
phase: 01-external-dependencies-project-setup
verified: 2026-08-19T00:00:00Z
status: gaps_found
score: 6/8 must-haves verified
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "A restricted YouTube Data API key exists in a dedicated Google Cloud project (API + bundle-ID restrictions), delivered only via gitignored Secrets.xcconfig"
    status: failed
    reason: "The 01-03 checkpoint (create the Google Cloud project, enable YouTube Data API v3, create the key, set both restrictions) was never completed. Root Secrets.xcconfig still holds the sentinel value BUILD_TIME_SENTINEL_REPLACE_WITH_REAL_KEY, confirmed by direct read. No dedicated Google Cloud project exists. STATE.md's own Blockers/Concerns section documents this as unresolved ('Google shipping key not yet created')."
    artifacts:
      - path: "Secrets.xcconfig"
        issue: "Contains sentinel value, not a real AIza-prefixed key"
    missing:
      - "Human checkpoint: create dedicated GCP project, enable YouTube Data API v3, create an API key, set API restriction (YouTube Data API v3 only) and iOS application restriction (com.cartube.carplay, com.cartube.carplay.playon), enable quota alerting, paste the real key into root Secrets.xcconfig"
      - "Agent-side follow-up once the key exists: gcloud restriction verification, fresh simulator build + plutil extraction proving the real key (matching ^AIza[0-9A-Za-z_-]{30,}$) reaches the built Info.plist, git grep AIza hygiene re-check"
  - truth: "Built app Info.plist carries the real YouTube API key at build time (sentinel replaced)"
    status: failed
    reason: "Direct rebuild + plutil extraction against the current pbxproj/Info.plist confirms the built product still carries BUILD_TIME_SENTINEL_REPLACE_WITH_REAL_KEY, not a real key — this necessarily follows from the previous gap (no real key has been created yet to inject)."
    artifacts:
      - path: "CarTube/Info.plist"
        issue: "Substitution mechanism is correctly wired (verified), but the value it resolves to is still the sentinel because Secrets.xcconfig has no real key"
    missing:
      - "Same as previous gap — real key must exist before this can close"
  - truth: "If Apple grants the entitlement, the new provisioning profile is wired into the project and the CarPlay scene connection is verified"
    status: partial
    reason: "Apple granted the CarPlay Audio App entitlement 2026-08-18 (Case-ID 21672656, mid-Phase-3), and STATE.md/PROJECT.md both record this. Only runbook step 8 (adding com.apple.developer.carplay-audio = true to CarTube/CarTube.entitlements) has been executed and committed (848f8df) — confirmed by direct read of CarTube/CarTube.entitlements. Runbook steps 1-7 (enable CarPlay capability on the App ID at developer.apple.com, create + import a new CarPlay-capable provisioning profile), 9-10 (turn OFF automatic signing in Xcode, select the imported profile), and 11 (verify the CarPlay scene connects via CarPlay Simulator) remain outstanding. The ROADMAP success criterion is conjunctive ('provisioning profile is wired into the project AND the CarPlay scene connection is verified') — the entitlements-file edit alone does not satisfy it; it is one of eleven sequential steps and the only one an autonomous agent could perform without Apple-portal login, Xcode UI, or simulator/device access."
    artifacts:
      - path: "CarTube/CarTube.entitlements"
        issue: "Correctly carries the granted key (step 8 only) — this is real progress, not a stub, but it is a small fraction of the full wiring chain"
    missing:
      - "Human/Apple-portal: enable CarPlay entitlement on App ID com.cartube.carplay, create and import a new provisioning profile"
      - "Human/Xcode-UI: turn off 'Automatically manage signing', select the imported profile, confirm CODE_SIGN_ENTITLEMENTS still points at CarTube/CarTube.entitlements (it does)"
      - "Human/simulator: verify the CarPlay scene connects using the CarPlay Simulator from Additional Tools for Xcode"
human_verification:
  - test: "Create the dedicated Google Cloud project, enable YouTube Data API v3, create the restricted API key per docs/runbooks/google-youtube-api-key.md, and paste it into root Secrets.xcconfig"
    expected: "A rebuild's plutil extraction of YOUTUBE_API_KEY from the built Info.plist matches ^AIza[0-9A-Za-z_-]{30,}$; gcloud confirms both restrictions (YouTube Data API v3, iOS bundle IDs com.cartube.carplay / com.cartube.carplay.playon); git grep AIza still returns zero matches in tracked files"
    why_human: "Login-walled Google Cloud Console action; no agent credential exists for this account"
  - test: "Execute the remaining steps of docs/runbooks/carplay-entitlement-grant-wiring.md (steps 1-7, 9-11): enable CarPlay on the App ID, create/import a provisioning profile, turn off automatic signing in Xcode, select the profile, and verify the CarPlay scene connects via CarPlay Simulator"
    expected: "Xcode builds and signs CarTube against the imported CarPlay-capable provisioning profile (not automatic signing), and the CarPlay scene visibly connects in the CarPlay Simulator"
    why_human: "Login-walled Apple Developer Portal actions, Xcode UI signing configuration, and simulator-observed scene connection — none of which an agent can perform or verify programmatically"
---

# Phase 1: External Dependencies & Project Setup Verification Report

**Phase Goal:** The two timelines outside our control (Apple entitlement review, Google key provisioning) are started on day 1 so no later phase blocks on them, and the entitlement grant is wired the moment it arrives
**Verified:** 2026-08-19T00:00:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification (no prior 01-VERIFICATION.md existed, despite all 3 plans being executed and summarized)

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | CarPlay entitlement application submitted under the audio category, with rationale documented as a Key Decision and submission date recorded (SC1) | ✓ VERIFIED | Submitted 2026-08-18, Case-ID 21672656, App ID `com.cartube.carplay`, team K2TYLYAWMK, category audio (STATE.md, PROJECT.md line 32). Key Decision row present in PROJECT.md Key Decisions table ("CarPlay entitlement requested under the audio category…", line 74) |
| 2 | Paste-ready audio-category request text excludes on-screen-viewing/driver-context wording; distribution bundle ID consciously confirmed before submission | ✓ VERIFIED | `sed`-extracted REQUEST-TEXT block in `docs/runbooks/apple-carplay-entitlement-request.md` matches zero case-insensitive hits for watch/driving/video/driver; bundle ID `com.cartube.carplay` recorded as a dated user decision (2026-08-18) before submission |
| 3 | Grant-wiring runbook exists, executable by any later phase, including the entitlements-file sequencing constraint | ✓ VERIFIED | `docs/runbooks/carplay-entitlement-grant-wiring.md` exists, contains `com.apple.developer.carplay-audio`, the sequencing-constraint section (now marked Resolved/Phase 2), and the numbered 11-step post-grant sequence |
| 4 | Build-time secret delivery pipe: Secrets.xcconfig → pbxproj `baseConfigurationReference` → `$(YOUTUBE_API_KEY)` → built Info.plist; fresh-clone (missing-file) failure demonstrated | ✓ VERIFIED | Re-ran `xcodebuild … build` against current (Phase-2/3-modified) pbxproj — `** BUILD SUCCEEDED **`; `plutil -extract YOUTUBE_API_KEY raw` on the built product returns a value (see truth 7 for which value); pbxproj carries `baseConfigurationReference` on both project-level Debug and Release configs (2 occurrences, confirmed); 01-01-SUMMARY.md documents the observed missing-file build error verbatim |
| 5 | Repo hygiene: Secrets.xcconfig gitignored; zero AIza-pattern strings in any git-tracked file | ✓ VERIFIED | `git check-ignore -q Secrets.xcconfig` exits 0; `git grep -nE 'AIza[0-9A-Za-z_-]{30,}'` returns zero matches (exit 1) across the full current tree |
| 6 | A restricted YouTube Data API key exists in a dedicated Google Cloud project (API + bundle-ID restrictions), delivered only via gitignored Secrets.xcconfig (SC2) | ✗ FAILED | `Secrets.xcconfig` still contains `YOUTUBE_API_KEY = BUILD_TIME_SENTINEL_REPLACE_WITH_REAL_KEY` (direct read, 2026-08-19). No Google Cloud project has been created. STATE.md Blockers/Concerns: "Google shipping key not yet created (external, 2026-08-18)" |
| 7 | Built app Info.plist carries the real key at build time (sentinel replaced) | ✗ FAILED | Fresh rebuild's `plutil -extract YOUTUBE_API_KEY raw` on `CarTube.app/Info.plist` prints `BUILD_TIME_SENTINEL_REPLACE_WITH_REAL_KEY`, not an `AIza…` value — direct consequence of truth 6 |
| 8 | If Apple grants the entitlement, the new provisioning profile is wired into the project and the CarPlay scene connection is verified (SC3, granted branch) | ✗ PARTIAL (treated as gap) | Entitlement granted 2026-08-18 mid-Phase-3 (STATE.md, PROJECT.md). `CarTube/CarTube.entitlements` correctly carries `com.apple.developer.carplay-audio = true` (commit 848f8df) — runbook step 8 only. Steps 1-7 (App ID CarPlay capability + new provisioning profile), 9-10 (disable automatic signing, select profile), and 11 (CarPlay Simulator scene verification) are not done — confirmed by STATE.md's own remaining-steps list and by the absence of any profile/signing evidence in the repo (these live outside the repo, in the Apple portal and local Xcode signing state) |

**Score:** 6/8 truths verified (0 present, behavior-unverified)

### Judgment call on truth 8 ("wired the moment it arrives")

The phase goal states the entitlement grant must be "wired the moment it arrives," and SC3 is conjunctive: "the new provisioning profile is wired into the project **and** the CarPlay scene connection is verified." Reading the executed plans and the grant-wiring runbook itself (an explicit 11-step sequence), the entitlements-file edit is step 8 of 11 — necessary but never scoped as sufficient on its own. Steps 1-7 (Apple-portal App ID capability + profile creation/import) and 9-11 (Xcode signing toggle + CarPlay Simulator scene verification) are the steps that actually constitute "wiring the profile" and "verifying the scene connects" — none of those have happened. So this truth is **not met** by the entitlements-file edit alone.

That said, this is not a stub or an oversight: it is correctly and transparently tracked as a dated, actionable item in STATE.md's Blockers/Concerns (not silently blocking), consistent with the roadmap's fallback intent for the "still pending" branch, reasonably extended to this partial-grant scenario. The remaining work is Apple-portal, Xcode-UI, and simulator/device actions with no code-level artifact to grep for — it requires a human developer with Apple Developer Program + Xcode access, mirroring the same shape as the still-open Google key checkpoint. It is reported here as a gap (for `/gsd-plan-phase --gaps` to schedule as a follow-up human checkpoint plan) rather than silently passed.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Config/Secrets.xcconfig.example` | Committed placeholder template with copy/CI instructions | ✓ VERIFIED | Present, contains observed-error wording, copy instructions, CI recipe |
| `Secrets.xcconfig` (repo root) | Local, gitignored, real key value | ⚠️ STUB (value) | File exists and is gitignored, but still holds the sentinel, not a real key |
| `.gitignore` entry | `Secrets.xcconfig` ignored | ✓ VERIFIED | Line 93: `Secrets.xcconfig`, under "Build-time secrets — never commit (public fork)" |
| `CarTube/Info.plist` key `YOUTUBE_API_KEY` | `$(YOUTUBE_API_KEY)` substitution | ✓ VERIFIED | Present, substitution mechanism proven at build time |
| `CarTube.xcodeproj/project.pbxproj` | file reference + `baseConfigurationReference` on Debug/Release | ✓ VERIFIED | 2 occurrences confirmed (project-level Debug + Release), no target-level override |
| `docs/runbooks/apple-carplay-entitlement-request.md` | Paste-ready audio-category submission runbook | ✓ VERIFIED | Present, wording gate clean |
| `docs/runbooks/carplay-entitlement-grant-wiring.md` | Post-grant wiring procedure | ✓ VERIFIED | Present, 11-step sequence, sequencing constraint resolved-and-annotated |
| `docs/runbooks/google-youtube-api-key.md` | Google key provisioning runbook | ✓ VERIFIED | Present, contains YouTube Data API v3, both restriction types, gcloud verification commands |
| `.planning/STATE.md` dated blocker entries | Submission date, category, bundle ID, runbook pointer; Google key + CarPlay wiring status | ✓ VERIFIED | Both blockers present, dated, actionable, pointing at the correct runbooks |
| `.planning/PROJECT.md` Key Decision rows | Audio-category rationale, xcconfig mechanism, dev-key deferral | ✓ VERIFIED | All 3 rows present (lines 74-76), Outcome: Pending (appropriate — grant/key still resolving) |
| `CarTube/CarTube.entitlements` | `com.apple.developer.carplay-audio = true` (post-grant) | ✓ VERIFIED (partial scope) | Present, correctly added per runbook step 8 only; remaining 10 steps outstanding |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| Root `Secrets.xcconfig` | pbxproj base configuration (Debug + Release) | `baseConfigurationReference` | ✓ WIRED | Confirmed on both project-level configs |
| pbxproj base configuration | `CarTube/Info.plist` | `$(YOUTUBE_API_KEY)` substitution | ✓ WIRED | `plutil -extract` proves the substitution reaches the built product (currently resolving to the sentinel — see truth 7) |
| Confirmed bundle ID (01-02) | Apple portal App ID registration | Runbook step 3 | ✓ WIRED | `com.cartube.carplay` registered, entitlement Case-ID 21672656 attached to it |
| Confirmed bundle ID (01-02) | Google key iOS application restriction | Runbook `google-youtube-api-key.md` | ✗ NOT WIRED | Restriction cannot exist because no key/project exists yet |
| Grant-wiring runbook step 8 | Phase 2 entitlements cleanup (INFRA-02) | Sequencing constraint | ✓ WIRED | Runbook's own "Resolved (Phase 2, INFRA-02)" note confirms the entitlements file was already emptied by Phase 2, so step 8 could apply cleanly — confirmed by direct read of `CarTube/CarTube.entitlements` (only the CarPlay key present) |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Simulator build succeeds against current (Phase 2/3-modified) project | `xcodebuild -project CarTube.xcodeproj -scheme CarTube -destination 'platform=iOS Simulator,name=iPhone Air' build` | `** BUILD SUCCEEDED **` | ✓ PASS |
| Built Info.plist carries the xcconfig-injected value | `plutil -extract YOUTUBE_API_KEY raw "$BP/CarTube.app/Info.plist"` | `BUILD_TIME_SENTINEL_REPLACE_WITH_REAL_KEY` | ✓ PASS (pipe works) / confirms truth 7 gap (real key absent) |
| Secrets.xcconfig stays out of git | `git check-ignore -q Secrets.xcconfig` | exit 0 | ✓ PASS |
| No key material in tracked files | `git grep -nE 'AIza[0-9A-Za-z_-]{30,}'` | zero matches (exit 1) | ✓ PASS |
| Request text excludes prohibited wording | `sed -n '/REQUEST-TEXT-BEGIN/,/REQUEST-TEXT-END/p' … \| grep -icE 'watch\|driving\|video\|driver'` | `0` | ✓ PASS |

### Probe Execution

Not applicable — this phase has no `scripts/*/tests/probe-*.sh` conventions and no PLAN/SUMMARY probe references. Skipped.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| INFRA-01 | 01-01, 01-02, 01-03 | CarPlay entitlement submitted under audio category, documented rationale, dated record; new provisioning profile wired when granted; Google key provisioned with restrictions, build-time delivery | ✗ BLOCKED | Apple-submission half (SC1) fully met; Google-key half (SC2) not met (key never created); grant-wiring half (SC3) partially met (step 8 only of 11). REQUIREMENTS.md itself still shows INFRA-01 unchecked and "Pending" in its status table — consistent with this finding |

No orphaned requirements — REQUIREMENTS.md maps only INFRA-01 to Phase 1, and all three plans declare `requirements: [INFRA-01]`.

### Anti-Patterns Found

No new blockers found by this verification pass beyond what `01-REVIEW.md` (deep code review, completed 2026-08-19, 0 critical / 4 warning / 3 info) already documents. Carrying forward without re-deriving, per instructions:

| File | Severity | Impact (from 01-REVIEW.md) |
|------|----------|--------|
| `docs/runbooks/apple-carplay-entitlement-request.md` | ⚠️ Warning (WR-01) | States team `U67AKNW8PW` as current fact; actual signing team is `K2TYLYAWMK` — stale if this runbook is ever re-run literally |
| `docs/runbooks/apple-carplay-entitlement-request.md` | ⚠️ Warning (WR-02) | "Current state" bundle-ID description (`com.avangelista.CarTube`) is stale — Phase 2's rebrand already landed |
| `CarTube.xcodeproj/project.pbxproj` (CarTubeTests) | ⚠️ Warning (WR-03) | Test target bundle ID never rebranded — cosmetic inconsistency, no functional impact |
| pbxproj + runbook | ⚠️ Warning (WR-04) | App Store category `video` sits in tension with the CarPlay `audio`-category framing; residual-risk note doesn't mention it |
| `CarTube/Info.plist` | ℹ️ Info (IN-01) | `CFBundleURLName` still says `com.avangelista.TrollTube` (cosmetic, no functional effect) |
| pbxproj (CarTubeTests config list) | ℹ️ Info (IN-02) | Build-configuration order inconsistency (cosmetic) |
| `CarTube/Info.plist` | ℹ️ Info (IN-03) | Indentation inconsistency (cosmetic) |

No debt markers (`TBD`/`FIXME`/`XXX`/`TODO`/`HACK`/`PLACEHOLDER`) found in any file this phase modified.

### Human Verification Required

#### 1. Complete Google Cloud API key provisioning

**Test:** Follow `docs/runbooks/google-youtube-api-key.md` end to end — create the dedicated Google Cloud project, enable YouTube Data API v3, create the API key, set both restrictions (API: YouTube Data API v3 only; iOS application: `com.cartube.carplay`, `com.cartube.carplay.playon`), enable quota alerting, and paste the real key into root `Secrets.xcconfig`.
**Expected:** A fresh simulator build's `plutil -extract YOUTUBE_API_KEY raw` on the built Info.plist matches `^AIza[0-9A-Za-z_-]{30,}$`; `gcloud services api-keys describe` (or restriction screenshots) confirms both restrictions; `git grep AIza` stays at zero matches.
**Why human:** Login-walled Google Cloud Console action — no agent credential exists for this account.

#### 2. Complete CarPlay entitlement grant wiring

**Test:** Execute the remaining steps of `docs/runbooks/carplay-entitlement-grant-wiring.md` — steps 1-7 (enable CarPlay on App ID `com.cartube.carplay` at developer.apple.com, create and import a new CarPlay-capable provisioning profile), 9-10 (turn OFF "Automatically manage signing" in Xcode, select the imported profile), and 11 (verify the CarPlay scene connects via the CarPlay Simulator from Additional Tools for Xcode).
**Expected:** Xcode signs CarTube against the imported, CarPlay-capable provisioning profile (not automatic signing), and the CarPlay scene visibly connects when launched in the CarPlay Simulator.
**Why human:** Login-walled Apple Developer Portal actions, local Xcode signing-configuration UI, and simulator-observed scene connection — none of which is verifiable by grep/file inspection or performable by an agent.

### Gaps Summary

Two of three success criteria for Phase 1 are not fully met, and both gaps are consistent with what the project's own state tracking (STATE.md, REQUIREMENTS.md, PROJECT.md) already honestly records — this verification did not discover anything hidden, but it does formally close the loop that no `01-VERIFICATION.md` had previously done despite all three plans being executed and summarized as complete/halted.

- **SC1 (Apple submission)** is fully achieved: submitted, dated, rationale recorded as a Key Decision, audio-category wording gate clean.
- **SC2 (Google key)** is not achieved: the restricted key was never created. This is the single highest-impact gap in the phase — Phase 3 (search core) has already executed downstream and shows `SRCH-01: Gaps Found` / `SRCH-04: Gaps Found` in REQUIREMENTS.md's status table, consistent with search functionality lacking a real key.
- **SC3 (grant wiring)** is partially achieved: Apple granted unusually quickly (same day as submission, mid-Phase-3), and the one repo-controllable step (entitlements file) was correctly and immediately wired. The remaining ten steps of the runbook are genuinely human/Apple-portal/Xcode-UI/simulator actions outside any agent's reach, and are already tracked as a dated blocker rather than silently ignored — but the roadmap's literal "provisioning profile wired + scene verified" bar is not yet met.

Both remaining items are appropriately scoped as **human checkpoints** (mirroring the `checkpoint:human-verify` tasks already used successfully elsewhere in this phase) rather than autonomous coding work — a closure plan should schedule them as such rather than attempt to script around a Google/Apple login wall.

---

_Verified: 2026-08-19T00:00:00Z_
_Verifier: Claude (gsd-verifier)_
