---
phase: 02
slug: severance-signing-modernization
status: verified
# threats_open = count of OPEN threats at or above workflow.security_block_on severity (the blocking gate)
threats_open: 0
asvs_level: 1
created: 2026-08-18
---

# Phase 02 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| entitlements file → code signature | private keys here become instant App Review flags embedded in every signed build | signing capabilities |
| repo → public fork | any tracked TrollStore/ldid artifact is visible to reviewers and forks | packaging tooling |
| built binaries → CI gate | the only automated barrier against private-API regression reaching upload | binary strings |
| marker list → gate efficacy | over-scoped markers fail retained features; under-scoped markers miss regressions | scan coverage |
| app process → private frameworks (dlsym/CFBundle) | every removed call crossed into SpringBoard/BackBoard/MediaRemote territory | private API access |
| app container → system preference domains | CFPreferencesCopyAppValue against com.apple.springboard / com.apple.backboardd read outside the container (guideline 2.5.2) | cross-app preference reads |
| Settings UI → process lifecycle | exit(0) path crossed from UI action into forbidden process termination | process control |
| ObjC runtime queries → Debug UI | status rows read runtime metadata (class_getInstanceMethod) — read-only, no new private calls | hook install-state |
| Debug screen → UserDefaults | script rows write user preferences; abuse surface is a user's own defaults, already the app's persistence contract | user preferences |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-02-01 | Elevation of Privilege | CarTube.entitlements | high | mitigate | Emptied all 7 private keys | closed |
| T-02-02 | Tampering | ipabuild.sh deletion | medium | mitigate | Deleted; `git grep -nI 'ldid\|ipabuild'` exits 1 (no matches) | closed |
| T-02-03 | Repudiation | removed keys re-added later | medium | mitigate | Removed-symbol markers wired into `scripts/scan-private-apis.sh` + CI | closed |
| T-02-04 | Tampering | scan script marker list | high | mitigate | TDD suite (`test-scan-private-apis.sh`) — 6/6 pass | closed |
| T-02-05 | Tampering | workflow bypass (continue-on-error) | medium | mitigate | Confirmed absent from `.github/workflows/scan.yml` | closed |
| T-02-06 | Information Disclosure | CI handling of API key | high | mitigate | `.github/workflows/scan.yml` uses `YOUTUBE_API_KEY=CI_PLACEHOLDER`, not a real key | closed |
| T-02-07 | Information Disclosure | getNowPlaying MediaRemote read | high | mitigate | Deleted; 0 matches for `getNowPlaying`/`checkIfYouTubePlaying` etc. | closed |
| T-02-08 | Elevation of Privilege | brightness/dlsym unsafeBitCast NULL crash | high | mitigate | Brightness trio deleted caller-first; build gate confirms no dangling reference | closed |
| T-02-09 | Information Disclosure | CFPreferences reads outside container | high | mitigate | `getSettingsBrightness`/`isAutoBrightnessEnabled` deleted (0 matches) — see caveat below | closed |
| T-02-10 | Denial of Service | exit(0) from shipping UI | high | mitigate | Replaced with `applyConfigurationInPlace()`; 0 matches for `exitGracefully`/`exit(0)` | closed |
| T-02-11 | Tampering | WKWebView re-creation loses message handler/delegates | medium | mitigate | `applyConfigurationInPlace()` reuses `applyConfiguration()`'s single construction path; delegates/handler confirmed reassigned | closed |
| T-02-12 | Tampering | pbxproj corruption from hand-editing | high | mitigate | ruby xcodeproj-gem mutation with post-save grep assertions; real `BUILD SUCCEEDED` on both targets | closed |
| T-02-13 | Denial of Service | hooks silently dead at iOS 16 (Pitfall 5) | high | mitigate | Debug status rows + blocking human checkpoint — see caveat below | closed |
| T-02-14 | Information Disclosure | debug surface shipping to production | low | accept | Debug screen already existed and is user-navigable; rows report status only, leak no secrets; revisit gating before TestFlight (Phase 6) | closed |
| T-02-SC | Tampering | package installs (all 4 plans) | low | accept | No package installs in any of this phase's 4 plans; only the `Dynamic` SPM package was *removed* | closed |

*Status: open · closed · open — below high threshold (non-blocking)*
*Severity: critical > high > medium > low — only open threats at or above workflow.security_block_on (`high`) count toward threats_open*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

**Caveats on closed threats (tracked, non-blocking):**
- **T-02-09**: the primary vulnerability (the app performing the CFPreferences reads) is verified deleted. The scan-gate's defense-in-depth coverage for this threat family is incomplete — `BKEnableALS` is not in `scan-private-apis.sh`'s marker list even though the mitigation plan named it alongside `SBBacklightLevel` (only the latter is present). Tracked as `02-REVIEW.md` WR-01, left open by user decision.
- **T-02-13**: the mitigation mechanism (Debug status rows + blocking human checkpoint) is in place and was exercised. One of the four rows (HideScrollBar) has a verification-logic defect that may cause it to report PASS even if the underlying hook failed to install — this weakens the row's ability to detect a *silent hook death*, which is exactly what T-02-13 mitigates against. Tracked as `02-REVIEW.md` CR-02 / `02-VERIFICATION.md` human-verification item 1, left open by user decision. Does not reopen T-02-13 itself (the mechanism exists and 3/4 rows are sound; AutoResize and the keyboard-API row are unaffected), but is the one item that could let a future Pitfall-5 regression through undetected.

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| R-02-01 | T-02-14 | Debug screen already existed pre-phase and is user-navigable; new rows report status/booleans only, no secrets. Revisit gating before TestFlight submission (Phase 6). | Plan 02-04 (accepted at plan time) | 2026-08-18 |
| R-02-02 | T-02-SC | No package installs across any of this phase's 4 plans (only a removal). | Plans 02-01–02-04 (accepted at plan time) | 2026-08-18 |

*Accepted risks do not resurface in future audit runs.*

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-08-18 | 15 | 15 | 0 | Claude (orchestrator, L1 grep-depth per short-circuit rule — asvs_level 1, register_authored_at_plan_time: true, threats_open: 0) |

Register built from all 4 `*-PLAN.md` `<threat_model>` blocks (register authored at plan time for every plan in this phase). Classification cross-checked against this session's independently-run verification: live `xcodebuild ... build` → `BUILD SUCCEEDED`, `codesign -d --entitlements` → empty dict, `scripts/scan-private-apis.sh` exit 0 on both compiled binaries, `bash scripts/tests/test-scan-private-apis.sh` → 6/6 pass, and targeted greps for every deleted symbol (0 matches) and every survivor (present). Per the short-circuit rule (`threats_open: 0 AND register_authored_at_plan_time: true AND asvs_level == 1`), `gsd-security-auditor` was not spawned — L1 grep-depth verification is sufficient at ASVS level 1 with a plan-time-authored register and zero open threats.

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-08-18
