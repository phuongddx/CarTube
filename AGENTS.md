<!-- GSD:project-start source:PROJECT.md -->

## Project

**CarTube**

CarTube is an iOS app that plays YouTube videos on CarPlay screens by rendering the YouTube mobile web inside a CarPlay-scene `WKWebView`, enhanced with injected JavaScript (ad blocking, SponsorBlock, age-restriction bypass, custom layout). The phone app is a launcher and settings editor; a share extension opens videos via the `cartube://` scheme. This milestone modernizes the app for App Store distribution and adds driver-friendly voice search.

**Core Value:** A driver can open any YouTube video on their car screen — by voice, search, or share — with ads and sponsors skipped automatically.

### Constraints

- **App Review**: Webview video on CarPlay + remaining private APIs carry a high rejection risk — user accepted this risk explicitly; goal is TestFlight-ready, not guaranteed approval
- **CarPlay entitlement**: Apple application process required; timeline outside our control
- **YouTube Data API**: Requires a Google developer key; current model (2026-06 docs) is a dedicated bucket of 100 `search.list` calls/day at 1 unit each, shared across ALL installs; quota extension requires an API Compliance Audit the ad-block scripts would fail
- **Tech stack**: Keep SwiftUI/UIKit/WebKit hybrid; no rewrite of the phone shell
- **Behavioral contracts**: Settings "exit to apply" and single-cached-video model retained unless a phase explicitly changes them

<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->

## Technology Stack

## Languages and Runtimes

- Swift 5 — SwiftUI app scenes/views and UIKit/WebKit CarPlay controller (`CarTube/CarTubeApp.swift`, `CarTube/Views/*.swift`, `CarTube/CarPlay/*.swift`)
- Objective-C — UIKit runtime method hooks and private API declarations (`CarTube/Hooks/*.m`, `CarTube/Headers/*.h`)
- JavaScript — browser-side layout, ad blocking, age restriction bypass, SponsorBlock, and wake-lock behavior (`CarTube/Scripts/*.js`)
- iOS application targeting iOS 16 minimum (Phase 2 baseline; deployment-target bump lands in plan 02-04)
- Product is built for standard App Store / TestFlight distribution with Automatic code signing (`README.md`)
- Main app targets iPhone (`TARGETED_DEVICE_FAMILY = 1`); share extension targets iPhone/iPad (`TARGETED_DEVICE_FAMILY = "1,2"`)

## Frameworks

- SwiftUI — phone UI, app entry scene, settings, keyboard, and embedded splash (`CarTube/CarTubeApp.swift`, `CarTube/Views/`)
- UIKit — CarPlay window scene, view controller ownership, alerts, gestures, keyboard hosting (`CarTube/CarPlay/`, `CarTube/Extensions/Alert++.swift`)
- WebKit — YouTube presentation and user-script injection (`CarTube/CarPlay/CarPlayViewController.swift`)
- AVFoundation — CarPlay external-device detection (`CarTube/CarPlay/CarPlaySingleton.swift`)
- Social and UniformTypeIdentifiers — share extension input (`PlayOnCarTube/ShareViewController.swift`)
- Foundation and CoreFoundation — URL handling, preferences, notifications, bundle APIs (`CarTube/Util/Utilities.swift`)
- Dynamic — dynamic Objective-C interop used to decode MediaRemote now-playing protobuf data (`CarTube/Util/Utilities.swift`, `CarTube.xcodeproj/project.pbxproj`)

## Build System

- Xcode project: `CarTube.xcodeproj/project.pbxproj`
- Targets: `CarTube` main app and `PlayOnCarTube` share extension
- Swift bridging header: `CarTube/CarTube-Bridging-Header.h`
- `CODE_SIGN_STYLE = Automatic` on all target build configurations.
- `CarTube/CarTube.entitlements` is retained as an empty plist dict — no private entitlement keys — reserved for the future CarPlay entitlement key once Apple grants it (Phase 1 application).
- No separate packaging script; standard `xcodebuild`/Xcode archive and upload flow.

## Configuration

- Bundle identifier: `com.avangelista.CarTube`
- URL scheme: `cartube://` (`CarTube/Info.plist`)
- CarPlay scene delegate: `$(PRODUCT_MODULE_NAME).CarPlaySceneDelegate` (`CarTube/Info.plist`)
- Entitlements file retained for the future CarPlay entitlement key (emptied in Phase 2)
- Bundle identifier: `com.avangelista.CarTube.PlayOnCarTube`
- Activation rule accepts extension items whose attachments all conform to `public.url` (`PlayOnCarTube/Info.plist`)
- Stored in `UserDefaults.standard`
- Defaults are registered in `CarTube/CarTubeApp.swift`: SponsorBlock, age restriction bypass, ad blocker, zoom, screen persistence, lock-screen dimming
- User edits are persisted and the app exits from `CarTube/Views/Settings.swift`

## Dependencies

