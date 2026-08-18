---
phase: 02-severance-signing-modernization
reviewed: 2026-08-18T11:30:12Z
depth: deep
files_reviewed: 16
files_reviewed_list:
  - .github/workflows/scan.yml
  - AGENTS.md
  - CarTube.xcodeproj/project.pbxproj
  - CarTube.xcodeproj/xcshareddata/xcschemes/CarTube.xcscheme
  - CarTube/CarPlay/CarPlaySceneDelegate.swift
  - CarTube/CarPlay/CarPlaySingleton.swift
  - CarTube/CarPlay/CarPlayViewController.swift
  - CarTube/CarTube.entitlements
  - CarTube/CarTubeApp.swift
  - CarTube/Util/Utilities.swift
  - CarTube/Views/ContentView.swift
  - CarTube/Views/Debug.swift
  - CarTube/Views/Settings.swift
  - docs/runbooks/carplay-entitlement-grant-wiring.md
  - README.md
  - scripts/scan-private-apis.sh
  - scripts/tests/test-scan-private-apis.sh
findings:
  critical: 3
  warning: 7
  info: 3
  total: 13
status: issues_found
---

# Phase 02: Code Review Report

**Reviewed:** 2026-08-18T11:30:12Z
**Depth:** deep
**Files Reviewed:** 16
**Status:** issues_found

## Summary

The private-API/entitlement removal itself (`1f1a048`, `473f91e`) is thorough — I traced every deleted symbol
(`getNowPlaying`, `isScreenLocked`, `getScreenBrightness`/`setScreenBrightness`, `setAutoBrightness`,
`registerForUnlockNotification`, `checkIfYouTubePlaying`, `dontAskAboutLastPlaying`, `saveInitialBrightness`,
`setLowBrightness`, `restoreBrightness`) and found no dangling callers or references anywhere in the tree, and
the `Dynamic` SPM package removal from `project.pbxproj` (`aa9bb3d`) is complete (no leftover
`XCRemoteSwiftPackageReference`/`XCSwiftPackageProductDependency`/`packageReferences` entries). That part of the
"caller-first deletion" claim holds up.

However, three of this phase's headline additions have concrete correctness defects, and the pbxproj hand-edits
introduced a real signing hazard that the CI gate (a simulator-only build) cannot catch:

1. **Settings apply-in-place is incomplete** — the "Screen Persistence Helper" toggle is written to
   `UserDefaults` but never actually applied; only the webview-config settings (zoom/scripts) get pushed through
   `applyConfigurationInPlace()`. The idle-timer state only updates on the next CarPlay scene transition.
2. **The new "HideScrollBar" hook-verification row in Debug.swift is not a real verification** — it compares
   `_UIStaticScrollBar`'s `layoutSubviews` IMP to its superclass's IMP, which will almost certainly differ whether
   or not the swizzle actually installed, because `_UIStaticScrollBar` is a specialized view that already
   overrides `layoutSubviews` on its own. The row can report PASS even when `AutoHookImplementor` silently failed
   to install the hook.
3. **`project.pbxproj` now signs the `CarTube` app target and its embedded `PlayOnCarTube` extension under two
   different Apple Developer Teams** (`57RCRLS3QS`/`K2TYLYAWMK` vs `U67AKNW8PW`), introduced by the same commit
   that reworded the "standard-sign tracer build." This will not surface in the CI workflow (which only builds
   for the iOS Simulator, where strict codesign/team validation is skipped) but will break signing on a real
   device or archive build.

