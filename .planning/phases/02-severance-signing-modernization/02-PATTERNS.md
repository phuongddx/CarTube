# Phase 2: Severance, Signing & Modernization - Pattern Map

**Mapped:** 2026-08-18
**Files analyzed:** 12 (10 modified, 1 deleted, 1-2 created)
**Analogs found:** 11 / 12

No `CONTEXT.md` or `RESEARCH.md` exists in this phase directory yet; the file list below is derived from ROADMAP.md Phase 2 success criteria 1-5 and requirements INFRA-02…INFRA-06.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `CarTube/Util/Utilities.swift` (modify: delete functions) | utility | n/a (deletion) | itself — surviving functions | exact (self-edit) |
| `CarTube/CarPlay/CarPlaySingleton.swift` (modify) | service / facade | request-response | itself — `enablePersistence`/`disablePersistence` guard pattern | exact (self-edit) |
| `CarTube/CarPlay/CarPlayViewController.swift` (modify) | controller | lifecycle / transform | itself — `viewDidLoad` config block | exact (self-edit) |
| `CarTube/CarPlay/CarPlaySceneDelegate.swift` (modify) | controller (scene) | event-driven | itself — lifecycle methods | exact (self-edit) |
| `CarTube/CarTubeApp.swift` (modify) | config / entry | event-driven | itself — `registerDefaults()` | exact (self-edit) |
| `CarTube/Views/Settings.swift` (modify: delete toggle, replace `exitGracefully()`) | component | CRUD (UserDefaults) | itself — existing toggle rows | exact (self-edit) |
| `CarTube/Views/ContentView.swift` (modify: remove 1 call) | component | event-driven | itself | exact (self-edit) |
| `CarTube/Views/Debug.swift` (modify: add hook-verification section) | component | request-response | itself — existing Button rows + `Incrementer.swift` binding pattern | exact (self-edit) |
| `CarTube/CarTube.entitlements` (modify: strip private keys) | config | n/a | itself | exact (self-edit) |
| `CarTube.xcodeproj/project.pbxproj` (modify: target 16.0, drop Dynamic SPM) | config | n/a | itself + Phase 1 `01-01-PLAN.md` ruby-xcodeproj mutation recipe | role-match |
| `ipabuild.sh` (DELETE) + `CarTube.entitlements` legacy refs | build script | batch | itself (deletion, no analog needed) | n/a |
| `.github/workflows/scan.yml` + scan script (CREATE, INFRA-05) | config / gate | batch / transform | `ipabuild.sh` shell conventions + Phase 1 `git grep` hygiene gate | partial (no CI YAML exists) |

This phase is dominated by **severance edits to existing files**, so most "analogs" are the target files' own surviving code. The valuable pattern data for the planner is: (a) the verified caller map per deleted symbol, (b) the three-file settings-key contract, (c) the webview-config block that must become reusable for INFRA-06, (d) the Debug-screen row pattern for hook re-validation.

---

## Verified Caller Map (delete-bottom-up: caller first, definition last)

Every symbol Phase 2 removes, with all call sites confirmed by grep (2026-08-18):

**MediaRemote / now-playing (INFRA-03):**

| Symbol | Definition | Callers |
|--------|-----------|---------|
| `getNowPlaying(completion:)` | `Utilities.swift:149-179` | `CarPlaySingleton.swift:131` only |
| `checkIfYouTubePlaying()` | `CarPlaySingleton.swift:129-143` | `CarPlayViewController.swift:27` only |
| `dontAskAboutLastPlaying()` + `askAboutLastPlaying` state | `CarPlaySingleton.swift:13,31-33` | `ContentView.swift:24`, `CarTubeApp.swift:35` |
| `import Dynamic` / `Dynamic._MRNowPlayingClientProtobuf` | `Utilities.swift:11,164` | nowhere else — SPM package ref is `project.pbxproj` lines 37, 110, 299, 351, 722-737 |

**Brightness / lock-screen dimming (INFRA-03; `LockScreenDimmingOn` toggle dies with it):**

