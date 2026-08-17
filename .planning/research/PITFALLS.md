# Pitfalls Research

**Domain:** App Store compliance, private-API remediation, CarPlay entitlements, and voice search for an iOS webview-video-on-CarPlay app (CarTube)
**Researched:** 2026-08-17
**Confidence:** HIGH (Apple/Google official documents verified directly; swizzling and speech-UX details are codebase analysis + established platform knowledge, MEDIUM)

---

## Critical Pitfalls

### Pitfall 1: Treating the CarPlay entitlement as a late integration task instead of a day-1 external dependency

**What goes wrong:**
The team builds all the App Store, private-API, and voice-search work first, then applies for the CarPlay entitlement near the end — and the application sits in Apple's queue while the milestone is otherwise complete. Worse: under standard code signing, **without a CarPlay entitlement the app's CarPlay scene never connects at all** — iOS will not launch a `UIWindowSceneSessionRoleCarPlay` scene for an app whose provisioning profile lacks the CarPlay capability. The current app only works because TrollStore grants arbitrary entitlements (`ipabuild.sh` injects them with `ldid`). Everything CarPlay-visible in this app is serialized behind Apple approving the request.

**Why it happens:**
The entitlement feels like "configuration" rather than development work, so it gets scheduled alongside provisioning/setup at the end. Developers also don't realize that even the **CarPlay Simulator and Xcode require a provisioning profile that supports CarPlay** (confirmed in the June 2026 CarPlay Developer Guide, "Entitlements" section) — so it blocks not just release but local development of the CarPlay surface.

**How to avoid:**
- Submit the entitlement request at developer.apple.com/carplay in the **first phase** of the milestone, before any code work. The request requires agreeing to the CarPlay Entitlement Addendum and naming the category.
- Keep a written record of the application date; Apple publishes no SLA (community-reported timelines range from days to months).
- Until granted, develop against the CarPlay surface **behind a protocol/abstraction** (e.g., a `VideoSurface` protocol with a phone-screen mock renderer) so voice search, URL parsing, and search backend phases make progress without a CarPlay scene.
- After approval: regenerate the App ID's CarPlay capability, create a **new provisioning profile**, import it, and disable automatic signing in Xcode (the guide explicitly instructs turning off "Automatically manage signing"). Plan this as a concrete step, not an afterthought.

**Warning signs:**
- Roadmap phases show "apply for entitlement" anywhere but the first phase.
- Any phase's acceptance criteria requires running the CarPlay scene before the entitlement phase completes.
- The Xcode project still has "Automatically manage signing" on with the old TrollStore-style entitlements file.

**Phase to address:**
Phase 1 (kickoff/infrastructure phase) — application submitted; all later phases designed so they're testable without the entitlement.

---

### Pitfall 2: Requesting the wrong CarPlay entitlement category (audio vs. the new video category)

**What goes wrong:**
The milestone plans say "Apple's CarPlay audio/media entitlement," but CarTube's CarPlay surface is a **video** webview used **while driving**. As of the June 2026 CarPlay Developer Guide there are two plausible categories and both clash with the app's design:
- **CarPlay audio apps** must be "designed primarily to provide audio playback services."
- **CarPlay video apps** must (a) be designed primarily for video playback, and (b) **support AirPlay video streaming**, and the category exists to let people watch **when parked**.

Apple reviews the entitlement request against the category's criteria. An app that renders full YouTube video in a raw `UIWindow`/`WKWebView` while the vehicle is in motion matches neither category honestly. The mismatch surfaces twice: at entitlement review (denial or re-review) and at App Review (CarPlay guideline 1: "Your CarPlay app must be designed primarily to provide the specified feature"). Additionally, the guide states once you publish with CarPlay support you "cannot selectively show or hide CarPlay for certain people" — no staged rollout of the risky surface.

**Why it happens:**
The audio category is the historical path third-party YouTube/music clients used, and the project predates the video category. Choosing a category that doesn't match the actual surface is the kind of optimistic box-ticking that reads fine in a plan and fails in review.

