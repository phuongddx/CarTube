# Architecture

**Analysis Date:** 2026-08-17

## Overview

CarTube is a two-target iOS app: a SwiftUI phone shell plus a UIKit/WebKit CarPlay surface, accompanied by a share extension. The phone app is primarily a launcher and settings editor. Actual playback happens in a CarPlay-scene `WKWebView`, adapted through injected JavaScript and UIKit runtime hooks. A process-wide singleton bridges phone UI, URL events, scene lifecycle, and the CarPlay controller.

## Pattern

**Architecture style:**
- Scene-oriented hybrid SwiftUI/UIKit app
- Facade/singleton for cross-surface communication (`CarPlaySingleton.shared`)
- WebView-as-client over YouTube mobile web
- Runtime method swizzling for private UIKit behavior
- Resource-driven browser enhancement through `WKUserScript`

**Why this shape:**
- CarPlay content is represented as a normal UIKit scene/window rather than CarPlay template APIs.
- iOS-version-specific layout and window behavior is corrected with Objective-C hooks.
- Feature toggles can alter the browser client without rebuilding separate controllers.

## Targets and Layers

**CarTube main app:**
- SwiftUI application layer — `CarTube/CarTubeApp.swift`
- Phone presentation layer — `CarTube/Views/*.swift`
- CarPlay scene/window layer — `CarTube/CarPlay/CarPlaySceneDelegate.swift`
- CarPlay presentation/browser layer — `CarTube/CarPlay/CarPlayViewController.swift`
- Cross-surface coordination — `CarTube/CarPlay/CarPlaySingleton.swift`
- System/private interop — `CarTube/Util/Utilities.swift`
- Objective-C hook layer — `CarTube/Hooks/*.m`, `CarTube/Hooks/AutoHook/AutoHookImplementor.m`
- Browser feature scripts — `CarTube/Scripts/*.js`

**PlayOnCarTube extension:**
- Share input translation only — `PlayOnCarTube/ShareViewController.swift`
- Converts shared URL/text into the main app’s `cartube://<videoID>` scheme.

## Entry Points

**Process entry:**
- `@main struct CarTubeApp` in `CarTube/CarTubeApp.swift`
- `init()` registers defaults and lock-screen brightness callbacks.
- `WindowGroup` presents `ContentView`, handles `cartube://` URLs, and starts update checking.

**CarPlay scene entry:**
- `UIApplicationSceneManifest` in `CarTube/Info.plist` selects `CarPlaySceneDelegate`.
- `scene(_:willConnectTo:options:)` creates `UIWindow`, sets `CarPlayViewController`, and makes it visible.

**Share entry:**
- `NSExtensionPrincipalClass` in `PlayOnCarTube/Info.plist` selects `ShareViewController`.
- `viewWillAppear()` and `didSelectPost()` initiate URL extraction/opening.

**Browser entry:**
- A cached URL is consumed or YouTube home is loaded during `CarPlayViewController.viewDidLoad()`.

## Core Data Flow

**Manual playback:**
```text
ContentView TextField
  -> extractYouTubeVideoID() in CarTube/Util/Utilities.swift
  -> CarPlaySingleton.shared.loadUrl(YT_EMBED + id)
  -> CarPlayViewController.loadUrl()
  -> WKWebView.load()
  -> bundled WKUserScripts adapt YouTube
```

**Share-extension playback:**
```text
iOS share sheet
  -> PlayOnCarTube/ShareViewController.swift extracts ID
  -> responder chain opens cartube://<id>
  -> CarTubeApp.onOpenURL validates 11-character ID
  -> CarPlaySingleton caches/loads YouTube watch URL
```

**Now-playing takeover:**
```text
CarPlayViewController.viewDidLoad()
  -> CarPlaySingleton.checkIfYouTubePlaying()
  -> getNowPlaying() via MediaRemote/Dynamic
  -> user confirms YouTube app bundle ID
  -> CarPlaySingleton.searchVideo(title + artist)
  -> WKWebView loads YouTube search
```

**Settings flow:**
```text
Settings toggles/bindings
  -> saveSettings() writes UserDefaults scalar values
  -> exitGracefully() suspends then terminates process
  -> next CarPlay controller construction reads defaults and selects scripts/zoom
```

**Lock-screen/brightness flow:**
```text
CarTubeApp or CarPlaySceneDelegate lifecycle
  -> Utilities notification/private-symbol functions
  -> CarPlaySingleton saves/restores brightness and auto-brightness
  -> CarPlayViewController shows screen-off warning
```

## Key Abstractions

**`CarPlaySingleton` (`CarTube/CarPlay/CarPlaySingleton.swift`):**
- Holds the optional active `CarPlayViewController`.
- Buffers one requested video before the controller exists.
- Guards feature actions by CarPlay connection/active state.
- Bridges keyboard, navigation, persistence, brightness, and now-playing workflows.

**`CarPlayViewController` (`CarTube/CarPlay/CarPlayViewController.swift`):**
- Owns main YouTube `WKWebView`, hidden NoSleep web view, SwiftUI keyboard host, warning label, and splash host.
- Implements `WKNavigationDelegate`, `WKUIDelegate`, and `WKScriptMessageHandler`.
- Translates custom keyboard input into private WebKit text simulation and `document.execCommand('delete')`.

**`AutoHook` (`CarTube/Hooks/AutoHook/AutoHook.h`):**
- Hook classes expose `targetClasses`.
- `AutoHookImplementor` copies/swizzles methods marked `hook_` onto UIKit classes.

**Free utility functions (`CarTube/Util/Utilities.swift`):**
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

---

*Architecture analysis: 2026-08-17*
