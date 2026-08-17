# Architecture Research

**Domain:** Voice search + YouTube Data API search integration into an existing hybrid SwiftUI/UIKit/WebKit CarPlay webview app
**Researched:** 2026-08-17
**Confidence:** HIGH for Apple API surface (official docs), MEDIUM for quota/entitlement process details

> Confidence-tier note: the `classify-confidence` seam returns LOW for `sosumi`/`webfetch` because those provider IDs are not in its registry — an artifact of provider registration, not source quality. All Apple claims below come from developer.apple.com content (via sosumi mirror) and were cross-checked against the local codebase; Google quota claims come from two live developers.google.com pages. Tiers below reflect that verification.

## Standard Architecture

### System Overview

New components attach as **siblings around the existing singleton**, never inside it. The webview playback path (`CarPlaySingleton.loadUrl` → `CarPlayViewController.loadUrl` → `WKWebView.load`) is the load-bearing wall: every new feature terminates in a call to it, and nothing new sits between the singleton and the webview.

```
┌───────────────────────────────────────────────────────────────────────┐
│                        ENTRY SURFACES (new)                           │
│  ┌──────────────────┐   ┌──────────────────────┐                      │
│  │ Siri AppShortcut │   │ Push-to-talk button  │                      │
│  │ SearchCarTube-   │   │ (floating UIButton   │                      │
│  │ Intent           │   │  on CarPlay screen)  │                      │
│  └────────┬─────────┘   └──────────┬───────────┘                      │
│           │ query: String          │ audio → transcript               │
├───────────┴───────────────────────┴───────────────────────────────────┤
│                     COORDINATION (new, thin)                          │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │ SearchCoordinator                                             │    │
│  │  search(query) → service → present results → tap → loadUrl   │    │
│  └──────┬───────────────────────────────┬───────────────────────┘    │
│         │                               │                            │
├─────────┴──────────────┐   ┌────────────┴──────────────────────────┤ │
│   SERVICES (new,       │   │  CARPLAY UI OVERLAY (new)             │ │
│   no UIKit deps)       │   │  SearchResultsViewController          │ │
│  ┌───────────────────┐ │   │  (UIKit list, child of existing       │ │
│  │ YouTubeSearch-    │ │   │   CarPlayViewController, layered      │ │
│  │ Service           │ │   │   above WKWebView like KeyboardView)  │ │
│  └───────────────────┘ │   └────────────┬──────────────────────────┘ │
│  ┌───────────────────┐ │                │ videoId                     │
│  │ SpeechRecognizer- │ │                ▼                            │
│  │ Service           │ │   ┌──────────────────────────────────────┐ │
│  └───────────────────┘ │   │  EXISTING — UNCHANGED CORE           │ │
│                        │   │  CarPlaySingleton.loadUrl()          │ │
│                        │   │  CarPlayViewController / WKWebView   │ │
│                        │   │  CarPlaySceneDelegate / UIWindow     │ │
│                        │   └──────────────────────────────────────┘ │
└────────────────────────┴──────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation | Attach Point |
|-----------|----------------|------------------------|--------------|
| `YouTubeSearchService` | Query YouTube Data API v3 `search.list`, return `[SearchResult]` (videoId, title, channel, thumbnail URL, duration) | Stateless class, `URLSession` async, `part=snippet&type=video&maxResults=10`, API key from bundle config | Called only by `SearchCoordinator`; knows nothing about CarPlay or WebKit |
| `SpeechRecognizerService` | Push-to-talk: mic audio → transcript via on-device `SFSpeechRecognizer` | `AVAudioEngine` input tap → `SFSpeechAudioBufferRecognitionRequest` with `requiresOnDeviceRecognition = true`; owns both permission requests | Called by the mic button's target; returns transcript via completion to `SearchCoordinator` |
| `SearchCarTubeIntent` + `CarTubeShortcuts` | Map a Siri phrase with a query parameter into an in-process search | `AppIntent` with `@Parameter` query; `AppShortcutsProvider` with phrase "Search YouTube for …" + query parameter token | Runs in the app process — calls `SearchCoordinator` directly, no extension process |
| `SearchCoordinator` | One funnel for both entry surfaces: run query, present results, resolve tap to playback, degrade on quota/permission failure | Thin `@MainActor final class`, holds the service, drives the overlay through `CarPlaySingleton` passthroughs | The only new code that touches `CarPlaySingleton` |
| `SearchResultsViewController` | Driver-glanceable tappable list on the CarPlay screen | UIKit `UITableViewController`/`UICollectionView` child VC, full-screen opaque overlay, large rows (≥60 pt), thumbnail + title + channel | Added as child of `CarPlayViewController` exactly like `keyboardController` is today |
| Mic button | Always-visible push-to-talk affordance over the webview | Small circular `UIButton` pinned top-right of `CarPlayViewController.view`, shown only when speech is authorized | Subview of `CarPlayViewController.view`, above webview, below `screenOffLabel` |

**What does NOT change:** `CarPlaySingleton`'s playback path (`loadUrl`, `cachedVideo` buffering, `AVExternalDevice` guard), the webview construction and script injection in `CarPlayViewController.viewDidLoad()`, the scene delegate lifecycle, and the `cartube://` share flow all stay byte-identical. This is the stability contract.

