# Code Conventions

**Analysis Date:** 2026-08-17

## General Style

**Languages and layout:**
- Swift uses four-space indentation and conventional PascalCase types, camelCase members, and SCREAMING_SNAKE_CASE global constants.
- Objective-C uses two- or four-space indentation depending on the original vendored file; keep each existing file internally consistent.
- JavaScript is largely vendored third-party code. Preserve its existing style unless replacing a script deliberately.
- Files contain a header comment with the file/module name and original author where already established.

**Current formatting reality:**
- There is no SwiftFormat, SwiftLint, Prettier, EditorConfig, or formatting CI configuration.
- SwiftUI chains are often kept on one line, especially in older views.
- Match nearby formatting rather than reformatting entire unrelated files.

## Swift Patterns

**App and views:**
- Declare SwiftUI views as structs under `CarTube/Views/`.
- Use private `@State` for local view state.
- Keep small action methods on the view rather than embedding complex closures in button labels (`CarTube/Views/ContentView.swift`).
- Provide `PreviewProvider` stubs for primary views when following existing patterns (`CarTube/Views/ContentView.swift`, `CarTube/Views/Settings.swift`).

**State and persistence:**
- Initialize `@State` directly from `UserDefaults.standard` in `Settings`.
- Write all edited defaults in one `saveSettings()` action (`CarTube/Views/Settings.swift`).
- Register defaults at app startup (`CarTube/CarTubeApp.swift`).
- Avoid introducing a second persistence mechanism unless the process-exit settings contract changes.

**Singleton facade:**
- Cross-surface commands route through `CarPlaySingleton.shared` rather than views directly retaining `CarPlayViewController`.
- Keep `CarPlayViewController` ownership private to `CarPlaySingleton`.
- Use `controller == nil` caching for requests made before CarPlay UI exists (`CarTube/CarPlay/CarPlaySingleton.swift`).

**Delegation:**
- `CarPlayViewController` implements WebKit navigation, UI, and script-message delegation directly.
- New popups are forced back into the same web view by returning `nil` from `createWebViewWith` (`CarTube/CarPlay/CarPlayViewController.swift`).

**UIKit/SwiftUI bridging:**
- Embed SwiftUI keyboard/splash content with `UIHostingController` and explicit parent/child containment (`CarTube/CarPlay/CarPlayViewController.swift`).
- Route alerts through `UIApplication.shared.alert` / `confirmAlert` helpers rather than platform-specific SwiftUI state (`CarTube/Extensions/Alert++.swift`).

## Objective-C Hook Patterns

**Required structure:**
- Declare a hook subclass conforming to `AutoHook`.
- Implement `+targetClasses` with target class names.
- Name replacement selectors with the `hook_` prefix.
- Keep an `original_` selector stub where the swizzled method needs to call through.
- Use `CarTube/Hooks/AutoHook/AutoHookImplementor.m` conventions; do not add another swizzling engine.

**Examples:**
- Window safe-area correction: `CarTube/Hooks/AutoResize.m`
- Scroll-bar suppression: `CarTube/Hooks/HideScrollBar.m`

**Private declarations:**
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

**Current patterns:**
- User-facing failures commonly show an alert through `UIApplication.shared.alert`.
- Optional user actions use `confirmAlert` with an OK handler.
- URL conversion and regex parsing contain force-unwraps/force-tries.
- WebKit script loading silently skips unavailable resources with `guard ... else { return }`.
- Phase 2 removed the private-API surface; no code should assume private iOS 14–15.4 symbols exist.

**Recommended for new code:**
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

---

*Convention analysis: 2026-08-17*