| Symbol | Definition | Callers |
|--------|-----------|---------|
| `exitGracefully()` | `Utilities.swift:27-31` | `Settings.swift:25` only (also targeted by INFRA-06) |
| `isScreenLocked()` | `Utilities.swift:61-75` | `CarPlaySceneDelegate.swift:28,38` |
| `getScreenBrightness()` | `Utilities.swift:79-90` | `CarPlaySceneDelegate.swift:29` |
| `setScreenBrightness(_:)` | `Utilities.swift:94-103` | `CarPlaySingleton.swift:56,65` |
| `isAutoBrightnessEnabled()` | `Utilities.swift:108-118` | `CarPlaySingleton.swift:48,53,62` |
| `getSettingsBrightness()` | `Utilities.swift:122-134` | `CarPlaySingleton.swift:47` |
| `setAutoBrightness(_:)` | `Utilities.swift:137-146` | `CarPlaySingleton.swift:54,63` |
| `saveInitialBrightness()` / `setLowBrightness()` / `restoreBrightness()` + `initialBrightness`/`initialAutoBrightness` state | `CarPlaySingleton.swift:11-12,46-66` | `CarTubeApp.swift:16,19,22`; `CarPlaySceneDelegate.swift:32,39` |
| `"LockScreenDimmingOn"` key | `CarTubeApp.swift:15,51`; `Settings.swift:12,24`; `CarPlaySingleton.swift:52,61` | 3-file contract — see Shared Patterns |

**SURVIVES (per ROADMAP success criterion 2):** `showScreenOffWarning()` (`CarPlaySingleton.swift:81-83`) → `showWarningLabel()` (`CarPlayViewController.swift:236-244`); `registerForScreenOffNotification` (`Utilities.swift:35-44`) and `registerForUnlockNotification` (`Utilities.swift:48-58`) use the public `notify_register_dispatch` API, not `dlsym` — the screen-off warning label's surviving trigger path is `CarTubeApp.swift:17-20`. Planner decision point: keep the notify functions + `CarPlayApp.swift:17-20` registration minus the `setLowBrightness`/`restoreBrightness` lines, or drop the whole init block if the scene-delegate path is chosen instead; either way `showWarningLabel` must remain reachable.

---

## Pattern Assignments

### `CarTube/Views/Settings.swift` (component, CRUD — toggle removal + INFRA-06)

**Analog:** itself — the `LockScreenDimmingOn` row is the deletion template; sibling rows are the survivors to match.

Toggle row being removed (`Settings.swift:58-61`):
```swift
Section(footer: Text("RECOMMENDED.\nDim the Lock Screen while the app is running.")) {
    Toggle(isOn: $lockScreenDimmingOn) {
        Text("Lock Screen Dimming")
    }
}
```

Apply-button contract being replaced (`Settings.swift:17-26`) — `exitGracefully()` becomes the in-place config-recreation call; footer "The app will quit." (`Settings.swift:31-33`) must be reworded:
```swift
func saveSettings() {
    UserDefaults.standard.set(sponsorBlockOn, forKey: "SponsorBlockOn")
    UserDefaults.standard.set(ageRestrictBypassOn, forKey: "AgeRestrictBypassOn")
    UserDefaults.standard.set(adBlockerOn, forKey: "AdBlockerOn")
    UserDefaults.standard.set(zoom, forKey: "Zoom")
    UserDefaults.standard.set(screenPersistenceOn, forKey: "ScreenPersistenceOn")
    UserDefaults.standard.set(lockScreenDimmingOn, forKey: "LockScreenDimmingOn")   // delete
    exitGracefully()                                                                 // replace
}
```

Keep the existing structure verbatim for surviving keys: `@State` init from `UserDefaults.standard.bool/integer(forKey:)` at `Settings.swift:11-16`, single `saveSettings()` writer, `PreviewProvider` stub at `Settings.swift:69-73`.

### `CarTube/CarPlay/CarPlayViewController.swift` (controller, lifecycle — INFRA-06 in-place reconfiguration)

**Analog:** itself — `viewDidLoad` lines 28-73 are the configuration construction that must be extracted into a reusable method (e.g. `applyConfiguration()`), because settings must now take effect without process death.

Config construction to extract (`CarPlayViewController.swift:31-73`):
```swift
let sponsorBlockOn = UserDefaults.standard.bool(forKey: "SponsorBlockOn")
let ageRestrictBypassOn = UserDefaults.standard.bool(forKey: "AgeRestrictBypassOn")
let adBlockerOn = UserDefaults.standard.bool(forKey: "AdBlockerOn")
let webConfiguration = WKWebViewConfiguration()
var enabledScripts: [String] = []
if sponsorBlockOn {
    enabledScripts.append("SponsorBlock")
}
// ... zoomScript (lines 56-59), message handler + media flags (lines 60-69)
```

