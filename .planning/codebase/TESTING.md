# Testing Patterns

**Analysis Date:** 2026-08-17

## Test Framework

**Runner:**
- None. `CarTube.xcodeproj` contains no test target and no scheme test action configuration was identified.
- Config: `CarTube.xcodeproj/project.pbxproj`

**Assertion Library:**
- None.

**Run Commands:**
```bash
xcodebuild -project CarTube.xcodeproj -scheme CarTube build   # Compile main scheme
./ipabuild.sh                                                # Build unsigned Debug IPA
```

There is no test command because no test target exists.

## Test File Organization

**Location:**
- No test directories or `*Tests.swift` files exist.
- No `Tests/` folder exists at repository root.

**Naming:**
- No established project test naming convention.

**Structure:**
```text
(no tests)
```

## Existing Verification

**Compile/build verification:**
- `xcodebuild` is the primary available static verification path.
- `ipabuild.sh` verifies an iOS device build, strips standard signing, applies entitlements, and packages the IPA.

**Manual/runtime verification surface:**
- CarPlay connection and external display behavior (`CarTube/CarPlay/CarPlaySingleton.swift`)
- WKWebView navigation and JavaScript behavior (`CarTube/CarPlay/CarPlayViewController.swift`)
- YouTube ID extraction from URL, text, clipboard, and share extension (`CarTube/Util/Utilities.swift`, `PlayOnCarTube/ShareViewController.swift`)
- Settings defaults and WebKit reconstruction after process exit (`CarTube/CarTubeApp.swift`, `CarTube/Views/Settings.swift`)
- Lock-screen brightness, screen persistence, and screen-off warning (`CarTube/Util/Utilities.swift`, `CarTube/CarPlay/`)
- Share extension activation and URL handoff (`PlayOnCarTube/Info.plist`, `PlayOnCarTube/ShareViewController.swift`)

## Mocking

**Framework:** None.

**Patterns:**
- No mocks, stubs, fixtures, factories, or snapshot tests exist.

**What to Mock if tests are introduced:**
- YouTube URL parsing input/output is pure enough to test without mocks after centralizing the duplicated regex.
- Network release checks should use a URL protocol stub rather than hitting GitHub.
- UserDefaults should use an injected suite or temporary defaults instance.

**What NOT to Mock:**
- Private-framework calls for screen lock and brightness require real devices/TrollStore contexts and should remain integration/manual tests.
- WKWebKit user-script behavior should be exercised in a real WKWebView where possible.

## Fixtures and Factories

**Test Data:**
- No fixture files exist.
- Candidate pure inputs include valid/invalid YouTube URLs, 11-character IDs, mobile/desktop/share URLs, plain text, and empty strings.

**Location:**
- If introduced, place target-owned tests in conventional Xcode locations and keep fixture JSON/text minimal.

## Coverage

**Requirements:** None enforced.

**View Coverage:**
- No coverage command exists because no test target exists.

## Test Types

**Unit Tests:**
- Not present.
- Highest-value first candidates: YouTube ID parser, search percent-encoding, settings key/default consistency, and URL validation.

**Integration Tests:**
- Not present.
- Share-extension URL extraction and main-app `cartube://` handling are connected but not covered.

**E2E Tests:**
- Not present.
- Playback, CarPlay presentation, JavaScript injection, and private APIs currently require manual device validation.

## Common Patterns

**Async Testing:**
- No established pattern.
- Network update checking uses `URLSession.dataTask`; a test would need a stubbed protocol or injected loader.

**Error Testing:**
- No established pattern.
- `getNowPlaying` returns `Result`; it is a good candidate for failure-path unit coverage if private framework access is isolated behind a protocol.

## Adding Tests

1. Add a new unit test target to `CarTube.xcodeproj` rather than mixing tests into app targets.
2. Start with pure helpers in `CarTube/Util/Utilities.swift` and the duplicated share-extension parser.
3. Introduce protocol/injection boundaries for UserDefaults and networking before testing stateful flows.
4. Keep CarPlay/private API checks as separately gated integration tests because simulator support is insufficient.
5. Add CI only after a real test target and reliable build environment are established.

---

*Testing analysis: 2026-08-17*
