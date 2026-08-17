# Phase 1: External Dependencies & Project Setup - Research

**Researched:** 2026-08-18
**Domain:** Apple CarPlay entitlement application process, Google Cloud API key provisioning/restriction, Xcode build-time secret delivery, project scaffolding for a two-target app
**Confidence:** HIGH (Apple CarPlay Developer Guide 2026-06-08 downloaded and quoted directly; Google Cloud official docs fetched directly; repo facts read from source files this session)

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| INFRA-01 | CarPlay entitlement application submitted under the audio category on day 1, with documented rationale and dated record; new provisioning profile wired when granted | Exact application URL, required steps, addendum, audio-category entitlement key, post-grant provisioning sequence, and "disable automatic signing" step all verified from the official CarPlay Developer Guide (quoted below). Audio-category positioning rationale cross-checked against the guide's category criteria. Wiring runbook defined in Architecture Patterns. |
</phase_requirements>

## Summary

Phase 1 is an orchestration phase around two external clocks (Apple entitlement review, Google key provisioning) plus one in-repo decision (build-time key delivery). The Apple side is fully specified by the official CarPlay Developer Guide (2026-06-08): apply at developer.apple.com/carplay, state the category, agree to the CarPlay Entitlement Addendum, and after grant regenerate the App ID capability + provisioning profile, add `com.apple.developer.carplay-audio` to the entitlements file, and turn off automatic signing. The Google side is fully specified by Google Cloud's key-management docs: create the key in a dedicated project, apply BOTH the API restriction (YouTube Data API v3) and the iOS application restriction (bundle IDs), acknowledging Google's own warning that bundle-ID restriction alone is trivially bypassable. The in-repo key-delivery mechanism resolves to a committed `.xcconfig` template + gitignored real file (or absolute-path include outside the repo) + `$(YOUTUBE_API_KEY)` substitution into Info.plist, read in Swift via `Bundle.main.object(forInfoDictionaryKey:)` — all mechanisms verified against Apple's xcconfig documentation.

Three findings materially shape the plan. First, **the bundle ID decision gates both external clocks**: the CarPlay entitlement attaches to an App ID, and the Google iOS restriction lists bundle IDs — both must reference the final distribution bundle ID, and the repo currently uses the upstream author's reverse-DNS (`com.avangelista.CarTube` in a public fork of `Avangelista/CarTube`). This needs a user decision before submission. Second, **the existing entitlements file cannot coexist with a real provisioning profile**: it contains only TrollStore private keys, so the "wire the grant" branch requires a clean entitlements path — this phase should pre-stage the runbook rather than perform Phase 2's signing cleanup. Third, **both external submissions are human tasks** (Apple ID / Google account login walls) — the plan must model them as `checkpoint:human-verify` tasks with the agent preparing exact click-paths, positioning text, and verification steps.

**Primary recommendation:** Decide the distribution bundle ID first, then submit the Apple entitlement application (audio category, positioning text prepared in-repo) and create the restricted Google key in a dedicated project the same day; wire key delivery as committed `Config/Secrets.xcconfig.example` + gitignored `Secrets.xcconfig` + `$(YOUTUBE_API_KEY)` Info.plist injection; record the entitlement as a dated blocker with a pre-staged grant-wiring runbook.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| CarPlay entitlement application | External (Apple developer portal, human) | Repo: rationale doc + dated record | The request is an Apple-account action behind Apple ID auth; repo's job is the category rationale, submission date, and runbook |
| YouTube API key creation + restrictions | External (Google Cloud Console, human) | Repo: key-delivery mechanism | Key creation lives in Google Cloud Console; repo owns how the key reaches the binary at build time without being committed |
| Build-time secret delivery | Build system (xcconfig → Info.plist) | App target (Swift read) | Xcode's own substitution mechanism — user-defined build setting referenced from Info.plist, baked at build time |
| Entitlement grant wiring (when granted) | Xcode project config (pbxproj, entitlements file) | Apple portal (profile regeneration) | Guide-specified sequence: App ID capability → new profile → import → entitlements key → automatic signing off |
| Blocker tracking | `.planning/STATE.md` | ROADMAP.md notes | Existing GSD state mechanism for dated external blockers |
| XCTest target scaffolding decision | Xcode project (pbxproj) | — | No new runtime tier; a build-target decision whose execution belongs to Phase 3 (SRCH-04) |

## Standard Stack