## Recommended Project Structure

```
CarTube/
├── CarPlay/
│   ├── CarPlaySceneDelegate.swift        # unchanged
│   ├── CarPlaySingleton.swift            # +3 passthrough methods max (see Pattern 2)
│   ├── CarPlayViewController.swift       # +child VC wiring, z-order insert
│   ├── SearchResultsViewController.swift # NEW — results list overlay
│   └── MicButton.swift                   # NEW — floating push-to-talk button
├── Search/                                # NEW group — no UIKit imports in service
│   ├── SearchResult.swift                # Codable value type
│   ├── YouTubeSearchService.swift        # Data API client
│   ├── SearchCoordinator.swift           # funnel for Siri + push-to-talk
│   ├── SearchCarTubeIntent.swift         # AppIntent
│   └── CarTubeShortcuts.swift            # AppShortcutsProvider
├── Speech/
│   └── SpeechRecognizerService.swift     # NEW — SFSpeechRecognizer wrapper
├── Util/
│   └── Utilities.swift                   # minus getNowPlaying, brightness fns
└── Scripts/                               # unchanged
```

### Structure Rationale

- **Search/:** The service, coordinator, and intent form one dependency island with no WebKit/CarPlay imports below the coordinator — the only place UIKit appears is the coordinator's presentation hop. This makes the search core testable without a CarPlay scene.
- **Speech/ kept separate from Search/:** Speech is an input modality, not a search concern. `SpeechRecognizerService` ends its job at "here is a transcript string." A future text-input surface could reuse it.
- **New CarPlay UI stays in CarPlay/:** matches the existing convention where everything the car screen renders lives beside `CarPlayViewController`.

## Architectural Patterns

### Pattern 1: Overlay-on-webview (extend the keyboard precedent)

**What:** Present search results as a native UIKit child view controller layered above the `WKWebView`, instead of navigating the webview to a YouTube results page.
**When:** Any transient driver interaction — exactly what `KeyboardView` already does.
**Trade-offs:** Native list gives instant tappable rows with known frame geometry and no JS simulation; webview playback state (current position, single-video cache model) is untouched beneath. Cost: one more child VC to size for varying car screens (`view.bounds`, not fixed 720 pt).

**Example** — mirroring the existing keyboard wiring in `CarPlayViewController.viewDidLoad()`:

```swift
// z-order today: webView → noSleepView(hidden) → keyboardView(hidden)
//                → screenOffLabel → splash(temporary)
// insert after keyboardView, before screenOffLabel:
let resultsController = SearchResultsViewController(
    onSelect: { videoId in
        CarPlaySingleton.shared.loadUrl(YT_EMBED + videoId)   // existing playback path
        self.dismissSearchResults()
    },
    onCancel: { self.dismissSearchResults() }
)
addChild(resultsController)
resultsController.view.frame = view.bounds
resultsController.view.isHidden = true
view.insertSubview(resultsController.view, belowSubview: screenOffLabel)
```

Note the deliberate difference from the keyboard: the keyboard *shrinks* the webview frame (`webView.frame.size.height = view.bounds.size.height - keyboardView.frame.size.height`) because typing targets the page. Search results must **not** resize the webview — the video keeps rendering (audibly at minimum) beneath an opaque full-screen sheet, and dismissal restores the exact pre-search view with zero layout work.