Documentation (`README.md`, `AGENTS.md`) has also drifted out of sync with the very changes this phase made
(iOS-14 support claim survives the iOS-16 floor bump; stale "Settings exits the app" / "Dynamic package" / "lock
screen dimming" descriptions survive the removals).

## Structural Findings (fallow)

None provided for this run.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Settings "Screen Persistence Helper" toggle is written but never applied in-place

**File:** `CarTube/Views/Settings.swift:17-24`, `CarTube/CarPlay/CarPlaySingleton.swift:39-49`, `CarTube/CarPlay/CarPlaySceneDelegate.swift:24-32`
**Issue:** `saveSettings()` writes `ScreenPersistenceOn` to `UserDefaults` and then calls
`CarPlaySingleton.shared.applyConfiguration()`, which only rebuilds the WKWebView configuration
(`applyConfigurationInPlace()` — zoom, SponsorBlock/AdBlocker/AgeRestrictBypass scripts). It never calls
`enablePersistence()`/`disablePersistence()`. Those two methods — the only code paths that actually flip
`UIApplication.shared.isIdleTimerDisabled` — are only invoked from `CarPlaySceneDelegate.sceneDidBecomeActive`/
`sceneWillResignActive`. Before this phase, `saveSettings()` called `exitGracefully()` (`exit(0)`), so the app
relaunched and the scene lifecycle always re-applied the freshly saved value. Now that the process no longer
restarts, a user who flips this toggle while already connected to CarPlay (the common case — this is a
CarPlay-in-use setting) gets no effect until the CarPlay scene happens to resign/reactivate (e.g. switching to
Maps and back, or a cable reconnect). The Settings footer text ("Changes apply immediately to the CarPlay
browser.") is therefore false for this specific toggle.
**Fix:**
```swift
// CarPlaySingleton.swift
func applyConfiguration() {
    controller?.applyConfigurationInPlace()
    if isCPWindowActive {
        // re-evaluate persistence with the freshly written UserDefaults value
        UserDefaults.standard.bool(forKey: "ScreenPersistenceOn") ? enablePersistence() : disablePersistence()
    }
}
```
(or simply call `enablePersistence()`/`disablePersistence()` unconditionally from `saveSettings()` right after the
`UserDefaults` write, mirroring what the scene delegate does.)

### CR-02: "HideScrollBar" hook-verification row cannot distinguish "hook installed" from "class already overrides the method"

**File:** `CarTube/Views/Debug.swift:76-85`
**Issue:** `checkHideScrollBarInstalled()` reports PASS whenever
`_UIStaticScrollBar.layoutSubviews`'s IMP differs from its superclass's IMP. But `_UIStaticScrollBar` is a
specialized UIKit scroll-indicator view; it almost certainly implements its own `layoutSubviews` regardless of
whether `HOOK_UIStaticScrollBar`'s `hook_layoutSubviews` was ever installed by `AutoHookImplementor`
(`CarTube/Hooks/AutoHook/AutoHookImplementor.m`). The check therefore does not verify what the row claims to
verify ("Live runtime status of every surviving hook") — it can silently read PASS on an iOS version where the
swizzle failed (e.g. a type-encoding mismatch, per `AutoHookImplementor.m:111-115`, or the private class dropping
the method), giving false assurance that the hook survived the phase's private-API changes.
**Fix:** Compare against the actual hook implementation instead of the superclass:
```swift
private static func checkHideScrollBarInstalled() -> Bool {
    guard let scrollBarClass = NSClassFromString("_UIStaticScrollBar"),
          let hookClass = NSClassFromString("HOOK_UIStaticScrollBar"),
          let hookMethod = class_getInstanceMethod(hookClass, NSSelectorFromString("hook_layoutSubviews")),
          let currentMethod = class_getInstanceMethod(scrollBarClass, NSSelectorFromString("layoutSubviews"))
    else { return false }
    return method_getImplementation(hookMethod) == method_getImplementation(currentMethod)
}
```

### CR-03: `CarTube` app target and `PlayOnCarTube` extension target sign with mismatched Apple Developer Teams

**File:** `CarTube.xcodeproj/project.pbxproj:541,584,621,648`
**Issue:** Commit `473f91e` ("standard-sign tracer build") changed the `CarTube` target's `DEVELOPMENT_TEAM` to
`57RCRLS3QS` (Debug) and `K2TYLYAWMK` (Release) but left the embedded `PlayOnCarTube` extension target on the
original `U67AKNW8PW` for both configurations. Before that commit all four config slots shared `U67AKNW8PW`. An
app and its embedded extension must be signed/provisioned under the same Apple Developer Team for the "Embed
Foundation Extensions" copy phase to validate on a real device or in an archive/TestFlight build — `git show
473f91e` confirms this asymmetry was introduced deliberately for the app target only, without a matching update
to the extension target. `.github/workflows/scan.yml` only builds for `platform=iOS Simulator`, where strict
codesign/team validation is skipped, so this gate does not catch it, and the phase's own "BUILD SUCCEEDED"
verification claim (simulator-only) does not actually prove the standard-signing story it's meant to prove.
**Fix:** Align `PlayOnCarTube`'s `DEVELOPMENT_TEAM` (both Debug and Release) with whichever team the `CarTube`
app target is meant to ship under, then verify with a device/archive build (not just the simulator destination
used in CI):
```
// 257D149E.../257D149F... (PlayOnCarTube Debug/Release)
DEVELOPMENT_TEAM = K2TYLYAWMK;  // or whatever the CarTube Release team should be, consistently
```

## Warnings

### WR-01: `scan-private-apis.sh` marker list omits the auto-brightness preference key removed alongside the brightness trio

**File:** `scripts/scan-private-apis.sh:35-51`
**Issue:** The deleted `isAutoBrightnessEnabled()` (removed in `1f1a048`) read `CFPreferencesGetAppBooleanValue("BKEnableALS" as CFString, "com.apple.backboardd" as CFString, ...)`. Neither `BKEnableALS` nor
`com.apple.backboardd` appears in `MARKERS`, and — unlike the `com.apple.springboard.lockstate` exclusion, which
is explicitly documented in the header comment with a stated (if debatable) coupling rationale — this omission
is not called out anywhere as an intentional exclusion. A regression that reintroduces only the auto-brightness
read (without also touching `BKSDisplayBrightness*`/`SBGetScreenLockStatus`/`SBSSpringBoardServerPort`, all of
which are separate dlopen'd symbols) would pass the gate silently.
**Fix:** Add `"BKEnableALS"` to `MARKERS` (and optionally document why `com.apple.backboardd` alone is not used,
since it's too generic a bundle-ID string to be a good marker on its own).

### WR-02: 11 of 14 markers in `scan-private-apis.sh` have no positive-match test coverage

**File:** `scripts/tests/test-scan-private-apis.sh:37-87`
**Issue:** The hermetic test suite only exercises `MRMediaRemote`, `BKSDisplayBrightness`, and
`platform-application` as positive (marker-detected) fixtures. `kMRMediaRemoteNowPlayingInfo`,
`_MRNowPlayingClientProtobuf`, `SBGetScreenLockStatus`, `SBSSpringBoardServerPort`, `SBBacklightLevel`,
`PrivateFrameworks/`, `com.apple.private.security.no-container`, `com.apple.private.security.container-manager`,
`com.apple.backboard.displaybrightness`, `SBStarkCapable`, `com.apple.runningboard.assertions.webkit`, and
`com.apple.multitasking.systemappassertions` are never asserted to actually trip the gate. A typo or accidental
deletion of any of those 11 entries in `MARKERS` would not be caught by this test suite.
**Fix:** Add one fixture line per marker (a loop over `MARKERS` driving `run_scan` is simplest) so every entry in
the array is round-tripped through a positive-match test, not just three of them.

### WR-03: `scan-private-apis.sh` matches markers as regex (BRE), not literal strings

**File:** `scripts/scan-private-apis.sh:79-84`
**Issue:** `grep -q -- "$marker"` runs in basic-regex mode. Several markers contain regex metacharacters —
e.g. `com.apple.private.security.no-container` and `com.apple.private.security.container-manager` have `.`
(matches any character) and `-` inside what looks like a literal dotted string. Currently harmless (the `.`
wildcards only make matching *more* permissive, so there's no false-negative risk today), but it means the
script's behavior depends on markers never containing meaningful regex syntax — a future marker with a `[`, `*`,
`+`, or anchor character could silently fail to match or throw a `grep` syntax error.
**Fix:** Use fixed-string matching: `grep -qF -- "$marker" <<< "$SCAN_OUTPUT"`.

### WR-04: `isCPWindowActive` is dead write-only state left behind by the caller-first deletion

**File:** `CarTube/CarPlay/CarPlaySingleton.swift:15,35-37`
**Issue:** `setCPWindowActive(_:)` still exists and is still called from both `CarPlaySceneDelegate` lifecycle
methods, but its sole readers — `setLowBrightness()`, `restoreBrightness()`, and `checkIfYouTubePlaying()`'s
gating — were all deleted in `1f1a048`. `isCPWindowActive` is now written on every scene activation/resignation
and read nowhere. The caller-first deletion pass removed the readers but missed the now-pointless writer/state,
leaving dead code exactly in the file the phase's own "caller-first deletion" work targeted.
**Fix:** Delete `isCPWindowActive`, `setCPWindowActive(_:)`, and its two call sites in
`CarPlaySceneDelegate.swift`, or repurpose it if a near-term Phase 3 feature is known to need it.

### WR-05: README.md still claims "Supports iOS 14.0 - 15.4.1" after the deployment target was raised to iOS 16

**File:** `README.md:1,11`
**Issue:** `aa9bb3d` (this phase) raised `IPHONEOS_DEPLOYMENT_TARGET` to `16.0` across all six build-setting
sites. The app can no longer run on iOS 14.0–15.4.1 devices at all, yet the README's H1 banner and intro
paragraph still advertise that range as supported. This is now a factually false, user-facing claim.
**Fix:** Update both lines to reflect the iOS 16+ floor (or remove the specific-version banner if the intent is
to stop pinning a range in the README).

### WR-06: AGENTS.md documents a codebase that no longer exists (stale relative to this phase's own later commits)

**File:** `AGENTS.md:17,39,42,62-63,65-73,144,198,233-234,239-240,248`
**Issue:** AGENTS.md was regenerated in `473f91e` (02-01) but never refreshed for 02-03/02-04, so it now
contradicts the code it documents in several concrete places:
- `"Dynamic — dynamic Objective-C interop used to decode MediaRemote now-playing protobuf data"` and
  `"Dynamic Swift package, fetched from https://github.com/mhdhejazi/Dynamic"` — the package and all its call
  sites were removed (`1f1a048`, `aa9bb3d`).
- `"Defaults are registered in CarTube/CarTubeApp.swift: ... lock-screen dimming"` — `LockScreenDimmingOn` was
  deleted from `registerDefaults()` in `1f1a048`.
- `"User edits are persisted and the app exits from CarTube/Views/Settings.swift"` and (Architecture section)
  `"The settings screen intentionally exits the process so a new controller can reconstruct WebKit
  configuration."` — this is the exact contract `9ac0e11` replaced with in-place application; both statements
  are now the opposite of current behavior.
- `"init() registers defaults and lock-screen brightness callbacks."` and `"Bridges keyboard, navigation,
  persistence, brightness, and now-playing workflows."` and `"Owns main YouTube WKWebView, hidden NoSleep web
  view, ..."` — brightness/now-playing/NoSleep-webview were all removed.
- `"BackBoardServices, SpringBoardServices, and MediaRemote symbols loaded dynamically in
  CarTube/Util/Utilities.swift"` — that code was deleted.
**Fix:** Regenerate AGENTS.md (or its source `codebase/*.md` docs) from the current tree now that Phase 2 is
otherwise complete, so the next contributor/agent isn't oriented by a description of the pre-severance app.

### WR-07: Force-unwrap on attacker/caller-controlled URL string in the refactored file

**File:** `CarTube/CarPlay/CarPlayViewController.swift:279-284`
**Issue:** `loadUrl(_:)` does `let youtubeURL = URL(string: urlString)!`. `URL(string:)` returns `nil` for a
string containing characters that aren't valid in a URL (e.g. raw spaces, control characters); this path is
reachable from `CarPlaySingleton.searchVideo` (adds percent-encoding first, so safe) but also directly from
`CarTubeApp`'s `onOpenURL` handler and the share-extension flow via `CarPlaySingleton.loadUrl`, both of which
build the string as `YT_EMBED + id`/`YT_EMBED + urlID` from externally supplied input. A future change to
`extractYouTubeVideoID` or the share extension that lets an unencoded/invalid character slip into `id` will crash
the CarPlay scene via this force-unwrap rather than failing gracefully. AGENTS.md's own Conventions section
already flags "Guard optional URLs instead of force-unwrapping" as outstanding tech debt for this exact file.
**Fix:**
```swift
func loadUrl(_ urlString: String) {
    guard let youtubeURL = URL(string: urlString) else { return }
    webView.load(URLRequest(url: youtubeURL))
}
```

## Info

### IN-01: Confusingly duplicate method name across `CarPlaySingleton` and `CarPlayViewController`

**File:** `CarTube/CarPlay/CarPlaySingleton.swift:80-82`, `CarTube/CarPlay/CarPlayViewController.swift:20-59`
**Issue:** `CarPlaySingleton.applyConfiguration()` is a `Void`-returning facade that triggers a full webview
teardown/rebuild (`controller?.applyConfigurationInPlace()`), while `CarPlayViewController.applyConfiguration()`
is a pure builder that *returns* a `WKWebViewConfiguration` and has no side effects. Same name, same file family,
different signature and very different semantics (one is idempotent/pure, the other tears down the live
webview) — easy to call the wrong one, and easy to misread which one a call site is invoking when grepping.
**Fix:** Rename the singleton facade to something like `reapplySettings()` or keep it, but rename the
view-controller builder to `buildWebViewConfiguration()` to remove the collision.

### IN-02: Orphaned `UniformTypeIdentifiers.framework` reference in project.pbxproj

**File:** `CarTube.xcodeproj/project.pbxproj:72,189`
**Issue:** The `UniformTypeIdentifiers.framework` `PBXFileReference` exists in the `Frameworks` group but has no
corresponding `PBXBuildFile` entry and is not listed in either target's `PBXFrameworksBuildPhase.files` — it is
visible in Xcode's navigator but not actually linked into any target. Pre-dates this phase (present since commit
`4d337f3`), but it's a dangling reference in the exact file this phase's plans instruct hand-editing carefully.
**Fix:** Either link it into the `PlayOnCarTube` (or `CarTube`) target's Frameworks phase if it's actually needed
for `UniformTypeIdentifiers` usage in the share extension, or delete the stale reference.

### IN-03: `onOpenURL` scheme-stripping regex makes the wrong character optional

**File:** `CarTube/CarTubeApp.swift:23`
**Issue:** `url.absoluteString.replacingOccurrences(of: "^cartube?://", with: "", options: .regularExpression)`
— the `?` quantifies the preceding `e`, not a literal question mark, so the pattern matches `cartub://` just as
readily as `cartube://`. It happens to still correctly strip the real `cartube://` scheme, so there's no observed
functional break today, but the pattern doesn't express the intended match and would silently accept a malformed
`cartub://<id>` URL as if it were valid.
**Fix:** `"^cartube://"` (drop the `?`), or escape it if an optional character was genuinely intended.

## Fixes Applied (orchestrator, post-review)

User decision: fix the 2 confirmed critical bugs now; leave CR-02, all Warnings, and all Info findings as tracked follow-up.

- **CR-01 fixed** (`d45b686`): `CarPlaySingleton.applyConfiguration()` now also calls `controller?.enablePersistence()` / `controller?.disablePersistence()` based on the current `ScreenPersistenceOn` value, immediately after `applyConfigurationInPlace()`. Rebuilt and re-verified `BUILD SUCCEEDED` + `scan-private-apis.sh` clean on both binaries. Behavioral confirmation is limited to the same environment constraint plan 02-04's checkpoint already accepted: `controller` is only non-nil when a live CarPlay scene is connected, and no CarPlay entitlement/scene is available in this sandbox — the fix is architecturally verified (mirrors the exact gating `CarPlaySceneDelegate` already uses) but not end-to-end simulator-observed.
- **CR-03 fixed** (`e615e7f`): all 4 build configs (CarTube Debug/Release, PlayOnCarTube Debug/Release) now consistently use `com.cartube.carplay` / `com.cartube.carplay.playon` bundle IDs and `DEVELOPMENT_TEAM = K2TYLYAWMK` — verified against `.planning/STATE.md`'s record that K2TYLYAWMK is the user's actual (paid) Apple Developer team, not the stale `U67AKNW8PW` upstream value or the unexplained `57RCRLS3QS`. Rebuilt clean.
- **CR-02 (HideScrollBar false-PASS) — not fixed**, tracked as open follow-up.
- **Warnings/Info (WR-01…WR-07, IN-01…IN-03) — not fixed**, tracked as open follow-up.

Updated counts after this pass: 1 critical (CR-02) + 7 warning + 3 info = 11 open findings (2 critical resolved).

---

_Reviewed: 2026-08-18T11:30:12Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_
_Fixes applied: 2026-08-18 (orchestrator, CR-01 + CR-03)_