No third-party packages are installed in this phase. The toolchain is entirely first-party plus already-present local tools:

| Tool | Version (verified this session) | Purpose | Why Standard |
|------|------|---------|--------------|
| Xcode / xcodebuild | 26.3 (Build 17C529) | Builds, scheme inspection, eventual test runs | Only viable toolchain for this project |
| iOS SDK | iphoneos26.2 (from `-showsdks`) | Build target SDK | Ships with installed Xcode |
| gcloud CLI | Google Cloud SDK 579.0.0 (`/opt/homebrew/share/google-cloud-sdk/bin/gcloud`) | Scriptable verification of key existence/restrictions (`gcloud services api-keys list/update --allowed-bundle-ids`) | Official Google CLI; already installed |
| ruby + xcodeproj gem | ruby 3.2.3, xcodeproj 1.28.1 | Scripted pbxproj edits (xcconfig attachment, later test target) | Standard programmatic pbxproj manipulation; already installed |
| xcbeautify | present (`/opt/homebrew/bin/xcbeautify`) | Readable build output for verification commands | Already part of local workflow |

**Installation:** none required.

## Package Legitimacy Audit

No external packages are installed by this phase. Not applicable — no registry lookups needed.

## Architecture Patterns

### System Architecture Diagram

```text
                    ┌────────────────────────────────────────────┐
                    │  Phase 1 (day 1, parallel)                 │
                    └────────────────────────────────────────────┘
  Decision 0: final distribution bundle ID (user)  ── gates everything below
        │
        ├─► [Human checkpoint] Apple developer.apple.com/carplay
        │     audio category + CarPlay Entitlement Addendum
        │     → submission date recorded → dated blocker in STATE.md
        │            │
        │            ▼  (days–months, no SLA)
        │     ┌─ grant lands ──► RUNBOOK: App ID capability → new
        │     │                  provisioning profile → import →
        │     │                  add com.apple.developer.carplay-audio →
        │     │                  automatic signing OFF → verify scene
        │     └─ still pending ─► phases 3–5 proceed on phone-side mocks
        │
        └─► [Human checkpoint] Google Cloud Console (dedicated project)
              enable YouTube Data API v3 → create API key →
              API restriction (YouTube Data API v3) +
              iOS restriction (bundle IDs) → key string handed to
              build-time delivery, NEVER committed
                     │
                     ▼
        Repo-side mechanism (agent-executable):
          Config/Secrets.xcconfig.example  (committed, placeholder)
          Secrets.xcconfig                 (gitignored or outside repo)
              YOUTUBE_API_KEY = AIza...
          project.pbxproj: attach xcconfig as base configuration
          CarTube/Info.plist: YOUTUBE_API_KEY = $(YOUTUBE_API_KEY)
          Swift: Bundle.main.object(forInfoDictionaryKey: "YOUTUBE_API_KEY")
              │
              ▼
        Verification: xcodebuild → plutil -extract on built Info.plist;
        git grep confirms no key material in tracked files
```

### Recommended Project Structure (phase deltas only)

```
CarTube/
├── Config/
│   └── Secrets.xcconfig.example   # committed template with placeholder
├── Secrets.xcconfig               # gitignored (or absolute-path #include target outside repo)
├── CarTube/
│   ├── CarTube.entitlements       # gains com.apple.developer.carplay-audio only when grant lands
│   └── Info.plist                 # gains YOUTUBE_API_KEY = $(YOUTUBE_API_KEY)
└── .planning/
    ├── PROJECT.md                 # Key Decision rows: category rationale, key-delivery mechanism
    └── STATE.md                   # dated blocker + submission dates
```

### Pattern 1: xcconfig secret injection (verified from Apple docs)

**What:** A user-defined build setting defined in a non-committed `.xcconfig` file, referenced from `Info.plist`, baked in at build time.
**When to use:** exactly this case — a per-build value that must never enter git but must reach the compiled product without hand-editing files.

Verified mechanics [VERIFIED: developer.apple.com/documentation/xcode/adding-a-build-configuration-file-to-your-project via Context7]:
- Format: `<SettingName> = <SettingValue>`, one per line; "Xcode ignores leading/trailing spaces and uses the last instance if a setting appears multiple times."
- Reference: `$(SettingName)` — "Reuse an existing build setting's value by placing its name in a string of the form $(SettingName). Xcode replaces these references with the actual values during the build process."
- Attachment: project → Info tab → Configurations → per-configuration (Debug/Release) popups. Layering: "project settings, then build configuration settings, then target settings" — target-level values win, which is safe here because `YOUTUBE_API_KEY` is a brand-new setting with no target-level definition.
- Out-of-repo support: `#include "/Users/MyUserName/Desktop/MyOtherConfig.xcconfig"` — absolute-path includes are a documented mechanism, so the real secrets file can live outside the repo entirely.
- When creating via Xcode's UI: "select File > New File, choose Configuration Settings File, ... and deselect all targets to prevent Xcode from embedding it as a resource."