### Pattern 2: Singleton passthrough, not singleton ownership

**What:** New features get their own objects; `CarPlaySingleton` grows only by delegating methods that mirror its existing `sendInput`/`toggleKeyboard` shape.
**When:** Any new component needs to reach the car screen from outside the scene.
**Trade-offs:** Keeps the proven single bridge to `AVExternalDevice`/controller-nil edge cases (`cachedVideo` buffering, "CarPlay not connected" alert) in one place, but the singleton is already the codebase's largest debt — cap the additions at three methods.

```swift
// CarPlaySingleton — the ONLY additions:
func showSearchResults(_ results: [SearchResult]) {
    controller?.showSearchResults(results)
}
func dismissSearchResults() {
    controller?.dismissSearchResults()
}
func submitSearchQuery(_ query: String) {
    SearchCoordinator.shared.search(query)   // funnel handles service + fallback
}
```

`SearchCoordinator` is itself a `static let shared` singleton — pragmatic here because the Siri intent, the mic button, and (in degradation) the old paths all need a single entry, and introducing DI plumbing into this codebase's style would be a rewrite in disguise.

### Pattern 3: Fail-closed degradation chain

**What:** Every new capability checks its precondition and falls back to the *existing* webview search path rather than erroring.
**When:** Quota exhausted, API key missing/invalid, speech denied, CarPlay disconnected.
**Trade-offs:** Slightly more branches; in exchange the app never strands the driver with a dead screen, and the legacy `searchVideo` path (percent-encoded `m.youtube.com/results?search_query=` load) becomes the safety net instead of dead code.

```
search(query)
  ├─ API key configured?            ── no ──▶ CarPlaySingleton.searchVideo(query)   [webview search]
  ├─ search.list succeeds?          ── no ──▶ 403 quotaExceeded / 403 keyError
  │                                             └─▶ CarPlaySingleton.searchVideo(query)
  └─ results non-empty?             ── no ──▶ inline "no results" row in overlay
```

For speech: mic button visible only when `SFSpeechRecognizer.authorizationStatus() == .authorized` AND mic permission granted; a denied user simply never sees the button — no prompt loop while driving. First-use permission prompts happen on the phone screen (the CarPlay scene cannot host permission alerts), so the phone `ContentView` should pre-flight both permissions during setup.

## Data Flow

### Request Flow (Siri)

```
"Hey Siri, search YouTube for lofi beats"
    ↓  AppShortcut phrase match (compile-time extracted)
SearchCarTubeIntent.perform()          @Parameter query = "lofi beats"
    ↓
SearchCoordinator.search(query)                          [MainActor]
    ↓
YouTubeSearchService.search(query)                       [background]
    → GET youtube/v3/search?part=snippet&type=video&maxResults=10&q=...&key=...
    ← [SearchResult]                                       [decode on background]
    ↓ hop to MainActor
CarPlaySingleton.showSearchResults(results)
    ↓
CarPlayViewController.showSearchResults(_:)              overlay unhidden
    ↓ driver taps row (one glance, one tap)
CarPlaySingleton.loadUrl(YT_EMBED + videoId)             ← EXISTING playback path
    → cachedVideo buffering if controller nil / alert if no CarPlay
    → WKWebView.load() → injected WKUserScripts adapt page
overlay dismissed
```

### Request Flow (push-to-talk)

Same funnel, different head: mic button touch-down → `SpeechRecognizerService.start()` (engine starts, tap feeds buffer request) → touch-up / final transcript → `SearchCoordinator.search(transcript)` → identical tail as above. Live partial transcripts are NOT shown — a single final string keeps the driving interaction to press, speak, release.

### State Management

```
SearchCoordinator (owns)
  ├─ results: [SearchResult]          ephemeral, per-query
  ├─ isSearching: Bool                drives overlay spinner row
  └─ service: YouTubeSearchService    stateless
CarPlayViewController (owns)           existing ownership style
  ├─ resultsController visibility     like keyboardView.isHidden
  └─ micButton visibility              gated on speech auth
UserDefaults (existing scalar style)
  └─ "YouTubeSearchOn"                feature toggle, registered in CarTubeApp.init
```

