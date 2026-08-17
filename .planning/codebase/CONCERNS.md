# Codebase Concerns

**Analysis Date:** 2026-08-17

## Tech Debt

**Duplicated YouTube parser:**
- Issue: The same large regex is separately force-tried in the app and share extension, with independent failure behavior.
- Files: `CarTube/Util/Utilities.swift`, `PlayOnCarTube/ShareViewController.swift`
- Impact: A URL-format fix must be made twice and can drift between targets.
- Fix approach: Move parsing into a shared framework/package or compile a shared source file into both targets, then add parser unit tests.

**No test target:**
- Issue: The project has no automated test or coverage infrastructure.
- Files: `CarTube.xcodeproj/project.pbxproj`
- Impact: Regressions in URL parsing, settings, script injection, and extension handoff are found only manually.
- Fix approach: Add a unit test target, begin with pure parser/settings tests, then isolate CarPlay/private APIs behind protocols for integration tests.

**Force-unwrap and force-try hotspots:**
- Issue: Several invariant assumptions terminate or trap at runtime.
- Files: `CarTube/CarTubeApp.swift`, `CarTube/Views/ContentView.swift`, `CarTube/Views/HowTo.swift`, `CarTube/CarPlay/CarPlayViewController.swift`, `CarTube/Util/Utilities.swift`, `PlayOnCarTube/ShareViewController.swift`
- Impact: Malformed input, missing bundle resources, or unexpected page state can crash the app/extension.
- Fix approach: Guard URL construction, preload static regexes safely, validate resource presence in development, and replace `as!` extension casting with conditional iteration.

**No centralized constants/configuration:**
- Issue: User-default keys are string literals repeated across app init, settings reads, and controller reads.
- Files: `CarTube/CarTubeApp.swift`, `CarTube/Views/Settings.swift`, `CarTube/CarPlay/CarPlayViewController.swift`, `CarTube/CarPlay/CarPlaySingleton.swift`
- Impact: Renaming or adding a setting risks missed registration/read/write sites.
- Fix approach: Introduce a strongly typed settings model or enum-backed keys while retaining the current exit-to-apply behavior.

**Legacy SwiftUI syntax:**
- Issue: Views use `PreviewProvider` and `onChange(of:) { newValue in }`, consistent with iOS 14 but older than current SwiftUI idioms.
- Files: `CarTube/Views/*.swift`
- Impact: Future toolchain migrations may produce warnings; modernization risks deployment-target regressions.
- Fix approach: Preserve iOS 14-compatible syntax until a deliberate minimum-iOS upgrade, then migrate previews and change handlers together.

## Known Bugs / Behavioral Risks

**Settings apply by process termination:**
- Symptoms: Saving settings suspends and then calls `exit(0)`.
- Files: `CarTube/Views/Settings.swift`, `CarTube/Util/Utilities.swift`
- Trigger: Tapping Save Settings.
- Workaround: Current behavior is intentional to recreate WKWebView configuration.
- Fix approach: Rebuild or replace the active web-view configuration in place, or clearly retain termination as a compatibility contract.

**Controller lifetime and scene teardown ambiguity:**
- Symptoms: The singleton retains the controller until explicitly removed; no scene disconnect path visibly clears it.
- Files: `CarTube/CarPlay/CarPlaySingleton.swift`, `CarTube/CarPlay/CarPlaySceneDelegate.swift`, `CarTube/CarPlay/CarPlayViewController.swift`
- Trigger: Repeated CarPlay scene creation/disconnection across iOS versions.
- Impact: Commands may target a stale web view or memory may remain alive longer than expected.
- Fix approach: Clear/reset singleton state in scene teardown or deinit and add lifecycle instrumentation.

**Silent script/resource failures:**
- Symptoms: Missing JS resources are skipped, and NoSleep setup returns early from `viewDidLoad`.
- Files: `CarTube/CarPlay/CarPlayViewController.swift`
- Trigger: Resource not added to target or bundle loading failure.
- Impact: Core layout or screen-persistence behavior silently disappears.
- Fix approach: Accumulate load errors, log them, and expose a diagnostic in the existing Debug screen.

