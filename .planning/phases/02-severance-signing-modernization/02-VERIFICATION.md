---
phase: 02-severance-signing-modernization
verified: 2026-08-18T19:05:00Z
status: passed
score: 11/13 must-haves verified
behavior_unverified: 2
overrides_applied: 0
human_verification:

  - test: "Deliberately break the AutoHook type-encoding match for HideScrollBar (or run on an iOS version where the swizzle fails) and confirm the Debug screen's HideScrollBar row reports FAIL, not PASS"
    expected: "Row should read FAIL when the hook did not install"
    why_human: "Static analysis of Debug.swift + AutoHookImplementor.m (confirmed independently, matching 02-REVIEW.md CR-02) shows the row compares _UIStaticScrollBar.layoutSubviews' IMP against its superclass's IMP. _UIStaticScrollBar is a specialized UIKit view that very likely overrides layoutSubviews on its own already, so the IMPs would differ from the superclass whether or not AutoHookImplementor's swizzle ever installed — the row can structurally always read PASS. This can only be settled by actually forcing a hook failure and observing the row, which requires a device/simulator session and is not visible from source alone. CR-02 was reviewed and knowingly left unfixed by user decision (02-REVIEW.md)."

  - test: "With a live CarPlay scene connected (controller non-nil), toggle Screen Persistence Helper in Settings and confirm the idle timer changes immediately, without needing a scene resign/reactivate cycle"
    expected: "isIdleTimerDisabled flips synchronously when Save Settings is tapped while CarPlay is connected"
    why_human: "CR-01 was fixed in code (CarPlaySingleton.applyConfiguration() now calls controller?.enablePersistence()/disablePersistence() based on the current ScreenPersistenceOn UserDefaults value) and is architecturally sound (mirrors the exact gating CarPlaySceneDelegate already uses), but the fix itself notes it was never simulator-observed end-to-end because `controller` is only non-nil with a live CarPlay scene, and no CarPlay entitlement/scene is available in this sandbox yet (Phase 1 external clock, Case-ID 21672656, still pending)."
---

# Phase 2: Severance & Signing Modernization Verification Report