No new persistence: results are throwaway, the query is not stored, and the single-cached-video model is untouched.

### Key Data Flows

1. **Selection → playback is one hop:** overlay row tap calls the same `CarPlaySingleton.loadUrl(YT_EMBED + id)` the share extension and phone TextField already use. No new navigation code path into the webview exists anywhere.
2. **Quota fallback preserves function:** a failed Data API query degrades to the webview-results load the now-playing takeover already used (`searchVideo`), so search never hard-fails.
3. **Speech terminates early:** `SpeechRecognizerService` produces a string and stops — it holds no reference to anything CarPlay-related, so mic/audio failures cannot destabilize playback.

## What Must Be Severed (and how degradation behaves)

| Severed item | Current location | Public replacement | Degradation behavior |
|---|---|---|---|
| MediaRemote now-playing interception | `Utilities.getNowPlaying`, `CarPlaySingleton.checkIfYouTubePlaying`, `_MRNowPlayingClientProtobuf` decode | **None exists** — `MPNowPlayingInfoCenter` is write-only for your own app; reading other apps' now-playing has no public API | Feature removed entirely: delete `checkIfYouTubePlaying()` call from `viewDidLoad`, `dontAskAboutLastPlaying()`, and the Dynamic protobuf path. Startup gets *faster* and simpler; nothing else referenced it |
| BackBoardServices brightness symbols (`BKSDisplayBrightnessGetCurrent/Set`, `SetAutoBrightnessEnabled`) + SpringBoard CFPreferences reads | `Utilities` brightness functions; `CarPlaySingleton.saveInitialBrightness/setLowBrightness/restoreBrightness` | `UIScreen.brightness` (own-display only — cannot dim the CarPlay screen on phone-lock the way the private calls did) | Lock-screen **dimming** is gone; the **warning label** survives (`showScreenOffWarning` depends only on the notify registration, which stays this milestone). Remove/hide the `LockScreenDimmingOn` setting + `setLowBrightness`/`restoreBrightness` bodies; keep the notification → warning-label path intact |
| TrollStore entitlements (`platform-application`, `com.apple.private.security.no-container`, `com.apple.backboard.displaybrightness`) + `ipabuild.sh`/ldid | `CarTube.entitlements`, build scripts | Standard free/team code signing + the official CarPlay entitlement once granted | No runtime degradation — these entitlements exist solely to authorize the severed private calls. Removing both sides in the same phase is the clean joint |
| Deployment target 14.0 | `project.pbxproj` (all 4 configs) | Raise to iOS 16 minimum (AppIntents floor; 17/18 if the team prefers current-1) | User-visible narrowing only; codebase uses no APIs that regress |

Severance ordering matters: cut MediaRemote/brightness/entitlements **before** adding search components. `viewDidLoad` (where `checkIfYouTubePlaying` fires) and `CarPlaySingleton` are exactly the files search touches — extending first would mean rebasing new wiring over code scheduled for deletion.

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 1 user (dev/TestFlight) | Nothing — 100 `search.list` calls/day is far beyond one driver's usage |
| ~100 active searchers | **First bottleneck: the shared API key.** The 100/day `search.list` bucket is *per project key across all installs*, not per user — roughly 100 searches/day total. File Google's quota extension request form early (external timeline, like the CarPlay entitlement) |
| 1k+ users | Quota extension granted or sustained fallback to webview search (Pattern 3 makes this automatic and invisible). Cache identical queries in `SearchCoordinator` (even a 1-entry last-query cache halves repeated "play that again" taps). Use `fields=` filtering to trim payloads |
| Any scale | Speech is on-device: no quota, no per-user cost, works with poor connectivity — this is why `requiresOnDeviceRecognition` is non-negotiable |

### Scaling Priorities

1. **First bottleneck:** API-key quota (shared across all users; resets midnight PT). Mitigation: extension request + automatic webview fallback + last-query cache.
2. **Second bottleneck:** none architectural — playback remains one webview, one video, exactly as today. Voice adds no server dependency.

## Anti-Patterns

### Anti-Pattern 1: Rendering results inside the webview

