# Technology Stack

**Analysis Date:** 2026-08-17

## Languages and Runtimes

**Primary Languages:**
- Swift 5 — SwiftUI app scenes/views and UIKit/WebKit CarPlay controller (`CarTube/CarTubeApp.swift`, `CarTube/Views/*.swift`, `CarTube/CarPlay/*.swift`)
- Objective-C — UIKit runtime method hooks and private API declarations (`CarTube/Hooks/*.m`, `CarTube/Headers/*.h`)
- JavaScript — browser-side layout, ad blocking, age restriction bypass, SponsorBlock, and wake-lock behavior (`CarTube/Scripts/*.js`)

**Runtime:**
- iOS application targeting iOS 16 minimum (Phase 2 baseline; deployment-target bump lands in plan 02-04)
- Product is built for standard App Store / TestFlight distribution with Automatic code signing (`README.md`)
- Main app targets iPhone (`TARGETED_DEVICE_FAMILY = 1`); share extension targets iPhone/iPad (`TARGETED_DEVICE_FAMILY = "1,2"`)

## Frameworks

**Apple Frameworks:**
- SwiftUI — phone UI, app entry scene, settings, keyboard, and embedded splash (`CarTube/CarTubeApp.swift`, `CarTube/Views/`)
- UIKit — CarPlay window scene, view controller ownership, alerts, gestures, keyboard hosting (`CarTube/CarPlay/`, `CarTube/Extensions/Alert++.swift`)
- WebKit — YouTube presentation and user-script injection (`CarTube/CarPlay/CarPlayViewController.swift`)
- AVFoundation — CarPlay external-device detection (`CarTube/CarPlay/CarPlaySingleton.swift`)
- Social and UniformTypeIdentifiers — share extension input (`PlayOnCarTube/ShareViewController.swift`)
- Foundation and CoreFoundation — URL handling, preferences, notifications, bundle APIs (`CarTube/Util/Utilities.swift`)

**Third-party Swift Package:**
- Dynamic — dynamic Objective-C interop used to decode MediaRemote now-playing protobuf data (`CarTube/Util/Utilities.swift`, `CarTube.xcodeproj/project.pbxproj`)

## Build System

**Project:**
- Xcode project: `CarTube.xcodeproj/project.pbxproj`
- Targets: `CarTube` main app and `PlayOnCarTube` share extension
- Swift bridging header: `CarTube/CarTube-Bridging-Header.h`

**Standard Xcode build:**
```bash
xcodebuild -project CarTube.xcodeproj -scheme CarTube build
```

**Standard signing (App Store / TestFlight):**
- `CODE_SIGN_STYLE = Automatic` on all target build configurations.
- `CarTube/CarTube.entitlements` is retained as an empty plist dict — no private entitlement keys — reserved for the future CarPlay entitlement key once Apple grants it (Phase 1 application).
- No separate packaging script; standard `xcodebuild`/Xcode archive and upload flow.

## Configuration

**Main App:**
- Bundle identifier: `com.avangelista.CarTube`
- URL scheme: `cartube://` (`CarTube/Info.plist`)
- CarPlay scene delegate: `$(PRODUCT_MODULE_NAME).CarPlaySceneDelegate` (`CarTube/Info.plist`)
- Entitlements file retained for the future CarPlay entitlement key (emptied in Phase 2)

**Share Extension:**
- Bundle identifier: `com.avangelista.CarTube.PlayOnCarTube`
- Activation rule accepts extension items whose attachments all conform to `public.url` (`PlayOnCarTube/Info.plist`)

**Runtime Settings:**
- Stored in `UserDefaults.standard`
- Defaults are registered in `CarTube/CarTubeApp.swift`: SponsorBlock, age restriction bypass, ad blocker, zoom, screen persistence, lock-screen dimming
- User edits are persisted and the app exits from `CarTube/Views/Settings.swift`

## Dependencies

**Managed by Xcode:**
- Dynamic Swift package, fetched from `https://github.com/mhdhejazi/Dynamic`

**Vendored/embedded source:**
- AutoHook runtime swizzling implementation (`CarTube/Hooks/AutoHook/AutoHookImplementor.m`)
- NoSleep.js behavior embedded through `CarTube/Scripts/NoSleepEnable.js`
- Ad blocking, age restriction bypass, SponsorBlock, and custom layout scripts bundled as app resources (`CarTube/Scripts/`)

**Operating-system private dependencies:**
- BackBoardServices, SpringBoardServices, and MediaRemote symbols loaded dynamically in `CarTube/Util/Utilities.swift`
- Private UIKit classes/methods declared in `CarTube/Headers/` and `CarTube/Hooks/Headers/`
- Private AVExternalDevice interface declared in `CarTube/Headers/AVExternalDevice.h`

---

*Stack analysis: 2026-08-17*