**Regex accepts only an exact 11-character ID:**
- Symptoms: Main-app custom URL handling checks only string length before building the watch URL.
- Files: `CarTube/CarTubeApp.swift`, `PlayOnCarTube/ShareViewController.swift`
- Trigger: Any `cartube://` payload that is not exactly 11 characters.
- Impact: Invalid IDs can load broken YouTube URLs instead of receiving consistent parser validation.
- Fix approach: Route custom-scheme payloads through the same validated parser/character-set check.

## Security Considerations

**Private APIs and elevated entitlements:**
- Risk: System brightness, lock state, now-playing metadata, no-container, and platform-application capabilities depend on private APIs.
- Files: `CarTube/CarTube.entitlements`, `CarTube/Util/Utilities.swift`, `CarTube/Hooks/`
- Current mitigation: Distribution is explicitly scoped to TrollStore and iOS 14–15.4.1 (`README.md`); scripts are bundled rather than remotely fetched.
- Recommendations: Keep compatibility assertions visible, isolate private calls, and avoid expanding entitlements without a documented requirement.

**WebView content trust:**
- Risk: YouTube web content and scripts execute in an app web view; custom layout/script behavior may break or interact with page changes.
- Files: `CarTube/CarPlay/CarPlayViewController.swift`, `CarTube/Scripts/*.js`
- Current mitigation: New-webview creation is redirected to the same controller; scripts are local bundle resources.
- Recommendations: Track upstream script updates, test injection failures, and avoid adding remote script loading.

**Update response handling:**
- Risk: GitHub response body text is inserted directly into an alert without validating response status or schema.
- Files: `CarTube/CarTubeApp.swift`
- Current mitigation: Decoding failure is ignored and the action only opens a fixed GitHub URL.
- Recommendations: Check HTTP status and decode a small typed response model before presenting release text.

**Clipboard access:**
- Risk: Reading general pasteboard on activation can trigger iOS paste privacy indicators and expose broader URL content to parsing logic.
- Files: `CarTube/Views/ContentView.swift`
- Current mitigation: Reads only when URLs are present and prefills recognized YouTube links.
- Recommendations: Consider an explicit paste button or iOS-version-appropriate pasteboard APIs when modernizing.

## Performance Bottlenecks

**Oversized browser scripts injected on every page:**
- Problem: Ad blocking, age bypass, SponsorBlock, and layout scripts are re-read and injected for each controller/page configuration.
- Files: `CarTube/Scripts/*.js`, `CarTube/CarPlay/CarPlayViewController.swift`
- Cause: Multiple large vendored scripts, some over a thousand lines.
- Improvement path: Measure startup/navigation impact, cache source strings, and lazy-load page-specific behavior where WebKit allows.

**Synchronous bundle file reads during view load:**
- Problem: Script resources are read with `String(contentsOfFile:)` on the main thread in `viewDidLoad`.
- Files: `CarTube/CarPlay/CarPlayViewController.swift`
- Cause: All enabled scripts are loaded before web-view presentation.
- Improvement path: Measure first; if meaningful, preload asynchronously before CarPlay scene connection.

**Two WKWebViews:**
- Problem: A hidden web view is kept solely for NoSleep behavior.
- Files: `CarTube/CarPlay/CarPlayViewController.swift`, `CarTube/Scripts/NoSleepEnable.js`
- Cause: Browser-based wake-lock workaround.
- Improvement path: Evaluate supported idleTimer/scene strategies per deployment target; retain fallback for old iOS versions.

## Fragile Areas

**Objective-C method swizzling:**
- Files: `CarTube/Hooks/AutoHook/AutoHookImplementor.m`, `CarTube/Hooks/AutoResize.m`, `CarTube/Hooks/HideScrollBar.m`
- Why fragile: It replaces UIKit methods and relies on runtime class/method availability and matching type encodings.
- Safe modification: Keep hook signatures identical, test on all supported iOS patch releases, and avoid broadening target classes.
- Test coverage: None; manual CarPlay visual validation is required.