- Dynamic Swift package, fetched from `https://github.com/mhdhejazi/Dynamic`
- AutoHook runtime swizzling implementation (`CarTube/Hooks/AutoHook/AutoHookImplementor.m`)
- NoSleep.js behavior embedded through `CarTube/Scripts/NoSleepEnable.js`
- Ad blocking, age restriction bypass, SponsorBlock, and custom layout scripts bundled as app resources (`CarTube/Scripts/`)
- BackBoardServices, SpringBoardServices, and MediaRemote symbols loaded dynamically in `CarTube/Util/Utilities.swift`
- Private UIKit classes/methods declared in `CarTube/Headers/` and `CarTube/Hooks/Headers/`
- Private AVExternalDevice interface declared in `CarTube/Headers/AVExternalDevice.h`

<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->

## Conventions

## General Style

- Swift uses four-space indentation and conventional PascalCase types, camelCase members, and SCREAMING_SNAKE_CASE global constants.
- Objective-C uses two- or four-space indentation depending on the original vendored file; keep each existing file internally consistent.
- JavaScript is largely vendored third-party code. Preserve its existing style unless replacing a script deliberately.
- Files contain a header comment with the file/module name and original author where already established.
- There is no SwiftFormat, SwiftLint, Prettier, EditorConfig, or formatting CI configuration.
- SwiftUI chains are often kept on one line, especially in older views.
- Match nearby formatting rather than reformatting entire unrelated files.

## Swift Patterns

- Declare SwiftUI views as structs under `CarTube/Views/`.
- Use private `@State` for local view state.
- Keep small action methods on the view rather than embedding complex closures in button labels (`CarTube/Views/ContentView.swift`).
- Provide `PreviewProvider` stubs for primary views when following existing patterns (`CarTube/Views/ContentView.swift`, `CarTube/Views/Settings.swift`).
- Initialize `@State` directly from `UserDefaults.standard` in `Settings`.
- Write all edited defaults in one `saveSettings()` action (`CarTube/Views/Settings.swift`).
- Register defaults at app startup (`CarTube/CarTubeApp.swift`).
- Avoid introducing a second persistence mechanism unless the process-exit settings contract changes.
- Cross-surface commands route through `CarPlaySingleton.shared` rather than views directly retaining `CarPlayViewController`.
- Keep `CarPlayViewController` ownership private to `CarPlaySingleton`.
- Use `controller == nil` caching for requests made before CarPlay UI exists (`CarTube/CarPlay/CarPlaySingleton.swift`).
- `CarPlayViewController` implements WebKit navigation, UI, and script-message delegation directly.
- New popups are forced back into the same web view by returning `nil` from `createWebViewWith` (`CarTube/CarPlay/CarPlayViewController.swift`).
- Embed SwiftUI keyboard/splash content with `UIHostingController` and explicit parent/child containment (`CarTube/CarPlay/CarPlayViewController.swift`).
- Route alerts through `UIApplication.shared.alert` / `confirmAlert` helpers rather than platform-specific SwiftUI state (`CarTube/Extensions/Alert++.swift`).

## Objective-C Hook Patterns

- Declare a hook subclass conforming to `AutoHook`.
- Implement `+targetClasses` with target class names.
- Name replacement selectors with the `hook_` prefix.
- Keep an `original_` selector stub where the swizzled method needs to call through.
- Use `CarTube/Hooks/AutoHook/AutoHookImplementor.m` conventions; do not add another swizzling engine.
- Window safe-area correction: `CarTube/Hooks/AutoResize.m`
- Scroll-bar suppression: `CarTube/Hooks/HideScrollBar.m`
- Place headers under `CarTube/Headers/` when generally exposed to Swift.
- Place UIKit-only declarations under `CarTube/Hooks/Headers/`.
- Expose only methods actually used by the app.

## Web and JavaScript Patterns

- Bundle feature scripts under `CarTube/Scripts/`.
- Load scripts by resource name, not path, with `Bundle.main.path(forResource:ofType:)`.
- Inject feature scripts at `.atDocumentEnd` and `forMainFrameOnly: false` (`CarTube/CarPlay/CarPlayViewController.swift`).
- Generate small dynamic viewport/CSS scripts in Swift only when they derive directly from user settings.
- Communicate JavaScript-to-native through the registered `keyboard` message handler rather than evaluating arbitrary callbacks.

## Naming

- Swift types/files: PascalCase.
- Swift methods/properties: camelCase.
- Global URL constants: SCREAMING_SNAKE_CASE in `CarTube/Util/Constants.swift`.
- Objective-C hook classes: prefixed with `HOOK` or a clear domain name.
- User-default keys: exact PascalCase string literals; update registration, Settings state, and write logic together.

## Error Handling

- User-facing failures commonly show an alert through `UIApplication.shared.alert`.
- Optional user actions use `confirmAlert` with an OK handler.
- URL conversion and regex parsing contain force-unwraps/force-tries.
- WebKit script loading silently skips unavailable resources with `guard ... else { return }`.
- Phase 2 removed the private-API surface; no code should assume private iOS 14–15.4 symbols exist.
- Guard optional URLs instead of force-unwrapping.
- Create the YouTube regex once or use a throwing initializer rather than duplicating `try!`.
- Report failed bundle-script loading in development builds rather than silently returning.
- Keep MediaRemote/Dynamic decode failures on the existing completion-result path.