**How to avoid:**
- Decide the category deliberately and document the rationale as a Key Decision. Given the parked-only constraint of the video category conflicts with the core "driver opens any video" value, **audio** remains the honest-fitting category (the app does provide audio playback of YouTube content); note explicitly that the video surface carries residual rejection risk under the audio category.
- If applying for audio, make sure the app *actually* provides audio playback services as a primary function (it does — YouTube audio through the car's system), and be ready to explain that in the entitlement request and review notes.
- Do not claim the video category unless the app genuinely supports AirPlay video and is prepared for parked-only gating — which contradicts this milestone's Core Value.

**Warning signs:**
- Entitlement request text describes "YouTube video on CarPlay screens" under an audio-category application.
- Any plan to detect vehicle motion / parked state to satisfy video-category rules appears in scope.

**Phase to address:**
Phase 1 (entitlement application) — category chosen and justified; Phase for submission — review notes consistent with the chosen category.

---

### Pitfall 3: Automated App Review static scans find private-API residue that "removal" missed

**What goes wrong:**
Guideline 2.5.1 (public APIs only) is enforced first by automated binary scans. The team removes the *behavior* (e.g., stops calling brightness functions) but the *markers* survive in the binary and the submission is rejected in minutes. CarTube's binary currently contains every category of detectable marker:

| Marker type | Present in CarTube | Detection surface |
|---|---|---|
| `dlsym` name strings | `SBSSpringBoardServerPort`, `SBGetScreenLockStatus`, `BKSDisplayBrightnessGetCurrent`, `BKSDisplayBrightnessSet`, `BKSDisplayBrightnessSetAutoBrightnessEnabled` (`CarTube/Util/Utilities.swift:67-143`) | Plaintext strings in `__cstring` |
| Private framework path strings | `/System/Library/PrivateFrameworks/SpringBoardServices.framework/...`, `BackBoardServices.framework/...`, `MediaRemote.framework` (`Utilities.swift:62,80,96,138,151`) | Plaintext paths |
| Private selector references | `_hasSleepDisabler`, `_simulateTextEntered` (`Headers/WebView+Additions.h`), `_isCarScreen` (`Hooks/Headers/UIScreen+_isCarScreen.h`), `_UIStaticScrollBar`, `UITextEffectsWindow` (`Hooks/Headers/`) | Objective-C selector tables; even Swift callers emit them |
| Private C-function names | `MRMediaRemoteGetNowPlayingInfo` via `CFBundleGetFunctionPointerForName` (`Utilities.swift:152`) | String + dynamic-link indirection does **not** hide it |
| Private dictionary keys | `kMRMediaRemoteNowPlayingInfoTitle`, `kMRMediaRemoteNowPlayingInfoClientPropertiesData`, etc. (`Utilities.swift:160-174`) | Plaintext strings |
| System notification names | `com.apple.springboard.hasBlankedScreen`, `com.apple.springboard.lockstate` (`Utilities.swift:35,48`) | Plaintext strings |
| Entitlement keys | `platform-application`, `com.apple.private.security.no-container`, `com.apple.private.security.container-manager`, `com.apple.backboard.displaybrightness` (`CarTube.entitlements`) | Signature/entitlements — instant flags under standard signing |
| Runtime swizzling | `AutoHookImplementor.m` (`class_copyMethodList` + `class_replaceMethod` on `UIWindow`), hook classes `HOOKUIWindow`, `HOOK_UIStaticScrollBar` | Method exchange patterns + `hook_`/`original_` selector names in the ObjC metadata |
| Reading outside the container | `CFPreferencesCopyAppValue` against `com.apple.springboard` / `com.apple.backboardd` (`Utilities.swift:106-129`) | Guideline 2.5.2 violation (reads/writes outside app container) — behavioral, not just static |

**Why it happens:**
The obvious fix (delete the calling code) doesn't remove strings compiled into other translation units; the headers declaring private categories (`Headers/` folder) and the `.entitlements` file keep emitting selectors even if unused; and "we'll keep the milder hooks" (scroll-bar hiding, window resize) feels safe but `hook_setRootViewController` on `UIWindow` and hooking `_UIStaticScrollBar` are exactly the swizzling patterns scanners and reviewers recognize.

**How to avoid:**
- Build a **private-API audit checklist phase** that removes, not just disables: delete `Headers/` private category declarations, delete hook classes that reference private classes, delete the entitlements file's private keys, remove the `import Dynamic` MediaRemote path entirely, and remove `notify_` springboard listeners.
- Add a **binary-scanning gate** to the build pipeline: run `strings` on the built binary (and on the `.appex`) for `SB[A-Z]`, `BKS`, `MRMediaRemote`, `_hasSleepDisabler`, `_simulateTextEntered`, `_UIStaticScrollBar`, `PrivateFrameworks/` and fail the build on hits. Cheap, catches regressions before upload.
- Decide explicitly, per remaining hook, whether it survives — the project decision is "keep remaining hooks," but write down *which* hooks remain and accept that each one is a 2.5.1 rejection candidate. `HideScrollBar` (hooks a private `_UIStaticScrollBar` class) is the riskiest survivor; `AutoResize` (hooks public `UIWindow.setRootViewController`) is milder but still swizzling on a UIKit system class.
- Apply API-key/API-restriction hygiene on the share extension too — App Review scans the whole bundle including `.appex` targets.

**Warning signs:**
- A "remove private APIs" phase has no binary-level verification step (strings/nm scan).
- `CarTube.entitlements` still contains `platform-application` or `no-container` after signing changes.
- Private-symbol declarations remain in `Headers/` "just in case."

**Phase to address:**
Phase 2 (private API audit). The strings-scan gate should be created here and run in every subsequent phase's CI/build.

---

### Pitfall 4: Removing MediaRemote/brightness breaks the launch flow and silently kills features that depend on them

**What goes wrong:**
The riskiest private APIs are load-bearing in non-obvious places:
- `getNowPlaying()` is called from `CarPlayViewController.viewDidLoad` → `CarPlaySingleton.checkIfYouTubePlaying()` (`CarPlayViewController.swift:31`, `CarPlaySingleton.swift:130-141`). Ripping out MediaRemote without touching this chain leaves a dangling launch path; the current failure path (`completion(.failure)` → `print`) is benign, but only if the function still exists and returns — deleting the whole `Dynamic` package dependency without stubbing the call breaks compilation at minimum, and a half-removed version can hang launch (the C function pointer lookup is synchronous).
- `setLowBrightness`/`restoreBrightness`/`setAutoBrightness`/`isAutoBrightnessEnabled`/`getSettingsBrightness` power the **LockScreenDimming** feature (`CarPlaySingleton.swift:50-67`, `CarPlaySceneDelegate.swift:29-44`). Removing BackBoardServices symbols removes the feature; leaving the calls in with no symbols returns garbage or crashes (`dlsym` returning NULL is force-cast via `unsafeBitCast` at `Utilities.swift:68,84,99,141` — a NULL function pointer called at runtime is a crash, not an error).
- `registerForScreenOffNotification`/`isScreenLocked` use springboard `notify` keys and `SBGetScreenLockStatus` — they gate the screen-off warning label and dim-restore logic in the scene delegate.
- The **now-playing takeover** (the "You were watching this on the YouTube app" alert) is a headline existing feature. Its removal is a user-visible feature removal, not just a code cleanup, and needs its own decision + settings-cleanup (the toggle that suppresses it, `askAboutLastPlaying`, becomes dead).

**Why it happens:**
Private-API removal is planned as a binary-safety exercise, but these calls sit inside feature logic and lifecycle paths. "Delete Utilities.swift functions" is a 10-minute task that breaks three features and one launch sequence if the callers aren't redesigned.

**How to avoid:**
- In the private-API phase, map every removed symbol to its callers first (the list above is the map for this codebase) and make an explicit keep/kill/graceful-degrade decision per feature: now-playing takeover → remove feature + alert chain; lock-screen dimming → remove feature or replace with a public-API approximation; screen-off detection → remove or degrade to no-op.
- Replace `unsafeBitCast`-of-`dlsym` patterns with `if let` guards during any interim state so a missing symbol degrades instead of trapping.
- Add a smoke test (manual checklist or unit test on the singleton) that CarPlay scene connect → home page load still works with every private path neutered.
- Update Settings UI in the same phase so toggles for removed features disappear together — the milestone explicitly must not leave dead toggles (string-literal UserDefaults keys across `CarTubeApp.swift`/`Settings.swift`/`CarPlayViewController.swift` make this easy to miss one site).

**Warning signs:**
- A diff removes `Utilities.swift` functions but doesn't touch `CarPlaySceneDelegate.swift` or `checkIfYouTubePlaying`.
- Settings still shows "Lock Screen Dimming" after the brightness symbols are gone.
- The share extension still parses YouTube URLs but the app-side parser changed (duplicated parser drift — see CONCERNS).

**Phase to address:**
Phase 2 (private API audit) — with the feature-decision list resolved before code changes start.

---

### Pitfall 5: Raising the deployment target and rebuilding against a modern SDK silently disables the swizzling hooks

**What goes wrong:**
The plan raises iOS 14.0 → a current version and builds with a modern SDK. The `AutoHook` machinery (`AutoHookImplementor.m:95-133`) installs hooks only when `method_getTypeEncoding` of hook and target match **exactly** (`strcmp` on type encodings), and logs-and-skips on mismatch. Type encodings for UIKit methods have shifted across iOS versions; behavior of `UIWindow.setRootViewController` in CarPlay scenes, `_UIStaticScrollBar`'s existence, `UIScreen._isCarScreen`, and `WKWebView._simulateTextEntered` are all version-dependent private behaviors. The realistic outcome is: build succeeds, hooks silently don't install (or install against changed behavior), and the CarPlay layout is broken — oversized status-bar overlap, the buggy scroll indicator returns, or keyboard input simulation dies — discovered only on a real head unit. Compounding this, the keyboard path (`sendInput` → `_simulateTextEntered`, and backspace via `document.execCommand('delete')`) is the foundation the new **on-CarPlay search** UX may want to reuse.

**Why it happens:**
Swizzling failures are invisible by design — `AutoHookImplementor` communicates via `NSLog` only. The current compatibility window (iOS 14–15.4.1) was validated manually; nobody has ever run these hooks on modern iOS. There are no tests, so "it compiled" reads as "it works."

**How to avoid:**
- Treat the deployment-target raise as a **behavioral re-validation phase**, not a build-settings change: after raising, run the app against the CarPlay Simulator (needs the entitlement-era profile — see Pitfall 1) and a physical CarPlay head unit if available, checking each hook's visible effect (status-bar safe-area resize, scroll-bar hidden, keyboard input round-trip).
- Add a debug assertion screen (extend the existing `Debug.swift`) that verifies hooks installed: after `+load`, check `class_getInstanceMethod(UIWindow, sel_registerName("original_setRootViewController:")) != nil` and surface the AutoHook log lines in-app. This turns silent failure into a visible checklist item.
- Re-check `CustomLayout.js`/`AdBlocker.js` injection after the raise at the same time — WebKit version changes affect both the injection points and the YouTube DOM assumptions (already flagged in CONCERNS).
- If `_simulateTextEntered` is gone on the target iOS version, the keyboard-simulation search path is dead; the voice-search and API-search work then becomes the replacement input path — sequence the search phase so it doesn't depend on a hook that may not survive.

**Warning signs:**
- Deployment-target raise is a checkbox in a build-modernization task with no on-device verification step.
- Nobody has run the app on the new minimum iOS version with a connected CarPlay session.
- Keyboard input still routes through `_simulateTextEntered` with no fallback.

**Phase to address:**
Phase 2 (deployment-target raise), re-verified in the final CarPlay integration phase on the real target OS.

---

### Pitfall 6: Embedding the YouTube Data API key in the client binary of an open-source project

**What goes wrong:**
The API key ships inside the IPA. Anyone (or any scanner) runs `strings CarTube.app/CarTube | grep AIza` and gets a working YouTube Data API key. Google's policy is explicit and this project is in the worst possible position for it: YouTube API Services Developer Policies **III.D.1.c** — credentials must not be shared with third parties **or embedded in open source projects**; CarTube is a fork of a public GitHub project (README, license, and release-check code in `CarTubeApp.swift` all point at public repos). A leaked key means quota theft and near-certain revocation of the API project, which kills search for every user until a new key ships through App Review.

**Why it happens:**
Client-side search with a free API key is the zero-infrastructure path, and "restrict the key to my bundle ID" feels like protection. It isn't: bundle-ID restriction (or API restriction to the YouTube Data API) limits *abuse surface* but does not hide the key string; a stolen key used from any process that spoofs the bundle ID, or just hammered through any allowed-API vector, still burns your quota.

**How to avoid:**
- Accept that the key is public-by-design and engineer for rotation: load the key from a **remote config endpoint or build-time xcconfig injected outside the repo** (never committed), so a leak is survivable by rotating the remote value without an app update. Google's own best-practices doc says do not embed keys in code and rotate periodically.
- Apply both key restrictions in the Google Cloud Console regardless: restrict to the **YouTube Data API v3** only, and add the iOS app restriction (bundle IDs of app + share extension).
- Set up quota monitoring/alerting on the Google Cloud project (quota errors are 403s with `rateLimitExceeded`/`quotaExceeded` reasons) and make the client degrade gracefully to the existing YouTube-URL/search-page path (the webview `YT_SEARCH` load already exists — keep it as the fallback input mode).
- Decide up front whether the repo stays public. If yes, the key never lives in the repo, not even briefly in a branch.

**Warning signs:**
- An API key literal appears in any committed Swift/plist/xcconfig file or in the Xcode project file.
- Search feature has no fallback when the API returns 403.
- No rotation story ("we'd ship an update" is not a rotation story).

**Phase to address:**
Phase 3 (search backend) — key delivery mechanism is a design requirement of the phase, not a hardening afterthought.

---

### Pitfall 7: Blowing the YouTube `search.list` quota — 100 searches per day, total, for all users

**What goes wrong:**
The milestone's stated assumption ("~10k unit/day default quota, a search costs 100 units" → ~100 searches/day) matches the **old** quota model. The current quota calculator (verified on Google's docs, updated 2026-06) is structured differently and tighter in practice:
- Default allocation: **100 `search.list` calls per day in a dedicated bucket**, 100 `videos.insert`/day, and 10,000 units/day combined *for the other endpoints*.
- Every request — even an invalid one — costs at least one unit, and **each additional page of results from a `search.list` call costs a full additional call** from that bucket.
- Daily quotas reset at midnight Pacific Time.