**What people do:** Navigate the CarPlay `WKWebView` to `m.youtube.com/results?search_query=...` and let the user tap YouTube's own web results.
**Why it's wrong:** Destroys the current video's playback state (the app's core contract is the single-cached-video model), adds multi-second page loads per interaction, and yields tiny unglanceable web targets requiring the private text-simulation input path — the exact private-API surface being severed for App Review.
**Do this instead:** Native `SearchResultsViewController` overlay; the webview never navigates until a concrete `videoId` is chosen.

### Anti-Pattern 2: Growing `CarPlaySingleton` into the search engine

**What people do:** Add the URLSession client, JSON decoding, speech session, and results storage as methods on `CarPlaySingleton` because it's the reachable object from everywhere.
**Why it's wrong:** The singleton is already the codebase's acknowledged god-object; embedding network + audio sessions makes it untestable and couples playback stability (the thing we must not destabilize) to search churn.
**Do this instead:** Services live outside; the singleton gains at most the three passthroughs in Pattern 2.

### Anti-Pattern 3: SiriKit `INIntent` + Intents extension

**What people do:** Use the older SiriKit custom-intents flow with a separate Intents-app-extension target, as most CarPlay-era tutorials show.
**Why it's wrong:** An extension runs in a separate process — it cannot see `CarPlaySingleton`, `CarPlayViewController`, or the webview, forcing an XPC/URL-scheme relay for what is an in-process call. Also requires intent-definition files and user setup of the shortcut.
**Do this instead:** `AppIntents` (iOS 16+): `perform()` executes in the app process, App Shortcuts need zero user setup, and phrases are compile-time extracted. The deployment-target raise this milestone already requires makes this free.

### Anti-Pattern 4: Shipping the API key in source

**What people do:** Paste the Google API key into `YouTubeSearchService.swift` or a committed plist.
**Why it's wrong:** Extractable from any IPA; a leaked key burns the whole project's daily quota.
**Do this instead:** Inject via xcconfig/build setting into `Info.plist` at build time, and restrict the key to the app's bundle ID in Google Cloud Console. (Key still ships in the IPA — bundle-ID restriction is the real guard; an obfuscation layer is optional theater.)

### Anti-Pattern 5: Server-based speech recognition

**What people do:** Leave `requiresOnDeviceRecognition` unset (default allows Apple-server recognition).
**Why it's wrong:** Sends driver voice audio off-device (privacy + App Review privacy-label burden), fails with no connectivity, and server recognition has its own usage limits.
**Do this instead:** `requiresOnDeviceRecognition = true` with an availability check on `supportsOnDeviceRecognition`; degrade by hiding the mic button, never by falling back to server recognition.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| YouTube Data API v3 `search.list` | Plain `URLSession` GET with API key, `part=snippet`, `type=video`, `maxResults=10`, `fields=` filter | **Quota model changed** (verified 2026-06 docs): default is now a dedicated bucket of **100 `search.list` calls/day at 1 unit each**, plus 10,000 units/day for other endpoints — PROJECT.md's "a search costs 100 units" is outdated. `videos.list` (for durations) costs 1 unit from the 10k pool. Quota resets midnight PT; file the extension form before public launch |
| `SFSpeechRecognizer` (Speech framework) | `AVAudioEngine` input tap → `SFSpeechAudioBufferRecognitionRequest` | Requires `NSSpeechRecognitionUsageDescription` + `NSMicrophoneUsageDescription` Info.plist keys — the app **crashes** requesting authorization without the speech key. `requestAuthorization` at first phone-screen use, never from the car |
| Siri / App Shortcuts | `AppShortcutsProvider` + `AppShortcut(intent:phrases:shortTitle:systemImageName:)`, iOS 16.0+ | Phrases are static + compile-time extracted; parameter tokens (`\(...)` interpolation with `AppShortcutPhraseToken`) let one phrase carry the query. Zero user setup |
| Apple CarPlay entitlement | Application at developer.apple.com/contact/carplay/ (Apple-ID gated) | External timeline outside our control — start the application in the first phase, since TestFlight on device blocks on it. Note: Apple now lists a **CarPlay video app category** ("play video content in supported cars when parked") with new video templates — a legitimate alternative to the webview hack, but a template rebuild is explicitly out of scope this milestone |
| UserDefaults (existing) | Scalar string-literal keys, registered in `CarTubeApp.init()` | Add `YouTubeSearchOn` following the existing pattern; codebase convention (documented debt) is retained, not fixed here |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `Search/*` ↔ `CarPlay/*` | One direction only: Search calls into CarPlay (`showSearchResults`, `loadUrl`). CarPlay never imports Search except `CarPlayViewController` constructing/holding the overlay | Keeps playback core ignorant of search; search can be deleted without touching the webview path |
| `Speech` ↔ everything | Terminal: emits a `String` transcript via completion | No shared state, no CarPlay references — mic failures are structurally unable to reach playback |
| Siri intent ↔ app process | Direct in-process call to `SearchCoordinator.shared` (no extension target) | Requires AppIntents, not SiriKit — the deployment-target raise enables this |
| Thread boundary | Service decodes on background; everything touching `CarPlayViewController`/`WKWebView` hops to main | Matches existing code's main-queue discipline (alerts, MediaRemote callback already dispatch to main). Speech/audio callbacks arrive off-main — marshal before presentation |

## Build Order (dependency-driven)

```
0. CarPlay entitlement application         (external process — start immediately, parallel)
1. Severance: private APIs + entitlements + deployment target + ipabuild removal
2. YouTubeSearchService + SearchResult            (leaf, no UI, unit-testable)
3. SearchResultsViewController overlay + mic-free wiring into CarPlayViewController
4. SpeechRecognizerService + mic button           (needs 3 for results display)
5. SearchCoordinator + quota/degradation chain    (needs 2+3; makes 4 and 6 correct)
6. SearchCarTubeIntent + AppShortcutsProvider     (thinnest layer; needs 5)
```

Rationale per step:

1. **Sever before extend.** The files search must touch (`CarPlaySingleton`, `CarPlayViewController.viewDidLoad`, `Utilities`) are the same files losing MediaRemote/brightness code. Deleting first means new wiring never sits atop code scheduled for removal, and the review-risk surface is reduced before anything new is added.
2. **Leaf first.** The API client has zero dependencies on the app; it can be built and unit-tested (fixture JSON → `[SearchResult]`) before any CarPlay work, and it is the piece with external unknowns (key setup, quota behavior).
3. **UI before voice.** Push-to-talk and Siri are useless without somewhere to show results; the overlay follows the proven keyboard pattern so it carries low novelty risk.
4. **Speech after UI.** Adds Info.plist keys, permission pre-flight on the phone screen, and the mic button visibility gating.
5. **Coordinator last-but-one.** Once query sources and result display both exist, the funnel + fallback chain is small and testable end-to-end.
6. **Siri last.** The intent is ~40 lines over the finished funnel; App Shortcuts phrase extraction wants stable phrases, so finalizing it last avoids re-extraction churn.

## Sources

- App Shortcuts overview + `AppShortcut` + `AppShortcutsProvider` (iOS 16.0+ availability): developer.apple.com/documentation/appintents/app-shortcuts, /appshortcut, /appshortcutsprovider — official Apple docs, HIGH
- Speech authorization requirements (`NSSpeechRecognitionUsageDescription`, crash-without-key, `requestAuthorization`): developer.apple.com/documentation/speech/asking-permission-to-use-speech-recognition — official, HIGH
- `supportsOnDeviceRecognition` / `requiresOnDeviceRecognition`: developer.apple.com/documentation/speech — official, HIGH
- YouTube Data API quota model (100 `search.list`/day dedicated bucket @ 1 unit, 10k units/day other endpoints, midnight-PT reset): developers.google.com/youtube/v3/determine_quota_cost and /getting-started (both "Last updated 2026-06-01") — official, cross-verified on two pages, HIGH; **contradicts PROJECT.md's 100-unit-per-search assumption — PROJECT.md should be corrected**
- CarPlay categories incl. new video-app category, entitlement request URL: developer.apple.com/carplay/ — official, HIGH
- UIKit-in-CarPlay-scene viability: verified empirically by the existing codebase (`KeyboardView` UIHostingController + WKWebView + gestures already render and receive touch in the `UIWindowSceneSessionRoleCarPlay` window), MEDIUM-HIGH
- Deployment target 14.0 (4 build configs), existing singleton/controller/keyboard wiring: local codebase files, HIGH

---
*Architecture research for: CarTube voice + YouTube search milestone*
*Researched: 2026-08-17*
