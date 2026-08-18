---
phase: 02-severance-signing-modernization
plan: 03
subsystem: infra
tags: [swift, uikit, wkwebview, privacy, settings, mediaremote, springboard, backboardservices]

# Dependency graph
requires:
  - phase: 02-severance-signing-modernization
    plan: 01
    provides: standard-signing baseline, entitlements emptied to zero private keys
  - phase: 02-severance-signing-modernization
    plan: 02
    provides: scripts/scan-private-apis.sh permanent removed-symbols scanner (used here for source-level partial verification)
provides:
  - Now-playing takeover feature fully deleted (getNowPlaying, checkIfYouTubePlaying, dontAskAboutLastPlaying, askAboutLastPlaying, import Dynamic)
  - Brightness/lock-screen-dimming private-API trio fully deleted (isScreenLocked, getScreenBrightness, setScreenBrightness, isAutoBrightnessEnabled, getSettingsBrightness, setAutoBrightness, saveInitialBrightness, setLowBrightness, restoreBrightness, registerForUnlockNotification)
  - LockScreenDimmingOn settings key retired from all 3 contract sites (CarTubeApp registration, Settings state/write, CarPlaySingleton consumption)
  - CarPlayViewController.applyConfiguration() — reusable WKWebViewConfiguration factory
  - CarPlayViewController.applyConfigurationInPlace() — teardown/recreate/reload path replacing exit(0)-to-apply
  - CarPlaySingleton.applyConfiguration() facade (Settings → singleton → controller)
  - Settings.saveSettings() applies in place instead of calling exitGracefully(); exitGracefully() deleted
  - enablePersistence()/disablePersistence() rewritten on UIApplication.shared.isIdleTimerDisabled; NoSleep hidden webview and its polling timer deleted
affects: [02-04-deployment-target-raise, phase-3-search-and-voice]

# Actuals (#2632)
actuals:
  tokens: 6000
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "WKWebViewConfiguration construction extracted into a single reusable factory method (applyConfiguration) consumed by both first-load and in-place-reload paths — one construction path, no config drift"
    - "Settings apply-in-place: tear down and reconstruct the WKWebView (WKWebView cannot swap configuration post-init), reassign delegates/gesture recognizers, restore z-order and frame, reload prior URL — replaces exit(0)-to-apply"
    - "Screen persistence on the public UIApplication.shared.isIdleTimerDisabled flag — no hidden second WKWebView, no polling timer"

key-files:
  created: []
  modified:
    - CarTube/Views/ContentView.swift
    - CarTube/CarTubeApp.swift
    - CarTube/CarPlay/CarPlaySingleton.swift
    - CarTube/CarPlay/CarPlaySceneDelegate.swift
    - CarTube/Util/Utilities.swift
    - CarTube/CarPlay/CarPlayViewController.swift
    - CarTube/Views/Settings.swift

key-decisions:
  - "registerForUnlockNotification deleted (not kept) — its only caller (restoreBrightness) died with the brightness trio, and the warning label self-hides via its own 3-second timer, so nothing needs the unlock event. This resolves the 'planner decision point' PATTERNS.md flagged, and matches scan-private-apis.sh's own header comment (written in plan 02-02, before this plan executed) which already documents com.apple.springboard.lockstate as 'removed by plan 02-03'."
  - "NoSleepEnable.js stays on disk as an unreferenced bundle resource (plan 02-04's scope, not this plan's) — its presence is harmless string noise, out of the private-API gate's marker vocabulary"

requirements-completed: [INFRA-03, INFRA-06]

