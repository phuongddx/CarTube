# CarPlay Scene Regression: Root Cause + Template Migration

**Date:** 2026-08-27
**Branch:** `gsd/v1.0-milestone`
**Environment:** Xcode 26.3 (17C529), iOS 26.3 simulator (iPhone 16 Pro Max), Debug build, ad-hoc signed
**Severity:** Blocker for v1.0 — the CarPlay surface renders nothing on iOS 26

## Verdict

CarTube's CarPlay surface does not work on iOS 26.3. The app icon appears on the CarPlay
home screen and tapping it dismisses the home screen, but the car display stays blank.
`CarPlaySceneDelegate` is never instantiated. Playback requests queue in
`CarPlaySingleton.cachedVideo` and never load.

The legacy raw-`UIWindow` CarPlay approach (`UIWindowSceneSessionRoleCarPlay` +
`UIWindowSceneDelegate`) no longer receives a scene. iOS routes the app through the
CPTemplate host instead.

## Evidence

### 1. iOS hosts the app in the template host process

Simulator log, after tapping CarTube on the CarPlay home screen:

```
[com.apple.DashBoard.scene-workspace.default0:Car[2-9]:com.apple.CarPlayTemplateUIHost:com.cartube.carplay]
<DBApplicationSceneHostViewController: com.cartube.carplay; proxy: com.apple.CarPlayTemplateUIHost>
Scene update for app: <DBApplication: com.cartube.carplay> - frame: {{0,0},{400,240}}, safe area insets: {0,49,0,0}
```

The scene is created and hosted by `com.apple.CarPlayTemplateUIHost` — Apple's template UI
host — not in CarTube's process. CarTube ships no CPTemplates (no `import CarPlay`, no
`CPTemplateApplicationSceneDelegate` anywhere in the target), so the host has nothing to
render. Blank screen.

### 2. The scene delegate never runs

`Debug → Hook Verification`, live after `Refresh Status`, with the CarPlay window open and
CarTube foregrounded on the car display:

| Row | Status |
| --- | --- |
| AutoResize | PASS |
| HideScrollBar | PASS |
| Keyboard Private API | PASS |
| **Idle Timer Disabled** | **FAIL** |

`Idle Timer Disabled` reflects `UIApplication.shared.isIdleTimerDisabled`, set by
`enablePersistence()` from `CarPlaySceneDelegate.sceneDidBecomeActive`
(`CarTube/CarPlay/CarPlaySceneDelegate.swift:24`). `ScreenPersistenceOn` defaults to `true`,
so FAIL means `sceneDidBecomeActive` never fired.

This rules out the "delegate ran but bailed on the cast" theory. The
`guard let windowScene = (scene as? UIWindowScene)` at
`CarPlaySceneDelegate.swift:16` is not the failure point — the delegate is not used at all.
Both methods live on the same delegate; neither fires.

### 3. No webview navigation

`log show --predicate 'eventMessage CONTAINS "L0mhJEtsm9Y" OR CONTAINS "m.youtube.com"'`
returns nothing across the whole attempt. The webview never loads, consistent with
`CarPlayViewController` never being constructed.

### 4. Declared role is not a public constant

`CarTube/Info.plist` declares:

```xml
<key>UISceneConfigurations</key>
<dict>
  <key>UIWindowSceneSessionRoleCarPlay</key>
  ...
</dict>
```

Public `UISceneSession.Role` values are `windowApplication`,
`windowExternalDisplayNonInteractive`, `windowExternalDisplay` (deprecated),
`carTemplateApplication` (raw value `CPTemplateApplicationSceneSessionRoleApplication`),
plus the dashboard and instrument-cluster roles. `UIWindowSceneSessionRoleCarPlay` is not
among them. The manifest also omits `UISceneClassName` (so the scene class defaults to
`UIWindowScene`, not `CPTemplateApplicationScene`) and `UISceneConfigurationName`.

### 5. Entitlement is stripped in simulator builds — the sim test cannot validate it

```
$ codesign -d --entitlements :- CarTube.app     →  <dict></dict>
$ cat .../CarTube.app.xcent                     →  <dict/>
```

Xcode drops `com.apple.developer.carplay-audio` under ad-hoc "Sign to Run Locally" (no
profile grants it). The app still appeared on the CarPlay home screen with zero
entitlements, so the simulator does not gate CarPlay home-screen presence on the
entitlement. **A green simulator run proves nothing about the entitlement path.** Device
verification with the real profile remains mandatory.