**Phase Goal:** The binary contains no auto-detectable review violations and installs under standard App Store signing — sever before extend, because the files search must touch are the exact files losing MediaRemote/brightness code
**Verified:** 2026-08-18T19:05:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (Roadmap Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | App and share extension build/run with standard App Store signing; no TrollStore artifacts remain | ✓ VERIFIED | Independently re-ran `xcodebuild -project CarTube.xcodeproj -scheme CarTube -destination 'id=F14D9B48-EF6B-4ACD-BB09-2D5951BF5D0A' build` in this session → `** BUILD SUCCEEDED **`. `codesign -d --entitlements :- CarTube.app` → `<dict></dict>` (empty). `ipabuild.sh` absent from working tree; `git grep -nI 'ldid|ipabuild' -- ':!*.planning*' ':!AGENTS.md'` exits 1 (no matches). All 4 signing-config slots (CarTube Debug/Release, PlayOnCarTube Debug/Release) now consistently use `DEVELOPMENT_TEAM = K2TYLYAWMK` and matching bundle-ID family (`com.cartube.carplay` / `com.cartube.carplay.playon`) — CR-03 fix confirmed live in `project.pbxproj:541,584,621,648`. |
| 2 | Now-playing takeover and lock-screen dimming removed, screen-off warning label survives, every removed symbol caller-mapped | ✓ VERIFIED | `grep -rn 'checkIfYouTubePlaying\|dontAskAboutLastPlaying\|askAboutLastPlaying\|getNowPlaying'` over `CarTube/` and `PlayOnCarTube/` → 0 matches. `grep -rn 'LockScreenDimmingOn' --include='*.swift' .` → 0 matches. Survivors confirmed present: `showScreenOffWarning` (CarPlaySingleton.swift), `registerForScreenOffNotification` (CarTubeApp.swift), `showWarningLabel` (CarPlayViewController.swift). |
| 3 | Deployment target iOS 16.0; injected-JS behaviors (ad block, SponsorBlock, age-restriction bypass) re-validated via hook-verification debug screen | ✓ VERIFIED | `grep -c 'IPHONEOS_DEPLOYMENT_TARGET = 16.0' project.pbxproj` = 6, `= 14.0` = 0. `Debug.swift` contains 3 script re-validation rows (AdBlocker/SponsorBlock/AgeRestrictBypass), each writes its UserDefaults key and calls `CarPlaySingleton.shared.applyConfiguration()` (reuses the same construction path Settings uses) then confirms via alert. Orchestrator's simulator pass (02-04-SUMMARY) exercised all three rows live with no crash. |
| 4 | Settings has no dead toggles; changing settings applies webview config in place instead of terminating the app | ✓ VERIFIED | Read full `Settings.swift`: no Lock Screen Dimming section, no "will quit" language, footer reads "Changes apply immediately to the CarPlay browser." `saveSettings()` calls `CarPlaySingleton.shared.applyConfiguration()` after all writes. `grep -rn 'exitGracefully\|exit(0)' --include='*.swift' CarTube/` → 0 matches. CR-01 fix (idle-timer resync on save) present in `CarPlaySingleton.swift:80-87`. |
| 5 | `strings` binary scan gate runs in CI on both binaries, fails build on private-API markers | ✓ VERIFIED | Independently ran `bash scripts/tests/test-scan-private-apis.sh` → 6/6 PASS. Independently built the real binaries this session and ran `scripts/scan-private-apis.sh` against both `CarTube.app/CarTube` and `CarTube.app/PlugIns/PlayOnCarTube.appex/PlayOnCarTube` → exit 0 on both (real Mach-O, not fixtures — the marker list is proven to catch the pre-severance app per 02-02-SUMMARY's real-source proof). `.github/workflows/scan.yml` wires the same script into CI on push/PR for both binary paths with no `continue-on-error`. |

**Score:** 5/5 roadmap success criteria structurally verified (see plan-level must-haves below for finer-grained gaps)

### Plan-Level Must-Haves (finer detail beneath the 5 roadmap truths)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 6 | CarTube.entitlements is a bare empty dict; simulator build succeeds with it attached | ✓ VERIFIED | `plutil -convert json -o -` → `{}`. Confirmed above. |
| 7 | Each surviving settings key resolves at its expected contract sites | ✓ VERIFIED (with note) | `SponsorBlockOn`/`AgeRestrictBypassOn`/`AdBlockerOn` now resolve in 4 files (not the 3 the 02-03 plan asserted) — `Debug.swift`'s script re-validation rows (added legitimately by plan 02-04, after 02-03's audit ran) added a 4th reference. This is expected growth from a later, in-scope plan, not a contract violation; `Zoom` and `ScreenPersistenceOn` remain at 3 files each. |
| 8 | Debug screen reports live runtime status for AutoResize, HideScrollBar, keyboard API, idle timer | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED (HideScrollBar row specifically) | Code present and wired (`Debug.swift:70-85`), AutoResize/keyboard/idle-timer checks read plausible runtime state. HideScrollBar's check (`checkHideScrollBarInstalled()`) compares `_UIStaticScrollBar.layoutSubviews` IMP against its **superclass's** IMP — independently confirmed by reading `AutoHookImplementor.m` that this check cannot distinguish "hook installed" from "class already overrides the method on its own," which `_UIStaticScrollBar` (a specialized scroll-indicator view) almost certainly does regardless of the swizzle. This is 02-REVIEW.md's CR-02, confirmed independently in this verification, left unfixed by explicit user decision. See Human Verification below. |
| 9 | Deployment target 16.0 at all 6 sites, Dynamic SPM package fully removed | ✓ VERIFIED | `grep -c 'Dynamic'` and `grep -c 'XCRemoteSwiftPackageReference'` over `project.pbxproj` both = 0; `find CarTube.xcodeproj -name Package.resolved` → none. |
| 10 | scan-private-apis.sh passes on the actual compiled binaries (not just source grep) | ✓ VERIFIED | Confirmed above with a fresh build in this verification session — this closes out the "unknown"/`human_judgment: true` coverage items left open in 02-01/02-02/02-03's own SUMMARYs (their local sandbox had a simulator-runtime mismatch that has since been resolved). |
| 11 | Settings apply-in-place applies ALL settings, not just webview config | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | CR-01 (Screen Persistence Helper written but not applied) is fixed in code and architecturally sound, but per the fix's own note it has not been observed end-to-end against a live CarPlay scene (`controller` is nil without one; no CarPlay entitlement available in this environment). See Human Verification below. |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `CarTube/CarTube.entitlements` | Empty plist dict, file retained | ✓ VERIFIED | Confirmed empty; CODE_SIGN_ENTITLEMENTS build settings unchanged, still point at this file |
| `ipabuild.sh` | Deleted | ✓ VERIFIED | Absent from working tree and git index |
| `scripts/scan-private-apis.sh` | Executable, 15-marker array, SCAN_INPUT_FILE hook | ✓ VERIFIED | Executable, exit 0 on clean binaries, exit 1 with marker names on synthetic marker fixtures (test suite) |
| `scripts/tests/test-scan-private-apis.sh` | 6-case hermetic suite | ✓ VERIFIED | 6/6 PASS, re-run independently this session |
| `.github/workflows/scan.yml` | CI job scanning both binaries, no continue-on-error | ✓ VERIFIED | Present, references both binary paths, `YOUTUBE_API_KEY` placeholder override, no `continue-on-error` |
| `CarPlayViewController.applyConfiguration()` / `.applyConfigurationInPlace()` | Reusable config factory + in-place re-creation | ✓ VERIFIED | Both methods present and match the plan's behavioral contract (read directly, lines 20-98) |
| `CarPlaySingleton.applyConfiguration()` facade | Settings → singleton → controller passthrough | ✓ VERIFIED | Present, includes CR-01's idle-timer resync |
| `CarTube/Views/Debug.swift` Hook Verification section | 4 status rows + 3 script rows | ✓ VERIFIED (wiring) / ⚠️ (HideScrollBar accuracy) | All rows present, wired through `CarPlaySingleton.shared`, no direct `CarPlayViewController` reference; HideScrollBar row's correctness is the CR-02 gap above |
| `project.pbxproj` | 6× iOS 16.0, 0× Dynamic/SPM objects, consistent signing team | ✓ VERIFIED | All confirmed above, including the CR-03 team-consistency fix |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `Settings.saveSettings()` | `CarPlaySingleton.applyConfiguration()` | direct call after UserDefaults writes | ✓ WIRED | Confirmed in Settings.swift:23 |
| `CarPlaySingleton.applyConfiguration()` | `CarPlayViewController.applyConfigurationInPlace()` | `controller?.applyConfigurationInPlace()` | ✓ WIRED | Confirmed CarPlaySingleton.swift:81 |
| `CarPlaySingleton.applyConfiguration()` | `enablePersistence()`/`disablePersistence()` | UserDefaults-value branch (CR-01 fix) | ✓ WIRED | Confirmed CarPlaySingleton.swift:82-86; not yet behaviorally observed live (see Human Verification) |
| CI build products | `scripts/scan-private-apis.sh` | string match on both binary paths | ✓ WIRED | Confirmed in `.github/workflows/scan.yml`; independently proven to work against real, freshly-built binaries this session |
| `Debug.swift` script rows | `CarPlaySingleton.shared.applyConfiguration()` | button action → facade → webview reload | ✓ WIRED | Confirmed and exercised live per 02-04-SUMMARY's orchestrator-driven checkpoint |
| `Debug.swift` HideScrollBar row | `AutoHookImplementor`'s actual swizzle state | IMP comparison | ⚠️ WIRED BUT UNRELIABLE | Wired (compiles, runs, renders a result) but the comparison target (superclass IMP) does not correlate with actual hook-install state — see CR-02 |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|--------------|--------|----------|
| INFRA-02 | 02-01 | Standard signing, TrollStore artifacts removed | ✓ SATISFIED (code) / ⚠️ doc-stale | Fully verified in code and via a real build this session. **REQUIREMENTS.md still shows `[ ]` unchecked and its traceability table row still says "Pending"** — no plan's docs-commit ever flipped this checkbox (checked git log for `docs(02-01)` commits; none touch REQUIREMENTS.md's INFRA-02 line). Documentation bookkeeping gap, not a functional gap. |
| INFRA-03 | 02-03 | Riskiest private APIs removed, callers mapped | ✓ SATISFIED | REQUIREMENTS.md already shows `[x]`/"Complete" — consistent with verified code. |
| INFRA-04 | 02-04 | Deployment target 16.0 + hook re-validation debug screen | ✓ SATISFIED (code, with CR-02 caveat) / ⚠️ doc-stale | Code fully verified (deployment target, SPM removal, debug screen wiring) except the CR-02 HideScrollBar-row-accuracy gap noted above. **REQUIREMENTS.md still shows `[ ]` unchecked / "Pending"** — same bookkeeping gap as INFRA-02. |
| INFRA-05 | 02-02 | strings scan CI gate | ✓ SATISFIED | REQUIREMENTS.md shows `[x]`/"Complete", matches verified evidence. |
| INFRA-06 | 02-03 | Settings no longer exits via `exit(0)` | ✓ SATISFIED | REQUIREMENTS.md shows `[x]`/"Complete", matches verified evidence. |