Script-resource loading convention to preserve (`CarPlayViewController.swift:52-56`) — load by resource name, `.atDocumentEnd`, `forMainFrameOnly: false`:
```swift
enabledScripts.forEach { item in
    guard let scriptPath = Bundle.main.path(forResource: item, ofType: "js"),
          let scriptSource = try? String(contentsOfFile: scriptPath) else { return }
    let userScript = WKUserScript(source: scriptSource, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
    webConfiguration.userContentController.addUserScript(userScript)
}
```

Recreation should follow the existing child-view containment pattern (`CarPlayViewController.swift:110-117`) and frame management (`toggleKeyboard`, lines 275-283) rather than re-adding subviews unconditionally. Deletion in this file is exactly one line: `CarPlaySingleton.shared.checkIfYouTubePlaying()` (`CarPlayViewController.swift:27`).

The private WebKit calls `_simulateTextEntered` (`CarPlayViewController.swift:249`), `_hasSleepDisabler` (lines 226-227) are **out of Phase 2's removal scope** (only MediaRemote + BackBoard/SpringBoard are named) but are `strings`-scan subjects — the gate's marker list must be chosen so the surviving keyboard/NoSleep features don't fail their own gate (planner decision; see INFRA-05 note below).

### `CarTube/CarPlay/CarPlaySingleton.swift` (service/facade, request-response)

**Analog:** itself — the persistence pair is the pattern for every feature that survives severance: read the UserDefaults gate, optional-chain to the controller.

Surviving conditional-command pattern (`CarPlaySingleton.swift:68-78`):
```swift
func disablePersistence() {
    if UserDefaults.standard.bool(forKey: "ScreenPersistenceOn") {
        self.controller?.disablePersistence()
    }
}
```

Deletions: `checkIfYouTubePlaying` (lines 129-143), `dontAskAboutLastPlaying` (31-33), brightness trio (46-66), `initialBrightness`/`initialAutoBrightness` (11-12), `askAboutLastPlaying` (13). Keep `showScreenOffWarning` (81-83). INFRA-06's "apply in place" lands here as the natural facade method (phone Settings → singleton → controller), mirroring how `sendInput`/`goHome` already route (lines 85-105).

### `CarTube/CarPlay/CarPlaySceneDelegate.swift` (controller, event-driven)

**Analog:** itself — the lifecycle methods slim down to the persistence + window-active calls.

Target end-state for `sceneDidBecomeActive` (`CarPlaySceneDelegate.swift:26-35`) is exactly the surviving shape:
```swift
func sceneDidBecomeActive(_ scene: UIScene) {
    CarPlaySingleton.shared.setCPWindowActive(true)
    CarPlaySingleton.shared.enablePersistence()
}
```
`sceneWillResignActive` (lines 37-44) keeps lines 42-43, drops the `isScreenLocked`/`restoreBrightness` block (38-40).

### `CarTube/CarTubeApp.swift` (config/entry, event-driven)

**Analog:** itself — `registerDefaults()` (lines 44-52) is where the `"LockScreenDimmingOn": true` registration dies. The init block lines 15-23 is removed or reduced to the surviving notify-registration (see caller-map decision point). `dontAskAboutLastPlaying()` call at line 35 is deleted. Note for INFRA-04: with iOS 16 as the floor, the legacy `.onChange(of: scenePhase) { newPhase in }` single-parameter form used in `ContentView.swift:82` still compiles (deprecated only in iOS 17) — migration is optional here, mandatory shape change if the floor ever goes to 17.

### `CarTube/Views/ContentView.swift` (component, event-driven)

**Analog:** itself. Single deletion: `CarPlaySingleton.shared.dontAskAboutLastPlaying()` (`ContentView.swift:24`). Everything else in `playVideo()` (lines 21-29) — the `extractYouTubeVideoID` → `YT_EMBED` → `CarPlaySingleton.shared.loadUrl` chain and the invalid-link alert — is the canonical phone→CarPlay command path to leave untouched.

