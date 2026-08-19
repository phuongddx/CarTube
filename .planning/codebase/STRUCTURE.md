# Project Structure

**Analysis Date:** 2026-08-17

## Top-Level Layout

```text
CarTube/
├── CarTube.xcodeproj/       # Xcode project, targets, package dependency, build settings
├── CarTube/                 # Main app target
├── PlayOnCarTube/           # Share extension target
├── Icon/                    # Repository icon assets
├── .planning/codebase/      # Generated codebase map
├── ipabuild.sh              # TrollStore IPA packaging script
├── README.md                # Product, compatibility, features, credits
└── license                  # Project license
```

## Main App Structure

```text
CarTube/CarTube/
├── CarTubeApp.swift             # @main app scene, defaults, update check, URL routing
├── CarTube-Bridging-Header.h   # Objective-C declarations exposed to Swift
├── CarTube.entitlements         # TrollStore/platform entitlements
├── Info.plist                   # URL scheme and CarPlay scene manifest
├── CarPlay/
│   ├── CarPlaySceneDelegate.swift
│   ├── CarPlaySingleton.swift
│   ├── CarPlayViewController.swift
│   ├── SearchResultsViewController.swift
│   └── MicButton.swift
├── Search/
│   ├── SearchResult.swift
│   ├── YouTubeSearchService.swift
│   ├── LastQueryCache.swift
│   ├── SearchFallback.swift
│   ├── DurationFormatter.swift
│   └── SearchCoordinator.swift
├── Speech/
│   ├── VoiceSearchAvailability.swift
│   └── SpeechRecognizerService.swift
├── Views/
│   ├── ContentView.swift
│   ├── Debug.swift
│   ├── HowTo.swift
│   ├── Incrementer.swift
│   ├── KeyboardView.swift
│   ├── Settings.swift
│   └── SplashScreen.swift
├── Extensions/
│   ├── Alert++.swift
│   └── String++.swift
├── Util/
│   ├── Constants.swift
│   └── Utilities.swift
├── Hooks/
│   ├── AutoHook/
│   │   ├── AutoHook.h
│   │   └── AutoHookImplementor.m
│   ├── Headers/
│   ├── AutoResize.m
│   └── HideScrollBar.m
├── Headers/
│   ├── AVExternalDevice.h
│   └── WebView+Additions.h
├── Scripts/
│   ├── AdBlocker.js
│   ├── AgeRestrictBypass.js
│   ├── CustomLayout.js
│   ├── NoSleepEnable.js
│   └── SponsorBlock.js
└── Preview Content/
    └── Preview Assets.xcassets/
```

## Share Extension Structure

```text
CarTube/PlayOnCarTube/
├── Info.plist                  # Share extension activation/principal class
└── ShareViewController.swift    # Shared URL/text extraction and cartube:// handoff
```

## Key Locations

**When adding or changing:**
- App lifecycle or custom URL behavior → `CarTube/CarTubeApp.swift`
- Phone launch UI → `CarTube/Views/ContentView.swift`
- Settings/default keys → `CarTube/Views/Settings.swift` and `CarTube/CarTubeApp.swift`
- CarPlay scene lifecycle → `CarTube/CarPlay/CarPlaySceneDelegate.swift`
- Browser setup, scripts, keyboard, gestures, persistence → `CarTube/CarPlay/CarPlayViewController.swift`
- Cross-surface command routing → `CarTube/CarPlay/CarPlaySingleton.swift`
- YouTube Data API search + result funnel → `CarTube/Search/`
- On-device speech recognition + voice-search availability gating → `CarTube/Speech/`
- YouTube URL constants → `CarTube/Util/Constants.swift`
- Private-system or URL helpers → `CarTube/Util/Utilities.swift`
- Alerts and String error conformance → `CarTube/Extensions/`
- UIKit method hooks → `CarTube/Hooks/`
- Private Objective-C headers → `CarTube/Headers/` and `CarTube/Hooks/Headers/`
- Browser behavior scripts → `CarTube/Scripts/`
- Share-sheet handoff → `PlayOnCarTube/ShareViewController.swift`
- Build settings, target membership, bundled resources, package dependency → `CarTube.xcodeproj/project.pbxproj`

## Naming Conventions

- Swift files use PascalCase matching their primary type (`CarPlayViewController.swift`, `KeyboardView.swift`).
- Objective-C hook files describe behavior (`AutoResize.m`, `HideScrollBar.m`).
- JavaScript resources use PascalCase feature names (`SponsorBlock.js`, `CustomLayout.js`).
- Shared project constants use SCREAMING_SNAKE_CASE (`YT_HOME`, `YT_EMBED`, `YT_SEARCH`).
- User-default keys use PascalCase boolean-style names (`SponsorBlockOn`, `ScreenPersistenceOn`).
- Directory names `CarPlay`, `Views`, `Extensions`, `Util`, `Hooks`, `Headers`, and `Scripts` describe target-wide responsibility.

## Adding Files

**Swift app/view/utilities:**
1. Create the file in the matching `CarTube/` subdirectory.
2. Add it to the `CarTube` target in `CarTube.xcodeproj/project.pbxproj`.
3. Keep the type PascalCase and the filename aligned to the type.

**Browser feature script:**
1. Add `CarTube/Scripts/<Feature>.js`.
2. Add it to main-app Resources in `CarTube.xcodeproj/project.pbxproj`.
3. Add a default key and Settings toggle when user-controlled.
4. Append the resource name in `CarPlayViewController.viewDidLoad()` injection setup.

**UIKit hook:**
1. Declare required private interfaces under `CarTube/Hooks/Headers/`.
2. Create an Objective-C hook class under `CarTube/Hooks/`.
3. Conform to `AutoHook`, expose `targetClasses`, and name swizzled methods with the `hook_` prefix.
4. Add the implementation to the main target.

## Generated Planning Artifacts

- Store codebase maps in `.planning/codebase/`.
- Do not place application runtime files under `.planning/`.
- Generated maps should be updated when architecture, stack, testing, integrations, conventions, or concerns materially change.

---

*Structure analysis: 2026-08-17*
