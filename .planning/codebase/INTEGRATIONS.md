# External Integrations

**Analysis Date:** 2026-08-17

## Overview

CarTube integrates primarily with YouTube in a WKWebView, Apple CarPlay/system media services, iOS share/URL routing, and one GitHub release API call. There is no local database, authentication provider, webhook receiver, or custom backend.

## Web and API Integrations

**YouTube Web:**
- Mobile home: `https://m.youtube.com/`
- Watch URL builder: `https://m.youtube.com/watch?v=<id>`
- Search URL builder: `https://m.youtube.com/results?search_query=<query>`
- Constants: `CarTube/Util/Constants.swift`
- Loaded by `WKWebView` in `CarTube/CarPlay/CarPlayViewController.swift`

**GitHub Releases API:**
- Endpoint: `https://api.github.com/repos/Avangelista/CarTube/releases/latest`
- Compares `tag_name` against `CFBundleShortVersionString`
- Opens `https://github.com/Avangelista/CarTube/releases/latest` when a newer numeric version exists
- Implementation: `CarTube/CarTubeApp.swift`

**External Website Links:**
- Source repository and release page links in `CarTube/CarTubeApp.swift`, `CarTube/Views/ContentView.swift`, and `CarTube/Views/HowTo.swift`
- Donation link in `CarTube/Views/ContentView.swift` and `CarTube/Views/HowTo.swift`

## Browser Injected Integrations

**SponsorBlock behavior:**
- Bundled script: `CarTube/Scripts/SponsorBlock.js`
- Enabled by `SponsorBlockOn` user default
- Added as a `WKUserScript` at document end by `CarTube/CarPlay/CarPlayViewController.swift`

**Age restriction bypass:**
- Bundled script: `CarTube/Scripts/AgeRestrictBypass.js`
- Enabled by `AgeRestrictBypassOn`
- Injected at document end into all frames

**Ad blocking:**
- Bundled script: `CarTube/Scripts/AdBlocker.js`
- Enabled by `AdBlockerOn`
- Injected at document end into all frames

**YouTube layout adaptation:**
- Bundled script: `CarTube/Scripts/CustomLayout.js`
- Always enabled
- Coordinates with a `keyboard` `WKScriptMessage` handler to show/hide the custom CarPlay keyboard

## Apple System Integrations

**CarPlay:**
- `UIWindowSceneSessionRoleCarPlay` configuration in `CarTube/Info.plist`
- Scene creation and lifecycle in `CarTube/CarPlay/CarPlaySceneDelegate.swift`
- External CarPlay connection checked through `AVExternalDevice.currentCarPlay()` in `CarTube/CarPlay/CarPlaySingleton.swift`

**Now Playing / MediaRemote:**
- Loads `/System/Library/PrivateFrameworks/MediaRemote.framework`
- Invokes `MRMediaRemoteGetNowPlayingInfo`
- Decodes `_MRNowPlayingClientProtobuf` with Dynamic
- Detects the YouTube app bundle ID and offers to search the currently playing title
- Implementation: `CarTube/Util/Utilities.swift`, `CarTube/CarPlay/CarPlaySingleton.swift`

**Screen and lock state:**
- Registers for `com.apple.springboard.hasBlankedScreen`
- Registers for `com.apple.springboard.lockstate`
- Reads/writes BackBoardServices brightness and auto-brightness symbols
- Reads SpringBoard screen-lock status and preferences
- Implementation: `CarTube/Util/Utilities.swift`

**Screen persistence:**
- Hidden `WKWebView` loads `about:blank` with `CarTube/Scripts/NoSleepEnable.js`
- Controller exposes `enablePersistence()` / `disablePersistence()`
- Managed by `ScreenPersistenceOn` and CarPlay lifecycle in `CarTube/CarPlay/CarPlayViewController.swift`, `CarTube/CarPlay/CarPlaySingleton.swift`

**iOS share sheet:**
- Extension target: `PlayOnCarTube`
- Principal class: `PlayOnCarTube/ShareViewController.swift`
- Accepts URL and plain-text attachments, extracts a YouTube ID, and forwards `cartube://<videoID>`

**Custom URL routing:**
- Scheme: `cartube://`
- Main app handles URLs in `CarTube/CarTubeApp.swift`
- Share extension constructs URLs in `PlayOnCarTube/ShareViewController.swift`

**Clipboard:**
- On active scene phase, `ContentView` reads a general pasteboard URL and prefills recognized YouTube links (`CarTube/Views/ContentView.swift`)

## Data Stores

**UserDefaults.standard:**
- All persisted user preferences are scalar values keyed by string literals.
- Keys: `SponsorBlockOn`, `AgeRestrictBypassOn`, `AdBlockerOn`, `Zoom`, `ScreenPersistenceOn`, `LockScreenDimmingOn`
- Registration: `CarTube/CarTubeApp.swift`
- Writes: `CarTube/Views/Settings.swift`

**No database:**
- Web navigation history is held only by `WKWebView`.
- No Core Data, SQLite, Realm, server session, or token store exists.

## Security Profile

- No authentication flow and no credential storage.
- App-network behavior consists of YouTube page resources and the GitHub release API.
- Browser scripts are local immutable bundle resources, not downloaded remote code.
- Elevated behavior is implemented through private APIs and entitlements and depends on TrollStore installation (`CarTube/CarTube.entitlements`, `README.md`).

---

*Integration analysis: 2026-08-17*