## Concurrency

- Dispatch alert presentation and updates to `DispatchQueue.main` (`CarTube/Extensions/Alert++.swift`).
- Use main-queue callbacks for MediaRemote data consumed by UI.
- `URLSession.dataTask` callbacks may parse on background queues, but UI work must return to main.
- Avoid retaining `CarPlayViewController` strongly inside long-lived closures; route through the singleton where existing code does.

## Build and Release

- Target the iOS 16 minimum deployment baseline (plan 02-04 raises it from 14.0).
- Standard App Store / TestFlight signing with `CODE_SIGN_STYLE = Automatic`; no sideload re-signing or packaging path remains.
- When changing target membership or adding resources, update `CarTube.xcodeproj/project.pbxproj` carefully and verify both target builds.

<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->

## Architecture

## Overview

## Pattern

- Scene-oriented hybrid SwiftUI/UIKit app
- Facade/singleton for cross-surface communication (`CarPlaySingleton.shared`)
- WebView-as-client over YouTube mobile web
- Runtime method swizzling for private UIKit behavior
- Resource-driven browser enhancement through `WKUserScript`
- CarPlay content is represented as a normal UIKit scene/window rather than CarPlay template APIs.
- iOS-version-specific layout and window behavior is corrected with Objective-C hooks.
- Feature toggles can alter the browser client without rebuilding separate controllers.

## Targets and Layers

- SwiftUI application layer — `CarTube/CarTubeApp.swift`
- Phone presentation layer — `CarTube/Views/*.swift`
- CarPlay scene/window layer — `CarTube/CarPlay/CarPlaySceneDelegate.swift`
- CarPlay presentation/browser layer — `CarTube/CarPlay/CarPlayViewController.swift`
- Cross-surface coordination — `CarTube/CarPlay/CarPlaySingleton.swift`
- System/private interop — `CarTube/Util/Utilities.swift`
- Objective-C hook layer — `CarTube/Hooks/*.m`, `CarTube/Hooks/AutoHook/AutoHookImplementor.m`
- Browser feature scripts — `CarTube/Scripts/*.js`
- Share input translation only — `PlayOnCarTube/ShareViewController.swift`
- Converts shared URL/text into the main app’s `cartube://<videoID>` scheme.

## Entry Points

- `@main struct CarTubeApp` in `CarTube/CarTubeApp.swift`
- `init()` registers defaults and lock-screen brightness callbacks.
- `WindowGroup` presents `ContentView`, handles `cartube://` URLs, and starts update checking.
- `UIApplicationSceneManifest` in `CarTube/Info.plist` selects `CarPlaySceneDelegate`.
- `scene(_:willConnectTo:options:)` creates `UIWindow`, sets `CarPlayViewController`, and makes it visible.
- `NSExtensionPrincipalClass` in `PlayOnCarTube/Info.plist` selects `ShareViewController`.
- `viewWillAppear()` and `didSelectPost()` initiate URL extraction/opening.
- A cached URL is consumed or YouTube home is loaded during `CarPlayViewController.viewDidLoad()`.

## Core Data Flow

```text

```

```text

```

```text

```

```text

```

```text

```

## Key Abstractions

- Holds the optional active `CarPlayViewController`.
- Buffers one requested video before the controller exists.
- Guards feature actions by CarPlay connection/active state.
- Bridges keyboard, navigation, persistence, brightness, and now-playing workflows.
- Owns main YouTube `WKWebView`, hidden NoSleep web view, SwiftUI keyboard host, warning label, and splash host.
- Implements `WKNavigationDelegate`, `WKUIDelegate`, and `WKScriptMessageHandler`.
- Translates custom keyboard input into private WebKit text simulation and `document.execCommand('delete')`.
- Hook classes expose `targetClasses`.
- `AutoHookImplementor` copies/swizzles methods marked `hook_` onto UIKit classes.
- Stateless URL, notification, screen, brightness, and MediaRemote helpers.
- Dynamic private-framework calls are centralized here rather than spread through views.

## Concurrency and Lifecycle

- Network update check uses `URLSession.dataTask` with a completion closure (`CarTube/CarTubeApp.swift`).
- MediaRemote invokes its callback on `DispatchQueue.main` (`CarTube/Util/Utilities.swift`).
- Alerts explicitly dispatch presentation and mutation to the main queue (`CarTube/Extensions/Alert++.swift`).
- UIKit lifecycle methods directly enable/disable persistence and CarPlay active state (`CarTube/CarPlay/CarPlaySceneDelegate.swift`).
- The settings screen intentionally exits the process so a new controller can reconstruct WebKit configuration.

## Extension Points

- Add a browser-only feature as a JavaScript resource and selectively append it in `CarTube/CarPlay/CarPlayViewController.swift`.
- Add a phone-side setting state/write/default in `Settings.swift` and `CarTubeApp.swift`.
- Add private-framework access through a typed declaration in `CarTube/Headers/` or a dynamic loader in `CarTube/Util/Utilities.swift`.
- Add a UIKit behavior correction as an Objective-C `AutoHook` class under `CarTube/Hooks/`.

<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->

## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->

## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:

- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->

## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