coverage:
  - id: D1
    description: "A simulator build of scheme CarTube succeeds after deleting every MediaRemote and BackBoard/SpringBoard brightness path"
    requirement: INFRA-03
    verification:
      - kind: other
        ref: "xcodebuild -project CarTube.xcodeproj -scheme CarTube -destination 'platform=iOS Simulator,name=iPhone Air' build; also attempted target-mode -sdk iphonesimulator build bypassing scheme resolution"
        status: unknown
    human_judgment: true
    rationale: "Same environment limitation logged in WINDOWS.md entries 1-4 (02-01, 02-02): this sandbox's Xcode 26.3 ships iphonesimulator SDK 26.2 (23C57) but only the iOS 26.5 (23F77) simulator runtime is installed. Scheme-mode resolves zero destinations; target-mode links PlayOnCarTube successfully but CompileAssetCatalogVariant fails before the CarTube app target's own Swift sources compile. A machine/CI runner with a matching runtime is required. Logged as WINDOWS.md entry 5."
  - id: D2
    description: "The strings output of the built CarTube binary contains none of the removed private-API markers"
    requirement: INFRA-03
    verification:
      - kind: other
        ref: "SCAN_INPUT_FILE=<file> scripts/scan-private-apis.sh <file> run against all 7 files this plan modified (Utilities.swift, CarPlaySingleton.swift, CarPlayViewController.swift, CarPlaySceneDelegate.swift, CarTubeApp.swift, Settings.swift, ContentView.swift) — all 7 clean, zero markers"
        status: pass
      - kind: other
        ref: "compiled-binary strings scan (must_haves.truths literal binary check)"
        status: unknown
    human_judgment: true
    rationale: "Source-level scan is strong partial evidence (the same scanner plan 02-02 proved detects these exact markers on the pre-severance source), but the literal built-binary check needs the same missing simulator runtime as D1. Deferred to CI (scripts/scan.yml already wired in 02-02)."
  - id: D3
    description: "Saving Settings no longer terminates the process — applyConfigurationInPlace() replaces exitGracefully()/exit(0); the app stays running"
    requirement: INFRA-06
    verification:
      - kind: unit
        ref: "grep -rn 'exitGracefully|exit(0)' --include='*.swift' CarTube/ → clean; grep for exit/terminate/suspend inside applyConfigurationInPlace's body → clean"
        status: pass
    human_judgment: false
  - id: D4
    description: "LockScreenDimmingOn key, its Settings toggle row, and its registration are fully gone across all 3 contract sites"
    requirement: INFRA-03
    verification:
      - kind: unit
        ref: "grep -r 'LockScreenDimmingOn' --include='*.swift' . → 0 matches"
        status: pass
    human_judgment: false
  - id: D5
    description: "Each surviving settings key (SponsorBlockOn, AgeRestrictBypassOn, AdBlockerOn, Zoom, ScreenPersistenceOn) still resolves in exactly 3 files"
    requirement: INFRA-06
    verification:
      - kind: unit
        ref: "grep -rl '\"<key>\"' --include='*.swift' CarTube/ for each of the 5 keys → exactly 3 files each, all registered in CarTubeApp.registerDefaults"
        status: pass
    human_judgment: false
  - id: D6
    description: "The screen-off warning label path survives untouched (showScreenOffWarning, showWarningLabel, registerForScreenOffNotification all still exist with callers)"
    requirement: INFRA-03
    verification:
      - kind: unit
        ref: "grep -q 'showScreenOffWarning' CarPlaySingleton.swift, grep -q 'registerForScreenOffNotification' CarTubeApp.swift, grep -q 'showWarningLabel' CarPlayViewController.swift — all present"
        status: pass
    human_judgment: false
  - id: D7
    description: "Now-playing takeover feature removed — no alert about 'You were watching this video' can appear"
    requirement: INFRA-03
    verification:
      - kind: unit
        ref: "grep -rn 'checkIfYouTubePlaying|dontAskAboutLastPlaying|askAboutLastPlaying|getNowPlaying' --include='*.swift' CarTube/ PlayOnCarTube/ → 0 matches"
        status: pass
    human_judgment: false

duration: 22min
completed: 2026-08-18
status: complete
---

# Phase 2 Plan 3: Severance + In-Place Settings Application Summary

**Deleted the MediaRemote now-playing takeover and BackBoard/SpringBoard brightness private-API surface caller-first across 7 files, retired the LockScreenDimmingOn 3-file settings contract, extracted a reusable WKWebViewConfiguration factory so Settings applies changes in place instead of calling exit(0), and replaced the hidden-webview NoSleep hack with the public idle timer.**

## Performance

- **Duration:** 22 min
- **Started:** 2026-08-18T09:58:00Z
- **Completed:** 2026-08-18T10:20:00Z
- **Tasks:** 3
- **Files modified:** 7

## Accomplishments

