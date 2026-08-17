---
phase: 1
slug: external-dependencies-project-setup
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-17
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | shell + plutil + xcodebuild (no test framework this phase — XCTest target arrives in Phase 3) |
| **Config file** | none — Wave 0 checks are inline commands |
| **Quick run command** | `git grep -c AIza -- . ':!*.example' || [ $? -eq 1 ]` |
| **Full suite command** | `xcodebuild -project CarTube.xcodeproj -scheme CarTube -configuration Debug build 2>&1 | tail -1` |
| **Estimated runtime** | ~120 seconds (full build); ~2 seconds (quick) |

---

## Sampling Rate

- **After every task commit:** Run the quick hygiene grep (`AIza` key-material check)
- **After every plan wave:** Run the full xcodebuild (proves xcconfig wiring never broke the build)
- **Before `$gsd-verify-work`:** Full build green + hygiene grep zero hits
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-01-T1 | 01-01 | 1 | INFRA-01 | T-01-01 (key commit) | xcconfig key file gitignored; Info.plist carries `$(YOUTUBE_API_KEY)` substitution | build | `plutil -extract YOUTUBE_API_KEY raw "$BP/CarTube.app/Info.plist"` (BP from `xcodebuild -showBuildSettings` BUILT_PRODUCTS_DIR; sentinel value check) | ❌ W0 (inline) | ⬜ pending |
| 01-01-T2 | 01-01 | 1 | INFRA-01 | T-01-01 | `git grep AIza` over tracked files returns zero key material | shell | `git grep -c AIza -- . ':!*.example' || [ $? -eq 1 ]` | ❌ W0 (inline) | ⬜ pending |
| 01-02-T1 | 01-02 | 1 | INFRA-01 | — | Runbook wording contains no watch/driving/video claims under audio category | shell | `grep -q REQUEST-TEXT-BEGIN docs/runbooks/apple-carplay-entitlement-request.md && grep -q REQUEST-TEXT-END docs/runbooks/apple-carplay-entitlement-request.md && [ "$(sed -n '/REQUEST-TEXT-BEGIN/,/REQUEST-TEXT-END/p' docs/runbooks/apple-carplay-entitlement-request.md \| grep -icE 'watch\|driving\|video\|driver') = 0 ]` | ❌ W0 (inline) | ⬜ pending |
| 01-02-T2 | 01-02 | 1 | INFRA-01 | — | Human submission checkpoint — see Manual-Only table | manual | — | — | ⬜ pending |
| 01-02-T3 | 01-02 | 1 | INFRA-01 | — | Dated STATE.md record exists with submission date | shell | `grep -q 'audio' .planning/STATE.md && grep -q 'carplay-entitlement-grant-wiring' .planning/STATE.md && grep -qE 'Submitted [0-9]{4}-[0-9]{2}-[0-9]{2}\|BLOCKER' .planning/STATE.md` (per plan's exact assertion) | ❌ W0 (inline) | ⬜ pending |
| 01-03-T1 | 01-03 | 2 | INFRA-01 | T-03-01 (quota abuse) | Google key created with both restrictions per runbook | manual+CLI | `gcloud services list --enabled` (human-verified against runbook) | — | ⬜ pending |
| 01-03-T2 | 01-03 | 2 | INFRA-01 | T-01-01 | Real key injected; built plist carries real value, not sentinel | build | `plutil -extract YOUTUBE_API_KEY raw <built app>/Info.plist` matches `^AIza[0-9A-Za-z_-]{30,}$` (per plan Task 2 acceptance) | ❌ W0 (inline) | ⬜ pending |
| 01-03-T3 | 01-03 | 2 | INFRA-01 | — | Exactly three Key Decision rows added; grant status branch resolved | shell | row-count delta assertion per plan (baseline vs after = 3) | ❌ W0 (inline) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Inline hygiene gate: `git grep AIza` zero-hit command added to the executor's per-task loop (no framework install needed — shell only)
- [ ] `docs/runbooks/` directory with the two runbook files (created by 01-02 T1 before its wording gate runs)

*Existing infrastructure (xcodebuild, plutil, gcloud CLI, shell) covers all automated needs; no framework install required this phase.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Apple CarPlay entitlement application actually submitted | INFRA-01 | Login-walled Apple form — agent cannot authenticate as the user | User follows 01-02 runbook, submits at developer.apple.com/carplay under audio category, confirms submission date back to the executor; STATE.md dated record is the artifact |
| Google API key created + restricted in Cloud Console | INFRA-01 | Login-walled Google Console | User follows 01-03 runbook: dedicated project, enable YouTube Data API v3, create key, restrict to YouTube Data API + iOS bundle IDs, paste key into local gitignored xcconfig; plutil build check verifies injection |
| Bundle ID final value confirmed | INFRA-01 | Owner decision (default prepared: user's own reverse-DNS) | User confirms exact string at 01-02 checkpoint before App ID registration |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Manual-Only coverage
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify (01-02-T2 checkpoint is bracketed by automated T1/T3)
- [ ] Wave 0 covers all MISSING references (all inline — no framework)
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