**Orphaned requirements:** None — all 5 requirement IDs assigned to Phase 2 (INFRA-02 through INFRA-06) are claimed by exactly one plan each (02-01, 02-03, 02-02, 02-04, 02-03 respectively) and all 5 have corresponding implementation evidence.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `.planning/REQUIREMENTS.md` | 13, 15, 78, 80 | INFRA-02 and INFRA-04 checkboxes/traceability rows never flipped to complete despite verified implementation | ℹ️ Info | Bookkeeping drift only; does not affect the shipped binary. Recommend a follow-up commit to sync REQUIREMENTS.md with actual completion state. |
| `README.md` | 1, 11 | "Supports iOS 14.0 - 15.4.1" banner survives the iOS 16.0 deployment-target raise | ⚠️ Warning | User-facing factually false claim (02-REVIEW.md WR-05, confirmed still present, left unfixed by user decision) |
| `AGENTS.md` | 42, 63, 67, 148, 240, 248 | Documents the removed `Dynamic` package and the retired "exit to apply" Settings contract as if they still exist | ⚠️ Warning | This is the exact failure mode plan 02-01's objective was written to prevent ("Phases 3-6 executors read the new baseline, not the TrollStore-era one") — AGENTS.md was regenerated once in 02-01 but never refreshed after 02-03/02-04 changed the very things it documents. Confirmed still stale (02-REVIEW.md WR-06, left unfixed by user decision). Recommend regenerating before Phase 3 begins. |
| `CarTube/CarPlay/CarPlaySingleton.swift` | 15, 35-37 | `isCPWindowActive` is write-only dead state (all its former readers were deleted in the caller-first pass) | ℹ️ Info | Cosmetic dead code, not a functional risk (02-REVIEW.md WR-04, left unfixed by user decision) |
| `CarTube/CarPlay/CarPlayViewController.swift` | ~280 | Force-unwrap on a URL string reachable from externally-supplied input | ℹ️ Info | Pre-existing pattern, flagged by review (WR-07), left unfixed by user decision; not introduced by this phase's severance work |