- Now-playing takeover fully removed: `getNowPlaying`, `checkIfYouTubePlaying`, `dontAskAboutLastPlaying`, `askAboutLastPlaying`, and the `Dynamic`/MediaRemote framework calls are gone from every caller and definition site
- Brightness/lock-screen-dimming private-API trio fully removed: `isScreenLocked`, `getScreenBrightness`, `setScreenBrightness`, `isAutoBrightnessEnabled`, `getSettingsBrightness`, `setAutoBrightness`, `saveInitialBrightness`, `setLowBrightness`, `restoreBrightness`, `registerForUnlockNotification` — all deleted caller-first, zero dangling references
- `LockScreenDimmingOn` settings key retired from all 3 contract sites (registration, state/write, consumption)
- `CarPlayViewController.applyConfiguration()` extracts the WKWebViewConfiguration construction into a reusable factory (script selection, zoom, keyboard handler, media flags) — identical output to the original inline `viewDidLoad` block for the same UserDefaults state
- `CarPlayViewController.applyConfigurationInPlace()` tears down and recreates the WKWebView (delegates, gesture recognizers, z-order below `keyboardView`, keyboard-aware frame, reload of the prior URL or homepage) with no process exit
- `CarPlaySingleton.applyConfiguration()` facade routes Settings → singleton → controller, mirroring the existing `goHome`/`toggleKeyboard` passthrough shape
- `Settings.saveSettings()` now calls the facade after all `UserDefaults` writes instead of `exitGracefully()`; the footer no longer says "The app will quit."; `exitGracefully()` itself is deleted from `Utilities.swift`
- NoSleep hidden `WKWebView` + its `_hasSleepDisabler` polling `Timer` deleted entirely; `enablePersistence()`/`disablePersistence()` now toggle `UIApplication.shared.isIdleTimerDisabled` directly
- Screen-off warning label path (`showScreenOffWarning`, `showWarningLabel`, `registerForScreenOffNotification`) survives untouched, as required by ROADMAP success criterion 2
- All 5 surviving settings keys (`SponsorBlockOn`, `AgeRestrictBypassOn`, `AdBlockerOn`, `Zoom`, `ScreenPersistenceOn`) audited and confirmed to still resolve in exactly 3 Swift files each

## Task Commits

Each task was committed atomically:

1. **Task 1: Caller-first deletion — now-playing takeover, brightness trio, LockScreenDimmingOn contract** - `1f1a048` (feat)
2. **Task 2: In-place configuration — extract applyConfiguration, replace NoSleep webview with idle timer** - `42ef7eb` (feat)
3. **Task 3: Settings apply-in-place wiring + toggle cleanup + surviving-key audit** - `9ac0e11` (feat)

**Plan metadata:** commit pending (this SUMMARY + STATE.md)