### `CarTube/Views/Debug.swift` (component, request-response — INFRA-04 hook re-validation)

**Analog:** itself — extend the existing Form with the hook-verification section; every row follows this routing pattern (`Debug.swift:14-24`):
```swift
Section {
    Button("Go Back in Browser") {
        CarPlaySingleton.shared.goBack()
    }
    Button("Go Home in Browser") {
        CarPlaySingleton.shared.goHome()
    }
    Button("Toggle CarPlay Keyboard") {
        CarPlaySingleton.shared.toggleKeyboard()
    }
}
```
New rows should keep: `Form { List { Section { Button } } }` nesting, `.navigationBarTitle("Debug", displayMode: .inline)` (line 27), actions routed through `CarPlaySingleton.shared` (never retaining `CarPlayViewController`), `PreviewProvider` stub (lines 30-34). State-bearing rows (e.g. a toggle forcing a script on for re-validation) follow the `@Binding` pattern of `Incrementer.swift:11-33` (`@Binding var value: Int` + `Button(action:)` + `BorderlessButtonStyle()`).

### `CarTube/CarTube.entitlements` (config)

**Analog:** itself. Private keys to delete: `com.apple.backboard.displaybrightness`, `platform-application`, `com.apple.private.security.no-container`, `com.apple.private.security.container-manager`. **Planner decision point:** `SBStarkCapable`, `com.apple.runningboard.assertions.webkit`, `com.apple.multitasking.systemappassertions` are also non-App-Store keys but are the load-bearing entitlements for the *surviving* Screen Persistence / NoSleep feature (`CarPlayViewController.swift:99-109`); INFRA-02 says "no private entitlement keys" remain, which conflicts with keeping NoSleep on entitlements — the plan must either empty the file to `<?xml …><plist…><dict/>` and accept NoSleep degradation, or scope the gate's marker list. Map this decision explicitly.

### `CarTube.xcodeproj/project.pbxproj` (config)

**Analog:** itself + Phase 1 `01-01-PLAN.md` (ruby `xcodeproj` gem mutation recipe, steps 74-79).

Exact edit sites (verified by grep):
- `IPHONEOS_DEPLOYMENT_TARGET = 14.0;` → `16.0;` at 6 locations: lines 484, 540 (project-level), 574, 617 (CarTube target Debug/Release), 646, 673 (PlayOnCarTube Debug/Release)
- Dynamic SPM removal: `PBXBuildFile` line 37, `Frameworks` phase line 110, `PBXPackageProductDependency` line 299, `XCRemoteSwiftPackageReference` lines 351 + 722-724, `XCSwiftPackageProductDependency` lines 733-737 — remove all five object types or the project file is corrupt
- `CODE_SIGN_ENTITLEMENTS = CarTube/CarTube.entitlements;` at lines 465, 527, 557, 600 — drop only if the entitlements file is emptied/deleted
- Standard signing is already configured: `CODE_SIGN_STYLE = Automatic` + `DEVELOPMENT_TEAM = U67AKNW8PW` on all four target configs (lines 558/561, 601/604, 639/641, 666/668) — INFRA-02 needs no signing-setting change, only the entitlements/ldid pipeline removal
- Deleting `ipabuild.sh` requires no pbxproj change (it is not referenced there)

### CI scan gate (CREATE: `.github/workflows/*.yml` + script — INFRA-05)

**Analog (shell conventions):** `ipabuild.sh` — adopt `set -e`, `cd "$(dirname "$0")"`, derived-path handling (`ipabuild.sh` lines 1-10). Build invocation shape from `ipabuild.sh` lines 19-27 (`xcodebuild -project … -scheme CarTube … -derivedDataPath`), but for CI use the Phase 1 recipe from `01-01-PLAN.md` step 74: copy `Config/Secrets.xcconfig.example` → `Secrets.xcconfig`, pass `YOUTUBE_API_KEY=...` as a command-line override so the real key never touches disk.