### Methodology correction

An earlier pass in the same session concluded the scene *did* connect and the webview
rendered video on the car display. That was wrong. It used
`screencapture -R<x,y,w,h>` against stale window bounds; `-R` captures whatever is
topmost in that screen region, so the frames included unrelated desktop windows (one later
capture at the same coordinates returned a screenshot of the terminal). Reliable method:

```bash
# authoritative bounds + window id from CGWindowListCopyWindowInfo, then:
screencapture -x -o -l<windowID> out.png   # occlusion-proof, ignores stacking
```

With window-ID captures the CarPlay surface is blank on every attempt, across two clean
simulator boots.

## Additional defects found while investigating

| Finding | Location | Impact |
| --- | --- | --- |
| No `UIBackgroundModes` anywhere (no `audio`) | `CarTube/Info.plist`, pbxproj | Under any architecture where the webview is not the foreground CarPlay scene, audio stops on background. Blocks the migration below. |
| No `MPNowPlayingInfoCenter` / `MPRemoteCommandCenter` / `AVPlayer` usage | whole target | `CPNowPlayingTemplate` renders from Now Playing info; none exists. Must be built from scratch. |
| `LSApplicationCategoryType = public.app-category.video` | pbxproj:780, 823 | App Store category is *video* while the granted entitlement is *audio*. Inconsistent with the audio positioning in `docs/submission/app-review-notes.md`. |
| `webView._simulateTextEntered(_:)` private WebKit API | `CarPlayViewController.swift:349` | Guideline 2.5.1 rejection vector. Becomes unnecessary after migration (CarPlay text entry uses `CPSearchTemplate`). |

## Root cause

On iOS 26, a CarPlay-entitled app is vended a `CPTemplateApplicationScene` under the
`CPTemplateApplicationSceneSessionRoleApplication` role, hosted by
`com.apple.CarPlayTemplateUIHost`. CarTube declares an undocumented role
(`UIWindowSceneSessionRoleCarPlay`) and supplies a `UIWindowSceneDelegate`. No
configuration in the manifest matches the role iOS requests, so UIKit instantiates no
delegate and installs no window. The template host renders its own empty scene.

The design this inherits — drawing an arbitrary `WKWebView` onto the car display — depends
on the app owning a raw `UIWindow` on the CarPlay screen. Public API never granted that to
non-navigation apps, and iOS 26 no longer grants it via the private role either.

## Fix

### Option A — migrate to CPTemplates, audio-only on the car screen (recommended)

The only shippable path. Matches the granted audio entitlement. Video does not appear on
the car display; the WKWebView stays on the phone as the playback engine and audio routes
to the vehicle through the normal audio session.

Steps:

1. **Scene manifest** — `CarTube/Info.plist`: replace the `UIWindowSceneSessionRoleCarPlay`
   entry with

   ```xml
   <key>CPTemplateApplicationSceneSessionRoleApplication</key>
   <array>
     <dict>
       <key>UISceneClassName</key>
       <string>CPTemplateApplicationScene</string>
       <key>UISceneConfigurationName</key>
       <string>CarTubeCarPlayScene</string>
       <key>UISceneDelegateClassName</key>
       <string>$(PRODUCT_MODULE_NAME).CarPlaySceneDelegate</string>
     </dict>
   </array>
   ```

2. **Scene delegate** — rewrite `CarPlaySceneDelegate` to conform to
   `CPTemplateApplicationSceneDelegate`; implement
   `templateApplicationScene(_:didConnect:)` (the two-arg form — the three-arg
   `to window:` form is navigation-entitlement only), retain the `CPInterfaceController`,
   set a root template. Drop `UIWindowSceneDelegate`, the `UIWindow`, and
   `CarPlayViewController` from the car surface.

3. **Car UI from templates** — audio-category templates available: `CPTabBarTemplate`,
   `CPListTemplate`, `CPGridTemplate`, `CPSearchTemplate`, `CPNowPlayingTemplate`,
   `CPAlertTemplate`, `CPActionSheetTemplate`, `CPInformationTemplate`. Suggested shape:
   `CPListTemplate` for recents/results → push `CPNowPlayingTemplate` on selection.
   Reuse `YouTubeSearchService` and `SearchResult` as-is; retire
   `SearchResultsViewController` and `MicButton` for the car (replaced by `CPSearchTemplate`
   / the assistant cell).

4. **Background audio** — add `UIBackgroundModes` with `audio`, configure
   `AVAudioSession` category `.playback`, and keep the WKWebView alive on the phone side.
   Without this the audio dies the moment CarPlay is the active surface.