```text
// Config/Secrets.xcconfig.example (committed)
YOUTUBE_API_KEY = REPLACE_ME

// Secrets.xcconfig (gitignored; real value)
YOUTUBE_API_KEY = AIza...real-key...

// CarTube/Info.plist (committed)
<key>YOUTUBE_API_KEY</key>
<string>$(YOUTUBE_API_KEY)</string>
```

```swift
// Swift read (Phase 3 consumer; decision documented now)
let key = Bundle.main.object(forInfoDictionaryKey: "YOUTUBE_API_KEY") as? String
```

**CI variant:** `xcodebuild` accepts build-setting overrides on the command line, so CI never needs the gitignored file — only a secret env var:
```bash
xcodebuild -project CarTube.xcodeproj -scheme CarTube YOUTUBE_API_KEY="$YOUTUBE_API_KEY" build
```

**Known limitation (must be documented in the plan, not hidden):** the key ships inside the IPA's `Info.plist` — readable with `plutil`, no `strings` needed. This is inherent to any client-side key. Google's own docs warn "Bypassing this restriction is straightforward" for iOS restrictions — which is why the milestone decision pairs this with API + bundle-ID restrictions and keeps the remote-config rotation path open (milestone Pitfalls P6). The xcconfig mechanism is chosen for *repo hygiene and CI rotation*, not secrecy from the device.

### Pattern 2: Entitlement grant-wiring runbook (verified from the CarPlay Developer Guide)

**What:** A pre-staged, ordered procedure executed the moment Apple grants the entitlement — regardless of which phase is active when it lands.
**When to use:** when the external clock has no SLA and the wiring steps are easy to get wrong months later.

The guide's exact post-grant sequence [VERIFIED: CarPlay Developer Guide 2026-06-08, "Entitlements" section]:
1. Log in to developer.apple.com/account/
2. Certificates, IDs & Profiles → Identifiers
3. Select the App ID (or create it)
4. Enable all necessary CarPlay app entitlements
5. Save
6. Provisioning Profiles → create a new provisioning profile for the App ID
7. Import the profile into Xcode ("Xcode and Simulator require a Provisioning Profile that supports CarPlay")
8. Add to Entitlements.plist (verbatim from guide):
```xml
<key>com.apple.developer.carplay-audio</key>
<true/>
```
9. Signing & Capabilities → turn OFF "Automatically manage signing"
10. Build Settings → Code Signing Entitlements points at the Entitlements.plist path (already true in this repo: `CODE_SIGN_ENTITLEMENTS = CarTube/CarTube.entitlements;` [VERIFIED: CarTube.xcodeproj/project.pbxproj:465,527,557,600])
11. Verify the CarPlay scene connects (simulator with CarPlay support or Device Hub / Additional Tools CarPlay Simulator)

**Sequencing constraint (critical):** the current entitlements file contains ONLY TrollStore private keys — verbatim, in full [VERIFIED: CarTube/CarTube.entitlements:5-18]: `SBStarkCapable`, `com.apple.runningboard.assertions.webkit`, `com.apple.multitasking.systemappassertions`, `com.apple.backboard.displaybrightness`, `platform-application`, `com.apple.private.security.no-container`, `com.apple.private.security.container-manager`. None of these are grantable by a real provisioning profile, and there is **no** `com.apple.developer.carplay-audio` key present today. A standard-profile build with this file fails at signing. Therefore the runbook's step 8 must be applied to an entitlements file that contains *only* grantable keys — i.e., in practice, step 8 lands as a swap to a clean file (or after Phase 2's key-stripping if that phase has already run). Phase 1 must document this dependency explicitly rather than pretend the swap is consequence-free; actually deleting the private keys is Phase 2 scope (INFRA-02) and must not be pulled forward casually — the TrollStore `ipabuild.sh` path still needs them until Phase 2 removes it.

### Pattern 3: Dated external blocker tracking