One hundred searches per day is the **entire TestFlight audience combined**. A single tester's first session with voice search can eat a double-digit chunk. A public beta exhausts it in minutes, and every user sees errors until midnight PT. Worse, the escape hatch — a quota extension — requires passing an **API Compliance Audit** (YouTube policy III.D.3), and this app's defining features (ad blocking, SponsorBlock, player modification — see Pitfall 8) are exactly what the audit examines. The extension path is effectively closed.

**Why it happens:**
Quota folklore ("10k units, searches cost 100") circulates from the pre-bucket era; nobody re-reads the quota page when planning a search feature, and dev/testing usage during the milestone itself consumes the same shared bucket as production.

**How to avoid:**
- Plan the search phase around a hard budget of **~100 searches/day app-wide**: cache aggressively, fetch one page (`maxResults` sized for one screen), never auto-refresh, debounce voice-triggered searches, and require explicit tap-to-search rather than search-as-you-type.
- Route around `search.list` where possible: resolve a pasted URL/ID without any API call (existing parser); consider `videos.list` (draws from the general 10k pool, not the search bucket) for metadata enrichment of a chosen video.
- Implement quota-aware UX: on 403 quota errors, show "search limit reached — enter a link or use on-screen search" and fall back to the webview search page (`YT_SEARCH + query`), which costs zero quota and already works.
- Keep dev testing on a **separate Google Cloud project/key** from the shipping key, and keep the shipping key's project off anything automated.
- Document the quota ceiling in the phase plan so roadmap acceptance criteria don't unknowingly assume unbounded search.