5. **Now Playing** — populate `MPNowPlayingInfoCenter.default().nowPlayingInfo` (title,
   artist, artwork, duration, elapsed, rate) and wire `MPRemoteCommandCenter`
   (play/pause/next/previous/seek) through to the webview's player via JS. This is what
   drives both `CPNowPlayingTemplate` and steering-wheel controls.

6. **Cleanup** — delete `_simulateTextEntered` usage and the `AutoResize` / `HideScrollBar`
   hooks for the car surface; fix `LSApplicationCategoryType` to an audio category.

Effort: substantial. Items 4 and 5 are new subsystems, not refactors.

### Option B — keep the raw-window design

Not viable. There is no public role that vends a raw `UIWindow` to a non-navigation CarPlay
app, and the private role no longer resolves on iOS 26.

### Option C — apply for the navigation entitlement

Navigation apps do get a `CPWindow` (`templateApplicationScene(_:didConnect:to:)`). Not
applicable: CarTube is not a navigation app, Apple's criteria would reject it, and the docs
explicitly restrict that window to map content ("Don't render alerts, overlays, or any
other user interface elements").

## Verification plan

1. Simulator, per-boot: `I/O → External Displays → CarPlay` (window does not survive a
   reboot; `CarPlayExtraOptions` is enabled on this machine so the menu item is
   `CarPlay…` and opens a "TV Out Extended Setup" dialog needing a **Run** click).
2. Capture with `screencapture -x -o -l<windowID>`, never `-R`.
3. Pass criteria: `CPNowPlayingTemplate` visible on the car display; `Debug → Hook
   Verification → Idle Timer Disabled` reads PASS; audio continues with the phone locked.
4. Device pass with the real CarPlay profile is mandatory — the simulator strips the
   entitlement (see Evidence 5), and locked-phone, Siri, and audio-ducking behaviour are
   untestable in the simulator.

## Docs contradicted by this evidence

These currently assert behaviour that does not hold and should be revised:

- `docs/submission/app-review-notes.md:41-66` — describes the
  `UIWindowSceneSessionRoleCarPlay` scene installing `CarPlayViewController` and rendering
  the video surface on the car screen. That mechanism does not function on iOS 26.
- `docs/runbooks/apple-carplay-entitlement-request.md:22,45` — same claim about existing
  CarPlay scene integration.
- `docs/runbooks/carplay-entitlement-grant-wiring.md` — should gain the Evidence 5 caveat
  that simulator runs cannot validate the entitlement path.

## Spike result (2026-08-28): webview cannot be the background playback engine

Ran before committing to the migration, to test the load-bearing assumption behind
`CPNowPlayingTemplate`. Scaffolding: `CarTube/CarPlay/NowPlayingBridge.swift` +
`CarTube/Views/BackgroundAudioSpike.swift`, reachable from Debug.

Setup: `UIBackgroundModes: audio` added and verified present in the built `.app`;
`AVAudioSession` `.playback`/`.moviePlayback` set and `setActive(true)` succeeded
(reported "playback / active"); `MPNowPlayingInfoCenter` populated from a 2s JS poll of the
page's `<video>` element; `MPRemoteCommandCenter` play/pause/toggle wired to JS.

**Positive — Now Playing metadata works.** The JS bridge reads title, duration,
`currentTime` and `paused` out of `m.youtube.com` and populates Now Playing. Observed live:
`playing — 12s / 5496s`.

**Blocking negative — playback does not survive backgrounding.**

| Measurement | Value |
| --- | --- |
| Position when backgrounded (home) | ~36s |
| Time spent backgrounded | ~72s |
| Predicted position if playback continued | ~107s |
| **Observed position on foreground** | **35s, state `paused`** |

The process stayed alive the whole time (`launchctl` showed the app running), so this is not
process suspension — WebKit paused its own `<video>` element on background. The audio
background mode does not override that.

Confounds ruled out: the SwiftUI view did not tear down (position would have reset to 0,
not held at 35s), and `detach()` never fired (the poll timer was still reporting fresh state
after foregrounding).

Caveat: measured on the iOS 26.3 **simulator**. Device confirmation is still advisable,
though this matches WebKit's documented behaviour of pausing HTML5 media when the app
backgrounds, so it is unlikely to be a simulator artifact.

**Implication for the fix plan.** Steps 4-5 of Option A do not work as written. A
`WKWebView` cannot serve as the background audio engine, so an audio-only CarPlay template
app cannot be driven by the existing player. Delivering Option A would require a real audio
pipeline (`AVPlayer` fed an actual audio stream), which for YouTube means stream extraction
— against YouTube's Terms of Service and technically fragile. **Option A is therefore not
reachable with the current playback architecture.** The viable paths are now: replace the
playback engine (legal/ToS problem), or scope CarPlay out (report Option B).

### Follow-up (2026-08-29)

**Metadata reaches MediaRemote, not just the app.** Confirmed from CarTube's own process
while audio played:

```
CarTube: (MediaPlayer) [com.apple.amp.mediaplayer:RemoteControl] NPIC: setNowPlayingInfo: sending to MediaRemote
```

MediaRemote is the system service CarPlay's Now Playing UI reads from, so the metadata
path is real, not merely a local write.

**Refinement to the pause finding.** Playback ran 334s continuously (9s → 343s) throughout
a CarPlay session in which the CarPlay window was clicked repeatedly. That is not a
contradiction: interacting with the Simulator's CarPlay window does not background the iOS
app, so the phone scene stayed foreground. The pause is triggered by *genuine*
backgrounding (home press / lock), which was re-measured and holds. This is the normal case
in a car — phone locked, CarPlay driving the display — so the blocker stands, and it also
explains why Now Playing could never work in practice: the moment CarPlay becomes the
surface the user looks at, the phone-side webview pauses and there is nothing playing to
report.

**CarPlay's built-in Now Playing screen stayed empty**, opened while the video was actively
playing and publishing to MediaRemote. Two explanations could not be disambiguated: the
Now Playing icon may be inert because CarTube is not a registered CarPlay audio app (no
working template scene), or the click did not register. The coordinate mapping was
calibrated by clicking Messages on the same grid row, which launched correctly and appeared
in the logs as `CarPlayTemplateUIHost:com.apple.MobileSMS`, so the click should have
landed — suggestive of the first explanation, but not proof.

**PiP avenue: closed.** `allowsPictureInPictureMediaPlayback = true` set explicitly on the
spike webview (production sets it `false` at `CarPlayViewController.swift:59`), rebuilt and
re-measured:

| Measurement | Value |
| --- | --- |
| Position when backgrounded | ~15s |
| Time backgrounded | ~60s |
| Predicted if PiP sustained playback | ~75s |
| **Observed on foreground** | **17s, `paused`** |

No PiP window appeared on backgrounding. Simulator PiP fidelity is limited, so this
measurement alone is weaker evidence than the main background test — but the avenue fails
on design grounds independent of it: PiP requires a visible PiP window on the phone, and a
locked phone in a car dismisses it. There is also no public API to start PiP programmatically
for WKWebView *web* content. PiP is therefore not a background-audio strategy for a car app.

**Option A is now closed with the webview as the playback engine.** Every route to keeping
`WKWebView` audio alive while backgrounded has been tested or ruled out on design grounds.

## Unresolved questions

1. Does a device build signed with the real CarPlay profile behave differently? Routing
   through `CarPlayTemplateUIHost` looks like OS-level scene resolution rather than
   entitlement-gated behaviour, but this was not tested on hardware.
2. Is audio-only on the car screen acceptable for the product, given the value proposition
   was video on the head unit? This is a product decision, not a technical one.
3. ~~Can the WKWebView drive Now Playing metadata?~~ **Answered: yes** — see the spike
   result above. Metadata extraction via JS works.
4. ~~Does backgrounded WKWebView audio survive?~~ **Answered: no** — playback pauses
   immediately on background. This invalidates Option A as designed. Remaining question is
   whether a device behaves differently (unlikely) and, if not, whether the product can
   accept replacing the playback engine or must scope CarPlay out.
6. Do `MPRemoteCommandCenter` handlers actually reach the webview from Control Center? Not
   tested — the simulator's Control Center would not render. Moot unless a viable playback
   engine is found.
7. ~~Would PiP keep webview audio alive in the background?~~ **Answered: no** — see the
   2026-08-29 follow-up. Closed on both measurement and design grounds.
8. Is CarPlay's built-in Now Playing inert for an app with no registered CarPlay audio
   scene? Suggested but not proven. Only resolvable once a working template scene exists,
   so it is downstream of the product decision, not a blocker on it.
5. Was the CarPlay surface ever functional on a shipping iOS version, or is this a
   pre-existing defect rather than an iOS 26 regression? No prior working capture exists.