No debt markers (`TBD`/`FIXME`/`XXX`) or placeholder/stub patterns found in any file this phase modified.

## Human Verification Required

### 1. HideScrollBar Debug-screen row accuracy (CR-02)

**Test:** Force the AutoHook type-encoding check to fail for `HOOK_UIStaticScrollBar` (e.g. temporarily rename/break the hook class, or run on an OS version where the target's `layoutSubviews` signature changed), then read the HideScrollBar row on the Debug screen.
**Expected:** The row should read FAIL when the hook did not install.
**Why human:** The check compares against the **superclass's** IMP, not the hook's own IMP — a specialized view class overriding a UIKit method on itself (which `_UIStaticScrollBar` almost certainly does) will show a superclass-IMP difference whether or not the swizzle ever ran. This can only be settled by deliberately breaking the hook and observing the row on a real device/simulator; source review alone (confirmed independently against `AutoHookImplementor.m` in this verification) strongly suggests it always reads PASS. Reviewed and knowingly deferred by user decision (02-REVIEW.md CR-02); recommend fixing per the review's suggested patch (compare against the hook class's own IMP, not the superclass) before relying on this row.

### 2. Screen Persistence Helper live-apply behavior with an active CarPlay scene (CR-01 fix)

**Test:** With a CarPlay entitlement/scene connected, open Settings mid-session, toggle Screen Persistence Helper, tap Save, and confirm `UIApplication.shared.isIdleTimerDisabled` changes immediately (not just on the next scene resign/reactivate).
**Expected:** Idle-timer state flips synchronously with the save action while CarPlay is connected.
**Why human:** The fix code is present and architecturally sound (mirrors `CarPlaySceneDelegate`'s existing gating), but no CarPlay entitlement is available in this environment yet (Phase 1's external clock — Case-ID 21672656 — is still pending), so `controller` has never been non-nil during any test of this path. This is a real runtime behavior, not visible from source alone once wired.

## Gaps Summary

No BLOCKER-level gaps. All 5 roadmap success criteria are independently verified against real, freshly-executed evidence in this session (actual `BUILD SUCCEEDED`, actual `codesign` entitlements dump, actual `scan-private-apis.sh` pass against the compiled binaries, actual grep confirmation of every deleted symbol and surviving symbol). The two 🛑-critical findings from the deep code review (CR-01 mismatched signing teams / CR-03 unapplied persistence toggle — note: CR-01 and CR-03 numbering in 02-REVIEW.md refers to the persistence-toggle and signing-team bugs respectively) were both fixed and are confirmed live in the code.

Two items remain open, both already known and explicitly deferred by user decision rather than newly discovered here:

- **CR-02** (HideScrollBar Debug row can structurally always PASS) — a real, confirmed logic defect in a debug-only diagnostic row, not in shipped user-facing behavior or App Store review surface. Routed to human verification.
- **CR-01's fix, end-to-end** — code-level fix confirmed present and correctly gated, but never observed against a live CarPlay scene due to the still-pending CarPlay entitlement from Phase 1. Routed to human verification.

Additionally, two documentation-only gaps are noted for follow-up (not blocking): REQUIREMENTS.md's INFRA-02/INFRA-04 checkboxes were never flipped despite verified completion, and AGENTS.md/README.md have drifted out of sync with this phase's own changes (Dynamic package removal, Settings exit-to-apply retirement, iOS 16 floor) — ironically the exact staleness risk plan 02-01's objective was written to prevent, now recurring because the docs were never refreshed again after 02-03/02-04.

---

_Verified: 2026-08-18T19:05:00Z_
_Verifier: Claude (gsd-verifier)_