**Warning signs:**
- Search phase plan has no per-user or global rate limiting.
- Development builds and the shipping key share one project.
- Any design that searches on every keystroke, wake, or CarPlay reconnect.

**Phase to address:**
Phase 3 (search backend) — quota strategy is an acceptance criterion; fallback path exercised in tests.

---

### Pitfall 8: The ad-blocking/SponsorBlock scripts and the YouTube Data API are on a collision course (ToS + key revocation)

**What goes wrong:**
Registering an API key means accepting the YouTube API Services Terms and Developer Policies for the *whole client*. Those policies directly prohibit what CarTube's vendored scripts do:
- **III.I.5:** must not "modify, interfere with, replace, or otherwise block advertisements" — `AdBlocker.js`.
- **III.I.6:** must not "modify, build upon, or block any portion or functionality of a YouTube player" — `SponsorBlock.js` (skips segments), `AgeRestrictBypass.js` (circumvention), `CustomLayout.js` (rebuilds the UI).
- **III.F.1:** must not "change or interfere with user interfaces in YouTube Applications" without prior written approval.
- **III.I.1:** must not create a substitute for YouTube Applications — an app whose core is "the YouTube app, but on CarPlay with ads skipped" is adjacent to this line.
- **III.C.5 / III.F.2:** search results must not be modified/merged, and YouTube branding/attribution must be shown where YouTube content is displayed — the new API-driven results list must carry YouTube attribution.