Success criterion 3 has two branches. The pending branch is the expected one (review times community-reported days–months; Apple publishes no SLA — milestone Pitfalls P1). Record in `.planning/STATE.md` under Blockers/Concerns: submission date, category requested, expected re-check cadence, and the fact that phases 3–5 are unblocked via phone-side mocks. The existing STATE.md already carries the seed of this entry: "Phase 1: CarPlay entitlement application timeline is outside our control (days–months, no SLA) — blocks on-device CarPlay verification only; code work proceeds against phone-side mocks" [VERIFIED: .planning/STATE.md:62-63]. Phase 1 upgrades it from generic concern to dated record.

### Anti-Patterns to Avoid

- **Submitting the entitlement application with the current reverse-DNS bundle ID "because it's already in the pbxproj"** — the entitlement attaches to the App ID; a later bundle-ID change orphans the grant and forces re-application. Decide the distribution bundle ID first.
- **Committing `Secrets.xcconfig` "temporarily"** — the repo is a public fork (`origin https://github.com/phuongddx/CarTube.git`, `upstream https://github.com/Avangelista/CarTube.git` [VERIFIED: `git remote -v` this session]); YouTube policy III.D.1.c explicitly prohibits credential embedding in open-source projects (milestone research P6). Git history is forever.
- **Describing "video on CarPlay while driving" in the entitlement request text** — the audio category requires being "designed primarily to provide audio playback services"; request text describing a driving video surface invites denial at entitlement review (milestone P2).
- **Treating key restrictions as secrecy** — Google's docs state plainly: "Bypassing this restriction is straightforward. If you use this restriction, you should also add API restrictions and monitor usage carefully." [VERIFIED: docs.cloud.google.com/docs/authentication/api-keys, iOS apps section]
- **Wiring the granted profile while private entitlement keys remain** — signing fails; the runbook must sequence the clean-entitlements dependency (see Pattern 2).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Getting a per-build string into the binary | Codegen scripts, build-phase shell scripts writing Swift files, obfuscated string tables | xcconfig → `$(YOUTUBE_API_KEY)` → Info.plist | Xcode's documented substitution; zero moving parts; CI-friendly via command-line override |
| Tracking the external clock | Ad-hoc TODOs / chat messages | STATE.md dated blocker + PROJECT.md Key Decision row | The GSD state mechanism already exists and is what later phases read |
| Key rotation plumbing | Custom key-encryption in the binary | Restrictions now; remote-config rotation path later (already a documented milestone decision) | Client keys are public-by-design; rotation beats obfuscation (milestone P6) |

**Key insight:** every novel mechanism added here becomes a review surface and a debugging liability; the phase's value is in correct external submissions and a boring, documented delivery path.

## Common Pitfalls

### Pitfall 1: The bundle ID gates both external clocks — and it's currently someone else's reverse-DNS
**What goes wrong:** The entitlement application and the Google iOS restriction both name the App ID/bundle IDs. The repo uses `com.avangelista.CarTube` / `com.avangelista.CarTube.PlayOnCarTube` [VERIFIED: CarTube.xcodeproj/project.pbxproj:580,623,653,680 — verbatim: `PRODUCT_BUNDLE_IDENTIFIER = com.avangelista.CarTube;` and `PRODUCT_BUNDLE_IDENTIFIER = com.avangelista.CarTube.PlayOnCarTube;`] — the upstream author's prefix, in a repo whose origin is a public fork of `Avangelista/CarTube`. If the final distribution ID differs from the one named in the entitlement application, the grant is attached to the wrong App ID; App Store submission additionally requires store-wide bundle-ID uniqueness.
**Why it happens:** the ID came with the fork and everything still builds with it, so nothing forces the question until an external form asks for it.
**How to avoid:** Make the bundle-ID decision the first task of the phase — before either submission. Options: keep `com.avangelista.CarTube` (only valid if that ID is registerable and the user accepts the branding) or re-prefix under the user's own domain/team. Team is already set: `DEVELOPMENT_TEAM = U67AKNW8PW;` [VERIFIED: pbxproj:561,604,641,668].
**Warning signs:** an entitlement application or a Google restriction listing a bundle ID that the user hasn't consciously chosen.

### Pitfall 2: The existing entitlements file blocks standard provisioning
Covered in Pattern 2's sequencing constraint. The concrete failure: import new profile → automatic signing off → build → codesign error on ungrantable entitlement keys. **Warning sign:** a plan step "wire provisioning profile" with no mention of the entitlements-file contents.