**Analog (gate-exit-code convention):** Phase 1 `01-01-PLAN.md` acceptance criteria use `git grep -nE '<pattern>'` exiting 1 as the pass condition (`01-01-PLAN.md` lines 88, 92). The `strings` gate is the binary-scanning counterpart: build app + share extension, then fail if `strings` output on both binaries (`CarTube.app/CarTube` and `CarTube.app/PlugIns/PlayOnCarTube.appex/PlayOnCarTube`) matches private-API markers. Marker list must be derived from the *removed* symbols (`MRMediaRemote…`, `BKSDisplayBrightness…`, `SBGetScreenLockStatus`, `SBSSpringBoardServerPort`, `SBBacklightLevel…`, `_MRNowPlayingClientProtobuf`) — NOT from the surviving private WebKit calls, or the build fails on its own retained features.

**No YAML analog exists** — the repo has no `.github/workflows/` directory (verified: repo root contains only `build/ CarTube CarTube.xcodeproj Icon PlayOnCarTube ipabuild.sh license README.md` + dotfiles). Planner should use a minimal single-job workflow; no in-repo precedent to copy.

---

## Shared Patterns

### Settings-key contract (applies to every key touched — INFRA-03/04)
Every `UserDefaults` key lives in exactly three places that must be updated together (CONVENTIONS.md "Naming"):
```swift
// 1. Registration — CarTube/CarTubeApp.swift:44-52
UserDefaults.standard.register(defaults: [
    "SponsorBlockOn": false,
    ...
    "LockScreenDimmingOn": true        // ← deleted this phase
])

// 2. Read/state + write — CarTube/Views/Settings.swift:12,24
@State private var lockScreenDimmingOn = UserDefaults.standard.bool(forKey: "LockScreenDimmingOn")
UserDefaults.standard.set(lockScreenDimmingOn, forKey: "LockScreenDimmingOn")

// 3. Consumption — CarTube/CarPlay/CarPlaySingleton.swift:52 / CarPlayViewController.swift:32-34
if UserDefaults.standard.bool(forKey: "LockScreenDimmingOn"), isCPWindowActive {
```
For `LockScreenDimmingOn`, all three sites are deleted. Surviving keys (`SponsorBlockOn`, `AgeRestrictBypassOn`, `AdBlockerOn`, `Zoom`, `ScreenPersistenceOn`) keep all three sites — a grep for each surviving key must still return 3 files after the phase.

### Cross-surface command routing (applies to Settings apply-in-place and Debug rows)
Views never retain `CarPlayViewController`; everything goes through the singleton facade, with `controller == nil` caching for pre-UI requests (`CarPlaySingleton.swift:21-28`):
```swift
func loadUrl(_ urlString: String) {
    if AVExternalDevice.currentCarPlay() == nil {
        UIApplication.shared.alert(body: "CarPlay not connected.", window: .main)
    } else if controller == nil {
        self.cachedVideo = urlString
    } else {
        controller?.loadUrl(urlString)
    }
}
```

### User-facing errors (applies to Debug screen and any new alerts)
Route through `UIApplication.shared.alert` / `confirmAlert`, never SwiftUI state (`Alert++.swift:23-43`), always dispatched to main.

### Objective-C hooks (validation-only this phase; do not modify)
Hook classes stay byte-identical; INFRA-04 only *re-validates* them at iOS 16 via the Debug screen. Reference shape (`AutoResize.m:12-29`): `HOOK*` subclass conforming to `AutoHook`, `+targetClasses`, `hook_`/`original_` selector pairs. `AutoHookImplementor.m:13` `+load` is the automatic entry point — no registration list to update when Swift code changes.

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `.github/workflows/*.yml` (CI workflow file) | config / gate | batch | No CI configuration exists anywhere in the repo; nearest conventions are `ipabuild.sh` (shell) and Phase 1's grep-based acceptance gates (planning artifact, not code) |
| GitHub Actions YAML syntax / runner setup | config | batch | Nothing in-repo; use platform-default minimal workflow (checkout + `xcodebuild` + strings scan) |

Everything else in the phase is a modification of a file whose own surviving code is the analog.

## Metadata

**Analog search scope:** `CarTube/` (all Swift/Obj-C/headers/plists), `CarTube.xcodeproj/project.pbxproj`, `PlayOnCarTube/`, repo root (scripts, .gitignore), `.planning/phases/01-*` (gate conventions), `.planning/codebase/*` (CONVENTIONS/CONCERNS)
**Files scanned:** 20 source/config files + 2 planning artifacts; grep across all `.swift/.m/.h`
**Pattern extraction date:** 2026-08-18