So the milestone as scoped simultaneously (a) uses YouTube's API under its policies and (b) ships a player experience those policies prohibit. The realistic failure is not an immediate legal notice — it's key revocation or audit failure at the worst time (after launch, when users depend on search), plus App Review 5.2.2/5.2.3 exposure (apps displaying third-party content need the service's permission; streaming that violates third-party ToS is rejectable — 5.2.3 names YouTube explicitly). This risk is adjacent to the accepted webview-video rejection risk, but it is *severable*: search-with-API is an additive feature the project is choosing to add on top.

**Why it happens:**
The App Review risk was accepted as a package ("webview video"), and the API-side policy risk looks like the same package — but adding the Data API creates a new, attributable identity (the API project) that YouTube can act against independently of Apple.

**How to avoid:**
- Make this a documented Key Decision with eyes open: either accept revocation risk for the search feature with a fallback (Pitfall 7's webview-search path), or keep API search behind a setting/default-off.
- Keep the two worlds as separable as possible in code: the search backend must be a swappable module (protocol-based client) so a revoked key degrades to webview search without an emergency rewrite.
- In the results list, show YouTube attribution/branding per III.F.2 and never re-order or interleave non-YouTube results (III.C.5).
- Ensure the app links YouTube's ToS and has a privacy policy covering API usage (III.A.1–2) — also an App Review 5.1.1(i) requirement.
- Do not compound the exposure: no downloading/caching of content (III.E.1), which the app doesn't do — keep it that way.

**Warning signs:**
- Search phase ships with no attribution on results.
- "Ad blocking" is marketed in App Store metadata while the Data API key is registered — the pairing an auditor/reviewer notices first.
- No documented decision acknowledging the policy collision.

**Phase to address:**
Phase 3 (search backend) for the decision and fallback; final submission phase for metadata honesty (don't advertise ad-blocking in App Store copy — see UX/anti-feature guidance below).

---

### Pitfall 9: Speech-recognition permission prompts fired at drive time (and other CarPlay voice-UX violations)

**What goes wrong:**
Push-to-talk on the CarPlay screen uses `SFSpeechRecognizer`, which needs **two** authorizations — microphone (`AVAudioSession`/`NSMicrophoneUsageDescription`) and speech recognition (`NSSpeechRecognitionUsageDescription`, via `SFSpeechRecognizer.requestAuthorization`). Both system prompts render **on the iPhone**, not the CarPlay screen, and cannot be triggered from or presented in a CarPlay scene. If the first prompt happens when the driver taps the mic button in the car, the flow dead-ends against the CarPlay guideline "Never instruct people to pick up their iPhone to perform a task" and "All CarPlay flows must be possible without interacting with iPhone." A missing purpose string isn't a graceful error either — the app **crashes** on the permission request. Siri-driven search adds a third setup surface (users must enable the shortcut/donation).

Additional traps: default (server-based) recognition has a ~1-minute audio-segment limit and requires network — flaky in a moving car; `requiresOnDeviceRecognition` avoids both but is locale/device-gated; holding an audio session open continuously violates the voice-app guideline to "only hold an audio session open when voice features are actively being used."

**Why it happens:**
Permission flows are designed on the phone app where prompts are visible; nobody drives the first-run path in an actual car. The Info.plist keys are also easy to forget because the phone app historically requested nothing.

**How to avoid:**
- Add both purpose strings (`NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`) to the **app target's Info.plist** in the same commit that adds the first speech code; missing keys are crash-on-request.
- Do a **first-run onboarding on the iPhone** (the app already has a phone shell with HowTo screens — extend it): request speech + mic authorization once, before the user ever connects CarPlay. Gate the CarPlay mic button's visibility on authorization state; if not determined/denied, show "set up voice search on your iPhone" (allowed — informing about a condition is permitted; instructing them to manipulate the phone mid-drive is not).
- Use push-to-talk with **explicit visual indication while listening** (guideline 2.5.14 requires clear indication when recording user activity) — a highlighted button state plus immediate auto-stop on silence.
- Prefer on-device recognition where available; fall back to server recognition; degrade to the on-screen keyboard search when neither is authorized.
- For Siri search ("Search YouTube for X"): implement as an App Intent / custom intent that resolves to the same search path; register vocabulary that pertains to the app (2.5.11: don't sign up for intents users wouldn't expect from the stated functionality).

**Warning signs:**
- Any code path calls `SFSpeechRecognizer.requestAuthorization` from the CarPlay scene/view controller.
- Info.plist has one of the two purpose strings.
- The mic button is visible regardless of permission state.

**Phase to address:**
Phase 4 (voice search) — permission onboarding and degraded states are acceptance criteria, not polish.

---

### Pitfall 10: The webview-video surface itself — knowing exactly which rejections it triggers and pre-planning the response

**What goes wrong:**
The user accepted rejection risk, but "high risk" is underspecified for planning. The concrete rejection vectors for this surface, in the order they'll be encountered:
1. **CarPlay template violations** (CarPlay guidelines 7 + category rules): apps must use CarPlay framework templates for their intended purpose. A raw `UIWindow` + `WKWebView` scene manifest (`Info.plist` `UIWindowSceneSessionRoleCarPlay` with `CarPlaySceneDelegate` installing `CarPlayViewController`) is a non-template UI rendering video while driving. The 2026 video category exists precisely for parked video and requires AirPlay-video support — an in-motion webview matches no sanctioned shape.
2. **Guideline 4.2 (minimum functionality / "repackaged website")**: the CarPlay experience *is* the YouTube mobile site (enhanced by injected JS). This is the single most common rejection for webview-wrapper apps, independent of CarPlay.
3. **Guideline 5.2.2/5.2.3**: displaying YouTube content without permission/ToS compliance; 5.2.3 explicitly warns streaming may violate the source's ToS.
4. **Guideline 2.3.1**: hidden/undocumented functionality — review notes must describe the webview-video mechanism specifically; generic notes are rejected.

**Why it happens:**
The accepted-risk framing can drift into "nothing to do here." In practice there's a big difference between a submission with a coherent review-notes strategy and a bare upload — both may fail, but one produces an actionable rejection and the other produces a rejection that also burns reviewer goodwill on the developer account.

**How to avoid:**
- Since "done = TestFlight-ready upload" and the user owns submission: write the **App Review notes** as a deliverable of the final phase — specific description of what the CarPlay surface does, why (driver access), and honest framing under the chosen entitlement category (Pitfall 2).
- Prior to that, reduce the *stacked* risk: fix everything else (private APIs, metadata, crashes) so the webview surface is the *only* rejection reason. A submission that fails on three grounds is much harder to iterate on.
- Metadata honesty (2.3): App Store copy should describe "YouTube player for CarPlay" without advertising ad-blocking/age-bypass (which reads as ToS-violation marketing to reviewers and to YouTube's brand-protection teams — 2.3.7/5.2.1 trademark/branding rules also apply to the app name and icon).
- Prepare the fallback ladder as a documented contingency: webview survives → if rejected on video-while-driving, a parked-gate (detect CarPlay driving state) or audio-UI fallback becomes the fast-follow submission; the search/voice work is reusable under every rung of the ladder. This is the practical payoff of keeping search/voice decoupled from the webview surface.

**Warning signs:**
- Final phase has no review-notes deliverable.
- App Store metadata drafts mention ad blocking, SponsorBlock, or age-restriction bypass.
- Search/voice features are architecturally tangled with the webview controller (no seam to fall back behind).

**Phase to address:**
Final submission phase (review notes, metadata review); architectural decoupling started in Phase 2/3 (protocols around the video surface and search client).

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Keeping "mild" swizzling hooks (AutoResize, HideScrollBar) | CarPlay layout stays fixed without template work | Standing 2.5.1 rejection candidate; silently breaks on iOS updates (Pitfall 5) | This milestone (explicit decision), with per-hook risk written down and a debug hook-verification screen |
| Shipping settings via `exit(0)` ("exit to apply") | Avoids rebuilding WKWebView config; existing contract | `exit()` in a shipping app is documented by Apple as forbidden ("Do not use this function in shipping applications"); `UIControl().sendAction(#selector(URLSessionTask.suspend)...)` is a known review flag | Never in the App Store build — replace with in-place webview/config recreation during the private-API phase |
| YouTube Data API called directly from the client | No backend infra | Key exposure (Pitfall 6), quota cliff (Pitfall 7), no audit path (Pitfall 8) | TestFlight-only with remote-config key + rotation; never with a committed key |
| Reusing the webview YouTube search page as the search backend | Zero quota, zero new code | No structured results, DOM-fragile, no attribution control | As the **fallback** path alongside API search — actually required by the quota strategy |
| Keeping the duplicated URL parser in app + extension | No refactor needed mid-milestone | Drift between targets when voice/search adds new URL forms | Acceptable this milestone if voice/Siri handoff routes through the same parser entry point in the app target |
| String-literal UserDefaults keys while adding voice/search settings | Fastest path | One missed site = feature silently off (existing CONCERNS risk, now with more features) | Acceptable only if new settings keys are defined as constants in the same PR that first uses them |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| CarPlay entitlement | Applying late; assuming simulator works without it; leaving automatic signing on | Apply in phase 1; new provisioning profile after grant; disable automatic signing; entitlement is account/App-ID-level and category-specific |
| YouTube Data API v3 | Assuming old quota model (100-unit searches); unrestricted key; testing on the shipping project | Dedicated 100-calls/day `search.list` bucket — plan around it; API + bundle-ID restrictions; separate dev project; one API project per client per policy III.D.1.c |
| App Review submission | Bare upload; generic notes; metadata advertising ad-block | Specific review notes describing the CarPlay surface; metadata that doesn't advertise ToS-violating features; fix all non-video issues first so webview is the only rejection reason |
| SFSpeechRecognizer | Requesting permission from CarPlay scene; missing Info.plist keys; server-based recognition with 1-min limit | Onboard on iPhone first-run; both purpose strings committed with first code; on-device recognition preferred; push-to-talk with visible listening state |
| SiriKit / App Intents | Registering broad intents or vocabulary users don't expect (2.5.11) | One narrowly-scoped search intent; app-specific vocabulary; resolve directly to results without marketing interstitials |
| Share extension | Forgetting the extension binary in the private-API scan; extension displays ads/marketing (4.4 prohibits) | Run the strings-scan gate on the `.appex` too; keep extension minimal and functional |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Synchronous script loading in `viewDidLoad` (`String(contentsOfFile:)` on main thread) | Slow CarPlay scene connect; watchdog risk on cold launch in the car | Preload/cache script strings; async load before scene connect; measure with Instruments | First launch / reconnect cycles; worsens as scripts grow |
| Second hidden WKWebView for NoSleep | Doubled WebKit memory + process overhead on modern iOS | Replace with public `UIScreen`/idle-timer strategy once deployment target is raised; keep NoSleep.js as fallback only if needed | Any modern-iOS run; memory pressure in the car (hot environment) |
| Search results list rendering in the webview surface | Each render re-navigates or re-injects scripts | Render results in a native overlay/list (UIKit) over the webview; keep webview for playback only | Immediately with API search — do not implement results as DOM injection |
| Speech recognition on server model in a moving car | Recognition timeouts, 1-minute truncation, data-usage complaints | `requiresOnDeviceRecognition` where supported; short push-to-talk windows | First real-world drive test |
| Quota-exhaustion retry loops | App hammers API on 403s, burning the 1-unit-per-request floor and possibly triggering abuse detection | Single retry with backoff; cache last results; hard-stop on quota errors with fallback UI | Public TestFlight, day one |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| API key committed to repo or embedded in binary | Key theft → quota theft → revocation kills search fleet-wide | Remote-config/build-time key injection; never in source; restrictions + rotation plan (Pitfall 6) |
| Keeping TrollStore-era entitlements in any signing config | `platform-application`/`no-container` are instant rejection markers and provisioning failures under standard signing | Delete private keys from entitlements; standard App Store entitlements file contains only granted capabilities (e.g., CarPlay key once approved) |
| Unvalidated GitHub update-check response rendered in an alert (existing `CarTubeApp.swift` issue) | MitM/injected content in an alert; schema drift crashes | Status-code check + typed decoding before display; consider removing the GitHub check for the App Store build |
| Reading general pasteboard on activation (existing ContentView behavior) | iOS paste-permission banner; privacy-policy disclosure burden; reviewer scrutiny | Explicit paste button / `UIPasteControl`-style interaction; declare and disclose accurately |
| Speech audio transmitted to Apple servers (server-based recognition) | Privacy-policy disclosure requirement (5.1.1); user surprise | Prefer on-device recognition; disclose data use accurately in privacy policy and App Store privacy labels |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|------------------|
| Permission prompts at drive time | Driver must grab phone mid-drive — guideline violation and genuine safety issue | iPhone first-run onboarding completes mic+speech authorization before CarPlay ever connects |
| Mic button with no listening indication | User unsure if car is recording (2.5.14 requires clear indication) | Obvious active-listening state; auto-stop on silence; cancel affordance |
| Search results list requiring scroll-and-read while driving | Eyes-off-road time; glanceability failure | One-glance list: title + channel + duration only, ≤ 5-8 items, tap-to-play; anything longer belongs in the phone app |
| Quota error surfacing as a generic failure | Users conclude the app is broken | Explicit "search limit reached, try again after midnight PT — or paste a link" with working link-entry fallback |
| Settings toggles for removed features (now-playing takeover, dimming) | Toggles that do nothing erode trust | Remove toggles in the same phase that removes the features |
| Keeping `exit(0)` settings flow in App Store build | App "quits" after saving settings — looks like a crash to users and reviewers | Recreate webview configuration in place (may finally retire the exit-to-apply contract — flag for explicit user decision since it's a stated behavioral contract) |

## "Looks Done But Isn't" Checklist

- [ ] **Entitlement received:** Often missing the *new provisioning profile + automatic-signing-off* step after Apple grants the capability — verify the CarPlay scene actually connects in the CarPlay Simulator.
- [ ] **Private API removal:** Often missing the binary-level check — verify `strings` on app **and** `.appex` binaries shows none of: `SBSSpringBoard`, `BKSDisplayBrightness`, `MRMediaRemote`, `kMRMediaRemoteNowPlayingInfo`, `_hasSleepDisabler`, `_simulateTextEntered`, `_UIStaticScrollBar`, `PrivateFrameworks/`, `com.apple.springboard.hasBlankedScreen`.
- [ ] **Deployment raise:** Often missing on-CarPlay verification — verify each hook's visible effect (safe-area resize, scroll bar hidden) and keyboard input round-trip on the new minimum iOS.
- [ ] **Launch flow after MediaRemote removal:** Often missing the `viewDidLoad → checkIfYouTubePlaying` chain — verify cold launch to homepage with the entire private path stubbed.
- [ ] **Voice search:** Often missing the denied/not-determined permission states — verify mic button hides/disables and search degrades to keyboard when authorization is refused.
- [ ] **Search backend:** Often missing quota-error handling — verify 403 fallback to webview search and link entry actually works in a build with an exhausted key.
- [ ] **Attribution:** Often missing YouTube attribution on API results — verify results list shows YouTube sourcing per policy III.F.2.
- [ ] **App Store metadata:** Often missing the honest-copy review — verify name/subtitle/description/screenshots don't advertise ad blocking or age bypass.
- [ ] **Share extension:** Often missing from the audit — verify the extension builds, signs, and contains no private markers or leftover TrollStore references.
- [ ] **Submission package:** Often missing review notes — verify notes specifically describe the CarPlay webview surface and the chosen entitlement category.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Entitlement denied or stalled | MEDIUM | Re-apply with corrected category/positioning (audio playback emphasis); meanwhile ship the milestone without the CarPlay scene behind a build flag so TestFlight validation isn't blocked |
| Rejected on 2.5.1 (private API) | LOW–MEDIUM | Rejection notice names the symbol; remove remaining marker, re-run strings gate, resubmit — fastest rejection class to fix |
| Rejected on 4.2/5.2.3 (webview video) | HIGH (accepted risk) | Invoke fallback ladder: parked-gating or audio-UI variant as fast-follow; search/voice assets are reusable — this is why they're kept decoupled |
| YouTube key revoked / quota dead | LOW (if planned) | Rotate remote-config key; if project terminated, fall back to webview search path permanently; do **not** create new accounts to evade (policy III.D.6 prohibits and escalates to account-level bans) |
| Hooks broken by iOS update after raise | MEDIUM | Disable failing hook via kill-switch constant, ship without layout fix; schedule template-based replacement |
| Permission-crash in the field (missing purpose string) | LOW | Add keys and resubmit; detect via crash reports — 2.1 rejection if reviewer hits it first |
| Settings exit(0) flagged in review | MEDIUM | Implement in-place webview config recreation; behavioral-contract change needs user sign-off |

## Pitfall-to-Phase Mapping

Phases below are the logical sequence implied by the milestone requirements; map to actual roadmap phase numbers when created.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| P1 Entitlement as external dependency | Phase 1 — submit request day 1 | Application submitted + dated; later phases testable via phone-side mocks |
| P2 Category mismatch | Phase 1 — category decision documented | Key Decision entry; request text consistent with app reality |
| P3 Private-API residue | Phase 2 — private API audit | `strings` gate passes on app + appex binaries; entitlements file clean |
| P4 Removal breaking launch/features | Phase 2 — feature keep/kill decisions + caller map | Cold-launch smoke test with private paths stubbed; Settings shows no dead toggles |
| P5 Deployment raise breaking hooks | Phase 2 — raise + re-validation | Hook-verification debug screen confirms installs; CarPlay Simulator visual pass on new minimum iOS |
| P6 API key leakage | Phase 3 — search backend design | No key literal in repo/binary strings; remote-config path tested; restrictions set |
| P7 Quota exhaustion | Phase 3 — search backend design | Budgeted-search design review; 403 fallback exercised; dev key separated |
| P8 Ad-block × API ToS collision | Phase 3 — decision + Phase final — metadata | Key Decision documented; attribution on results; fallback module swappable |
| P9 Speech permission UX at drive time | Phase 4 — voice search | First-run onboarding grants both permissions; denied-state degradation tested |
| P10 Webview-video rejection vectors | Phase 2–4 — keep surfaces decoupled; final phase — notes + metadata | Review-notes deliverable exists; metadata honest; fallback ladder documented |

## Sources

- App Review Guidelines (developer.apple.com/app-store/review/guidelines/) — 2.5.1, 2.5.2, 2.3.1, 4.2, 5.1.1, 5.2.2, 5.2.3, 2.5.11, 2.5.14, 4.4 — fetched directly, **HIGH confidence**
- CarPlay Developer Guide, June 2026 (developer.apple.com/download/files/CarPlay-Developer-Guide.pdf) — entitlement process, provisioning, categories incl. video apps (parked-only, AirPlay requirement), guidelines, "cannot selectively show/hide CarPlay" — **HIGH confidence**
- YouTube Data API Quota Calculator (developers.google.com/youtube/v3/determine_quota_cost, updated 2026-06) — `search.list` dedicated 100-calls/day bucket; per-page costs; reset at midnight PT — **HIGH confidence**
- YouTube API Services Developer Policies (developers.google.com/youtube/terms/developer-policies, updated 2026-06-24) — III.D.1.c (credentials/open source), III.D.3 (quota audit), III.E.1 (no downloads), III.F.1–2 (UI interference, branding), III.I.1/5/6/9/14 (substitute apps, ad blocking, player modification, background players, access methods) — **HIGH confidence**
- Google API key best practices (support.google.com/googleapi/answer/6310037) — no embedding in code, restrictions, rotation — **HIGH confidence**
- SFSpeechRecognizer permission flow, purpose strings, on-device recognition limits — Apple docs are JS-rendered; from established platform knowledge — **MEDIUM confidence**
- Swizzling/type-encoding behavior on modern SDKs; AutoHook failure modes — codebase analysis (`AutoHookImplementor.m`, `Hooks/`, `Headers/`) + ObjC runtime knowledge — **MEDIUM confidence**
- Codebase specifics (dlsym symbols, entitlement keys, launch chain, settings flow) — read directly from the repo — **HIGH confidence**

---
*Pitfalls research for: CarTube App Store compliance + CarPlay voice search milestone*
*Researched: 2026-08-17*