### Pitfall 3: Wrong category framing in the application text
**What goes wrong:** Apple reviews the request against the category's criteria. The guide's criteria, verbatim [VERIFIED: CarPlay Developer Guide 2026-06-08]:
- General rule 1: "Your CarPlay app must be designed primarily to provide the specified feature (for example, CarPlay audio apps must be designed primarily to provide audio playback services, CarPlay parking apps must be designed primarily to provide parking services, etc.)."
- Video category: "Video apps must be designed primarily to provide video playback services." + "Video apps must support AirPlay video streaming." (parked watching — contradicts this milestone's Core Value).
**Why it happens:** the honest description of this app ("YouTube video in a webview on the car screen while driving") matches neither category cleanly; audio is the *least dishonest* fit because the app genuinely provides audio playback of YouTube content through the car's system.
**How to avoid:** Request audio. Position the app as playback of YouTube content through the vehicle's audio system. Document the residual risk (video surface under an audio category) as a Key Decision — the decision is already pre-made by the user in PROJECT.md ("Official CarPlay entitlement: apply under the audio category (honest fit…)"); Phase 1 writes the rationale text and logs it. Also note from the guide: "CarPlay audio app and CarPlay video app entitlements may be combined in a single app" — not needed now, but the door exists.
**Warning signs:** request text mentioning "video while driving", "watch", or parked-detection plans.

### Pitfall 4: The key still ships — restrictions are abuse-surface reduction, not secrecy
**What goes wrong:** team treats bundle-ID + API restrictions as making the key safe to expose, skips the rotation path, and a leaked key burns the entire fleet's quota (100 `search.list` calls/day shared across ALL installs [VERIFIED: developers.google.com/youtube/v3/getting-started, updated 2026-06-01 — verbatim: "Projects that enable the YouTube Data API have a default quota allocation of 100 `search.list` calls, 100 `videos.insert` calls, and 10,000 units per day combined for all other endpoints."]).
**How to avoid:** document in the plan that the built Info.plist contains the key; set quota monitoring/alerting on the Google project; keep the remote-config rotation option from milestone research open. Google's warning is explicit that iOS restrictions are bypassable [VERIFIED: Google Cloud docs].
**Warning signs:** plan language like "secure key storage" for a client-embedded key.

### Pitfall 5: Forgetting the API must be *enabled* before it can be named in a restriction
**What goes wrong:** key creation flow in the Console now requires at least one API restriction [VERIFIED: Google docs — "In the Google Cloud console, you must add at least one API restriction to be able to create an API key"], and "Before you can specify an API for an API restriction, the API must be enabled for your project."
**How to avoid:** runbook order: create dedicated project → enable YouTube Data API v3 → create key → set both restrictions. Verify on the Enabled APIs page that "the status is ON for the YouTube Data API v3" [VERIFIED: developers.google.com/youtube/v3/getting-started].

### Pitfall 6: Only one application-restriction type at a time
**What goes wrong:** attempting to set both an iOS restriction and (say) a website restriction — Google allows exactly one application restriction type per key [VERIFIED: Google docs — "You can apply only one application restriction type at a time"].
**How to avoid:** iOS apps restriction only; that's the correct type here anyway.

## Code Examples

### Entitlements addition (when grant lands)
```xml
<!-- Source: CarPlay Developer Guide 2026-06-08, "Entitlements" section (verbatim example for a CarPlay audio app) -->
<key>com.apple.developer.carplay-audio</key>
<true/>
```

### xcconfig files
```text
// Source: developer.apple.com/documentation/xcode/adding-a-build-configuration-file-to-your-project (verified via Context7)
// Setting format verified verbatim: "<SettingName> = <SettingValue>"
YOUTUBE_API_KEY = REPLACE_ME

// Out-of-repo include (verified verbatim from docs):
// #include "/Users/MyUserName/Desktop/MyOtherConfig.xcconfig"
```

### Info.plist injection + Swift read
```xml
<!-- CarTube/Info.plist (existing custom plist — project does not use GENERATE_INFOPLIST_FILE for the app target's core manifest) -->
<key>YOUTUBE_API_KEY</key>
<string>$(YOUTUBE_API_KEY)</string>
```
```swift
let apiKey = Bundle.main.object(forInfoDictionaryKey: "YOUTUBE_API_KEY") as? String ?? ""
```

### .gitignore addition
```text
# Build-time secrets — never commit (repo is a public fork)
Secrets.xcconfig
```
Current `.gitignore` has no such entry today [VERIFIED: full file read this session — standard Xcode template only; `build/` and `DerivedData/` already ignored, which also keeps ipabuild.sh output out of git].

### Existing scene manifest (already CarPlay-shaped — no Info.plist scene changes needed this phase)
Verbatim [VERIFIED: CarTube/Info.plist:20-32]:
```xml
<key>UIApplicationSceneManifest</key>
<dict>
    <key>UIApplicationSupportsMultipleScenes</key>
    <true/>
    <key>UISceneConfigurations</key>
    <dict>
        <key>UIWindowSceneSessionRoleCarPlay</key>
        <array>
            <dict>
                <key>UISceneDelegateClassName</key>
                <string>$(PRODUCT_MODULE_NAME).CarPlaySceneDelegate</string>
            </dict>
        </array>
    </dict>
</dict>
```
The delegate exists and installs `CarPlayViewController` in a `UIWindow` on connect [VERIFIED: CarTube/CarPlay/CarPlaySceneDelegate.swift:13-27]. This non-template `UIWindowSceneSessionRoleCarPlay` approach is the deliberate core mechanism being preserved (PROJECT.md); the entitlement wiring does not touch it.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| CarPlay entitlement via ad-hoc emails / assumed automatic | Web request form at developer.apple.com/carplay + CarPlay Entitlement Addendum, account-level assignment | Current guide 2026-06-08 | One deliberate submission with recorded date; profile regeneration required after grant |
| YouTube quota folklore: "10,000 units/day, search costs 100" | Dedicated buckets: 100 `search.list` calls/day, 100 `videos.insert`/day, 10,000 units/day for other endpoints; every request (even invalid) costs ≥1 unit; reset midnight PT | Docs updated 2026-06 | Quota strategy is a hard constraint on Phase 3 design; reinforces key-hygiene urgency (a leaked key burns the whole fleet's 100) |
| Unrestricted API keys creatable in Console | Console requires ≥1 API restriction at creation | Google docs current (2026-08) | Key-creation runbook must enable the API first, then restrict |

**Deprecated/outdated:** none in-repo for this phase beyond what Phase 2 will remove (TrollStore entitlements pipeline).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The gcloud service-name string for YouTube Data API v3 is `youtube.googleapis.com` (for `--api-target=service=...`); Console UI shows it as "YouTube Data API v3" | Google key provisioning | Low — Console flow (select from dropdown) is the recommended path and needs no service string; only the gcloud/REST path is affected |
| A2 | A paid Apple Developer Program membership is required to submit the CarPlay entitlement request (form sits behind Apple ID auth; guide doesn't state the tier) | Entitlement application | Medium — if the user's account is free-tier, submission is impossible until upgraded; should be confirmed at the human checkpoint |
| A3 | The entitlement request form asks for app name, primary language, bundle ID / App ID, website, and a description of intended CarPlay functionality (form is behind login — not directly verifiable this session; the guide confirms only "provide information about your app, including the category") | Entitlement application | Low-Medium — agent prepares the rationale text as a paste-ready document so field-level surprises don't stall the submission |
| A4 | Community-reported entitlement review times of days–months remain representative | Blocker tracking | Low — tracking mechanism is date-based either way |
| A5 | `com.avangelista.CarTube` is registerable by team U67AKNW8PW for App Store distribution (not globally claimed) | Pitfall 1 / bundle-ID decision | High — if claimed by the upstream author's team for App Store use, the distribution bundle ID must change; hence the decision is the phase's first task |
| A6 | Info.plist `$(VARIABLE)` substitution works for the existing hand-authored `CarTube/Info.plist` the same as for generated plists | Pattern 1 | Low — this substitution in hand-authored plists is long-standing Xcode behavior; the verification step (`plutil -extract` on the built plist) catches failure immediately |

## Open Questions

1. **Final distribution bundle ID** (gates both submissions)
   - What we know: current IDs are `com.avangelista.CarTube` + `com.avangelista.CarTube.PlayOnCarTube`; team `U67AKNW8PW`; repo is a public fork of the upstream author's project; `CFBundleURLName` in Info.plist is still `com.avangelista.TrollTube` [VERIFIED: CarTube/Info.plist:13]
   - What's unclear: whether the user wants to keep the upstream prefix for distribution and whether that ID is store-registerable
   - Recommendation: planner makes this an explicit user decision task with two pre-written options (keep vs. re-prefix under user's domain), sequenced before both submissions
2. **Apple Developer account state**
   - What we know: entitlement request requires Apple ID sign-in; the user's team ID exists in the project
   - What's unclear: paid-program status (A2) and who performs the submission
   - Recommendation: fold into the same human-checkpoint task as the application itself
3. **Google project ownership and dev-key separation**
   - What we know: milestone research recommends a dedicated shipping project and a separate dev project/key; `gcloud` is installed for verification
   - What's unclear: whether the user wants the dev project created now or in Phase 3 when dev usage starts
   - Recommendation: create the dedicated shipping project + restricted key now (success criterion 2); defer the dev-key project to Phase 3, noting it in the Key Decision so it isn't forgotten

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode / xcodebuild | build verification, later test runs | ✓ | 26.3 (17C529) | — |
| iOS SDK | builds | ✓ | iphoneos26.2 | — |
| iOS Simulator | key-injection build verification (`-destination 'platform=iOS Simulator'`) | ✓ | iPhone Air booted; iPhone 17/17e available | — |
| gcloud CLI | scripted verification of key restrictions | ✓ | 579.0.0 | Console UI (manual) |
| ruby + xcodeproj gem | scripted pbxproj edits (xcconfig attach) | ✓ | ruby 3.2.3 / xcodeproj 1.28.1 | manual Xcode UI (human step) |
| xcbeautify | readable verification output | ✓ | present | plain xcodebuild output |
| Apple Developer account (paid) | entitlement submission | ? (login-walled) | — | none — human checkpoint |
| Google account w/ Cloud access | key creation | ? (login-walled) | — | none — human checkpoint |
| CarPlay Simulator / Additional Tools | post-grant scene verification | ✗ (not probed; downloadable from developer.apple.com/download/all — "additional tools for Xcode") | — | verification deferred until grant lands (expected branch) |

**Missing dependencies with no fallback:** none that block this phase's execution — both login-walled items are inherent human checkpoints, modeled as such.
**Missing dependencies with fallback:** CarPlay Simulator — only needed on the grant branch; download when the grant lands.

## Validation Architecture

This phase creates build-verifiable behavior, not Swift unit-test behavior. The XCTest target itself is Phase 3 scope (SRCH-04); Phase 1 decides the approach and records it so Phase 3 executes rather than explores.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (decided; target created in Phase 3 per SRCH-04) |
| Config file | none exists — no test target in project today [VERIFIED: `xcodebuild -list` shows only targets `CarTube`, `PlayOnCarTube`; schemes `CarTube`, `Dynamic`, `PlayOnCarTube`; grep of pbxproj finds no test-target entries] |
| Quick run command | `xcodebuild -project CarTube.xcodeproj -scheme CarTube build 2>&1 \| tail -5` |
| Full suite command | (Phase 3) `xcodebuild test -project CarTube.xcodeproj -scheme CarTube -destination 'platform=iOS Simulator,name=iPhone Air'` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| INFRA-01 (key delivery) | xcconfig value reaches built Info.plist | build-integration | `xcodebuild … build && plutil -extract YOUTUBE_API_KEY raw "$BUILT_PRODUCTS_DIR/CarTube.app/Info.plist"` (asserts non-placeholder value) | ❌ Wave 0 (one-line script, no framework needed) |
| INFRA-01 (repo hygiene) | no key material in tracked files | static | `git grep -nE 'AIza[0-9A-Za-z_-]{30,}'` returns empty; `git check-ignore Secrets.xcconfig` succeeds | ❌ Wave 0 |
| INFRA-01 (submissions) | application submitted + date recorded; key restricted | manual-only (external consoles; login-walled) | human checkpoint with evidence (submission date in STATE.md; restriction screenshot or `gcloud services api-keys list` output) | n/a |

Manual-only justification: both consoles sit behind Apple ID / Google auth; an agent cannot perform or directly verify them.

### Sampling Rate
- **Per task commit:** the two Wave 0 commands above (fast; build is the slow part — acceptable)
- **Per wave merge:** same, plus confirm STATE.md dated entries exist
- **Phase gate:** both Wave 0 checks green + both human checkpoints evidenced

### Wave 0 Gaps
- [ ] Key-injection build check (inline shell in plan verification — no test file needed)
- [ ] Repo-hygiene grep check (inline shell)
- [ ] XCTest target + config — **deliberately deferred to Phase 3 (SRCH-04)**; approach decided here: create via ruby `xcodeproj` script (gem 1.28.1 present) or Xcode UI, unit-test bundle hosted by the `CarTube` app target, test action attached to the `CarTube` scheme

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | no user auth in this phase |
| V3 Session Management | no | none |
| V4 Access Control | no | none |
| V5 Input Validation | no | no new input paths this phase |
| V6 Cryptography | no | API key is a *credential identifier*, not a secret protectable by client crypto — controls are transport hygiene + restrictions, not encryption |
| Secrets management (general) | yes | gitignored/out-of-repo xcconfig; both key restrictions; quota monitoring; never commit |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| API key leakage via public repo (origin is a public fork) | Information Disclosure | gitignored xcconfig + committed placeholder template + `git grep AIza` gate; remote-config rotation path retained |
| Quota theft via extracted key | Abuse / DoS (quota) | API restriction (YouTube Data API v3 only) + iOS bundle-ID restriction + Google Cloud quota alerting; accept key is public-by-design |
| Entitlement/category misrepresentation | Repudiation (review) | honest audio-category positioning; rationale documented as Key Decision |

## Sources

### Primary (HIGH confidence)
- CarPlay Developer Guide, 2026-06-08 (developer.apple.com/download/files/CarPlay-Developer-Guide.pdf — downloaded and text-extracted this session): entitlement request process, Addendum, `com.apple.developer.carplay-audio` key, post-grant provisioning sequence, automatic-signing-off instruction, audio/video category criteria (verbatim quotes above), simulator profile requirement, "cannot selectively show or hide CarPlay", audio+video combinability
- developer.apple.com/carplay/ (fetched): "Request CarPlay app entitlement" → /contact/carplay/ (redirects behind Apple ID auth — confirms login wall)
- Google Cloud "Manage API keys" (docs.cloud.google.com/docs/authentication/api-keys, updated 2026-08-13): key creation flow, mandatory API restriction in Console, API + iOS application restriction steps, one-restriction-type rule, X-Ios-Bundle-Identifier header, "bypassing is straightforward" warning, enable-before-restrict rule, gcloud/REST equivalents
- YouTube Data API getting-started (developers.google.com/youtube/v3/getting-started, updated 2026-06-01): current quota model (verbatim quote in Pitfall 4), ≥1-unit floor for all requests, extension form
- Repo files read this session: `CarTube/CarTube.entitlements` (all keys verbatim), `CarTube/Info.plist` (URL scheme, scene manifest verbatim), `CarTube.xcodeproj/project.pbxproj` (bundle IDs, team, signing style, deployment target, entitlements path), `CarPlay/CarPlay/CarPlaySceneDelegate.swift`, `CarTube/Util/Constants.swift`, `.gitignore` (full), `git remote -v`, `ipabuild.sh`, `.planning/STATE.md`, `.planning/ROADMAP.md`, `.planning/codebase/TESTING.md`

### Secondary (MEDIUM confidence)
- Apple xcconfig documentation (developer.apple.com/documentation/xcode/adding-a-build-configuration-file-to-your-project) via Context7: setting format, `$(Name)` substitution, Configurations attachment, layering order, absolute-path `#include`, deselect-targets guidance — official docs, but surfaced through Context7 rather than fetched raw
- xcodebuild test invocation patterns (developer.apple.com/documentation/xcode/running-tests-and-interpreting-results) via Context7

### Tertiary (LOW confidence)
- A2 (paid membership requirement), A3 (form field list), A4 (review timelines) — training/community knowledge, flagged in Assumptions Log

## Metadata

**Confidence breakdown:**
- Apple entitlement process: HIGH — official guide downloaded and quoted verbatim this session
- Google key provisioning/restriction: HIGH — official docs fetched directly
- xcconfig key delivery: MEDIUM-HIGH — official docs via Context7; mechanism is decades-stable; build-verification step covers residual risk
- XCTest scaffolding: MEDIUM — approach grounded in verified tool inventory + official run commands; target creation itself deferred to Phase 3
- Bundle-ID decision inputs: HIGH on facts (verbatim pbxproj/remote output), the decision itself is the user's

**Research date:** 2026-08-18
**Valid until:** 2026-09-17 (30 days — both Apple guide and Google docs are dated 2026-06/2026-08 and were fetched current; external processes change slowly, quota model has changed recently so re-verify before Phase 3)