**YouTube DOM assumptions:**
- Files: `CarTube/Scripts/CustomLayout.js`, `CarTube/Scripts/AdBlocker.js`, `CarTube/Scripts/SponsorBlock.js`
- Why fragile: YouTube can change DOM, player internals, request patterns, or script sandbox behavior.
- Safe modification: Keep changes narrowly scoped, preserve attribution/licensing, and test playback plus keyboard integration.
- Test coverage: None; requires manual web playback and layout checks.

**Private framework symbol loading:**
- Files: `CarTube/Util/Utilities.swift`
- Why fragile: `dlopen`/`dlsym` results and function signatures are assumed valid.
- Safe modification: Add optional binding and explicit failure paths without silently changing brightness behavior.
- Test coverage: None; requires physical devices and the documented TrollStore context.

**Custom keyboard input simulation:**
- Files: `CarTube/CarPlay/CarPlayViewController.swift`, `CarTube/Headers/WebView+Additions.h`
- Why fragile: `_simulateTextEntered` and `document.execCommand('delete')` depend on private WebKit behavior and editable-page state.
- Safe modification: Keep the singleton routing pattern and test both ordinary text and symbols after changes.
- Test coverage: None.

## Scaling Limits

**Compatibility window:**
- Current capacity: Explicitly iOS 14.0–15.4.1.
- Limit: Private APIs, entitlements, and hooks are not intended for newer iOS or App Store distribution.
- Scaling path: A supported-features abstraction would be needed to branch modern CarPlay/WebKit APIs from legacy private paths.

**Single active CarPlay controller:**
- Current capacity: One optional controller and one cached video.
- Limit: Requests are not queued beyond the first cached URL.
- Scaling path: If queueing is required, replace `cachedVideo` with an explicit request queue and lifecycle policy.

## Dependencies at Risk

**YouTube behavior scripts:**
- Risk: Vendored scripts derive from external projects and may lag upstream compatibility fixes.
- Impact: Ads/sponsors bypass, age bypass, or layout may stop working.
- Migration plan: Track each upstream project listed in `README.md`; evaluate tests and script updates independently.

**Dynamic Swift package:**
- Risk: Minimal active maintenance may not support future toolchains.
- Impact: MediaRemote protobuf decode can fail to compile or behave differently.
- Migration plan: Replace dynamic decoding with an explicit stable model or isolate the dependency behind a now-playing service.

## Missing Critical Features

**No crash/diagnostic telemetry:**
- Problem: Runtime failures in private API paths are largely invisible.
- Blocks: Field diagnosis of iOS-version-specific CarPlay and WebKit issues.

**No automated compatibility gate:**
- Problem: Builds are not automatically checked across supported iOS patch versions.
- Blocks: Confident changes to hooks, entitlement-dependent code, or WebKit behavior.

## Test Coverage Gaps

**YouTube URL parser:**
- What is not tested: Valid/invalid URL forms, short links, query variants, plain text, and malformed IDs.
- Files: `CarTube/Util/Utilities.swift`, `PlayOnCarTube/ShareViewController.swift`
- Risk: Core launch path can regress unnoticed.
- Priority: High

**UserDefaults contract:**
- What is not tested: Defaults registration, Settings writes, and controller reads remain consistent.
- Files: `CarTube/CarTubeApp.swift`, `CarTube/Views/Settings.swift`, `CarTube/CarPlay/CarPlayViewController.swift`
- Risk: Feature silently defaults or stops applying.
- Priority: High

**Share extension handoff:**
- What is not tested: URL/text item-provider paths, responder-chain opening, and request completion.
- Files: `PlayOnCarTube/ShareViewController.swift`
- Risk: Extension fails on real share payloads.
- Priority: Medium

**WebKit script selection:**
- What is not tested: Which scripts are enabled and injected for each settings combination.
- Files: `CarTube/CarPlay/CarPlayViewController.swift`
- Risk: Feature regressions after setting/key changes.
- Priority: Medium

---

*Concerns audit: 2026-08-17*