_Note: Task 2 carried `tdd="true"`; no Swift test target exists yet (deferred to Phase 3 per the plan's own note), so RED/GREEN was verified via the plan's own shell-level assertions (`grep -c noSleepView` / `grep -c isIdleTimerDisabled`) run before and after implementation, not via a committed test file — see TDD Gate Compliance below._

## Files Created/Modified

- `CarTube/Views/ContentView.swift` — deleted the `dontAskAboutLastPlaying()` call in `playVideo()`
- `CarTube/CarTubeApp.swift` — rewrote `init()` to register the screen-off notification unconditionally (only `showScreenOffWarning()`); deleted `LockScreenDimmingOn` from `registerDefaults()`; deleted the `onOpenURL` `dontAskAboutLastPlaying()` call
- `CarTube/CarPlay/CarPlaySingleton.swift` — deleted `checkIfYouTubePlaying`, `dontAskAboutLastPlaying`, `askAboutLastPlaying`, `saveInitialBrightness`, `setLowBrightness`, `restoreBrightness`, `initialBrightness`/`initialAutoBrightness`; added `applyConfiguration()` facade
- `CarTube/CarPlay/CarPlaySceneDelegate.swift` — slimmed `sceneDidBecomeActive`/`sceneWillResignActive` to the 4-call surviving shape (setCPWindowActive + enablePersistence/disablePersistence)
- `CarTube/Util/Utilities.swift` — deleted `getNowPlaying`, `isScreenLocked`, `getScreenBrightness`, `setScreenBrightness`, `isAutoBrightnessEnabled`, `getSettingsBrightness`, `setAutoBrightness`, `registerForUnlockNotification`, `exitGracefully`, and the `import Dynamic` line
- `CarTube/CarPlay/CarPlayViewController.swift` — extracted `applyConfiguration()`, added `applyConfigurationInPlace()`, deleted `noSleepView`/`timer`/`_hasSleepDisabler` polling, rewrote persistence on `isIdleTimerDisabled`, deleted the `checkIfYouTubePlaying()` call in `viewDidLoad`
- `CarTube/Views/Settings.swift` — deleted the Lock Screen Dimming section and its `@State`; `saveSettings()` calls the apply-in-place facade instead of `exitGracefully()`; reworded the footer

## Decisions Made

- Deleted `registerForUnlockNotification` rather than keeping it (its only caller died with the brightness trio) — this resolves the "planner decision point" flagged in `02-PATTERNS.md`, and is independently corroborated by `scripts/scan-private-apis.sh`'s own header comment (authored in plan 02-02, before this plan ran), which already documents `com.apple.springboard.lockstate` as "removed by plan 02-03." Note: the plan's frontmatter `must_haves.truths` bullet listing `registerForUnlockNotification` among survivors is stale/inconsistent with the plan's own `<action>` and `<verify>` text (which explicitly delete it) — followed the actionable, testable instructions over the stale prose line.
- `NoSleepEnable.js` left on disk as an unreferenced bundle resource per the plan's explicit note — its removal from the bundle is plan 02-04's scope, not this plan's

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Self-inflicted grep-gate trip fixed: comment containing the literal string `exit(0)`**
- **Found during:** Task 3, running the plan's own `grep -rn 'exitGracefully|exit(0)'` verification gate
- **Issue:** A descriptive comment I wrote in Task 2 (`CarPlayViewController.swift`) said "replaces the previous exit(0)-to-apply contract" — the literal substring `exit(0)` tripped Task 3's negative grep gate even though no actual `exit(0)` call exists in the code.
- **Fix:** Reworded the comment to "replaces the previous quit-to-apply contract" — same meaning, no longer matches the gate's pattern.
- **Files modified:** `CarTube/CarPlay/CarPlayViewController.swift`
- **Verification:** `grep -rn 'exitGracefully|exit(0)' --include='*.swift' CarTube/` now returns clean.
- **Committed in:** `9ac0e11` (Task 3 commit)

---

**Total deviations:** 1 auto-fixed (self-inflicted comment wording, not a functional bug)
**Impact on plan:** None on scope — the fix was a comment wording change with zero behavioral impact, discovered and corrected within the same plan execution before commit.

## Issues Encountered

**Known Environment Limitation — simulator build verification incomplete (not a plan defect, same root cause as 02-01/02-02):**

This sandbox's Xcode 26.3 install ships `iphonesimulator` SDK 26.2 (build `23C57`); only the iOS 26.5 (build `23F77`) simulator runtime is installed.

- `xcodebuild -scheme CarTube -destination 'platform=iOS Simulator,name=iPhone Air' build` reports "Unable to find a destination matching the provided destination specifier" — no simulator destinations are eligible at all in scheme mode in this install (even the connected physical device is ineligible: "iOS 26.2 is not installed").
- Target-mode build (`xcodebuild -target CarTube -sdk iphonesimulator build`, bypassing scheme/destination resolution) gets further — `PlayOnCarTube` links successfully — but fails on `CompileAssetCatalogVariant thinned` before the `CarTube` app target's own Swift sources compile, identical to the failure mode 02-01 and 02-02 already documented.

**What WAS verified as strong partial evidence the severance is correct:**
- `scripts/scan-private-apis.sh` (the permanent 15-marker scanner built in plan 02-02) run against every one of the 7 files this plan modified: all 7 scan clean, zero markers found
- Targeted `grep` checks for every symbol in the plan's deleted-symbol list return zero matches across `CarTube/` and `PlayOnCarTube/`
- The surviving-key audit (5 keys × exactly 3 files each) ran cleanly against the real source tree, not a fixture
- `showScreenOffWarning`, `showWarningLabel`, and `registerForScreenOffNotification` confirmed present with their callers intact

**What was NOT verified:** a literal `BUILD SUCCEEDED` and a `strings` scan of the actual compiled `CarTube.app/CarTube` Mach-O binary. Logged to `.planning/WINDOWS.md` (entry 5, `unrun-verify`) — the CI workflow committed in plan 02-02 will run this exact check on a runner with a matching simulator runtime.

## TDD Gate Compliance

Task 2 (`applyConfiguration`/`applyConfigurationInPlace`/idle-timer replacement) carried `tdd="true"`. No Swift `test(...)` commit exists because no XCTest/Swift Testing target exists in this repo yet — the plan's own task text explicitly defers a real test target to Phase 3 and instead specifies shell-verifiable assertions. RED state was confirmed before implementation (`grep -c noSleepView` = 14, `grep -c isIdleTimerDisabled` = 0); GREEN state was confirmed after (`grep -c noSleepView` = 0, `grep -c isIdleTimerDisabled` = 2). This is documented in the Task 2 commit message rather than as separate `test`/`feat` commits, since there is no committable test artifact distinct from the implementation itself.

## Next Phase Readiness

- The Swift-layer severance (INFRA-03) and the exit-to-apply behavioral contract change (INFRA-06) are both complete and committed; plan 02-04 (deployment target raise) can proceed on this baseline
- Once a machine/CI runner with a matching iOS simulator runtime is available, re-run `xcodebuild -scheme CarTube ... build` and `scripts/scan-private-apis.sh` against the real `CarTube.app/CarTube` binary to close out coverage items D1 and D2 (`.planning/WINDOWS.md` entry 5)
- `NoSleepEnable.js` remains an unreferenced bundle resource — no action required this phase; plan 02-04 may choose to remove it from the target's Copy Bundle Resources phase if desired, but its presence is harmless

---
*Phase: 02-severance-signing-modernization*
*Completed: 2026-08-18*

## Self-Check: PASSED

All 7 modified files confirmed present on disk with the expected content; all three task commits (`1f1a048`, `42ef7eb`, `9ac0e11`) confirmed present in `git log`; WINDOWS.md entry 5 confirmed recorded.
