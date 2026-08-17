# Feature Research

**Domain:** Driver-safe voice search and YouTube browsing on CarPlay; App Store compliance features for an existing webview-video CarPlay app
**Researched:** 2026-08-17
**Confidence:** HIGH for CarPlay HIG constraints and review-guideline feature categorization (verified by the parallel Pitfalls research against official guidelines); MEDIUM for competitor-specific outcomes (community-reported, not first-party)

> Provenance note: this dimension's subagent runs failed twice on upstream API capacity errors (503/504). Content below was synthesized inline by the orchestrator from the verified sources in `.planning/research/PITFALLS.md` (App Review Guidelines, CarPlay Developer Guide June 2026) and `.planning/research/ARCHITECTURE.md`, plus the documented product decisions in `.planning/PROJECT.md`. No new claims were introduced beyond those sources.

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Play a video from a link/ID without touching the phone | Core promise of the app; share extension + phone launcher already do this | LOW (exists) | Existing capability — preserve byte-identical |
| Search YouTube from the car | The whole point of adding voice/text search; without it the app is paste-a-link only | MEDIUM | Voice is the differentiator; on-screen text search already exists via custom keyboard |
| Exit/close playback without phone interaction | Driver must never be required to grab the iPhone mid-drive (CarPlay guideline: all flows possible without iPhone) | LOW | Existing back/close handling on CarPlay surface |
| Results list that is glanceable and tappable while driving | CarPlay HIG: minimal glance time, large touch targets, no scroll-heavy lists | MEDIUM | ≤5–8 rows, title + channel + duration, ≥60pt rows, single tap to play |
| Playback continues while interacting (search, settings) | Users expect audio continuity when they open search over playback | MEDIUM | Overlay must not resize/navigate the webview beneath |
| App Store build that launches under standard signing | Users can't install at all without it; TrollStore users are the existing niche | HIGH | Entitlement + private-API severance + signing pipeline — this milestone's core infrastructure work |
| Permission setup completed on the phone before driving | System speech/mic prompts only render on iPhone; prompting from CarPlay dead-ends | MEDIUM | First-run onboarding screen in the phone shell; mic button gated on authorization |

### Differentiators (Competitive Advantage)

Features that set the product apart. Not required, but valuable.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Siri voice search ("Search YouTube for X") | Fully hands-free, eyes-free search trigger; zero taps | MEDIUM | AppIntents App Shortcut, iOS 16+; runs in-process; phrase carries the query parameter |
| Push-to-talk mic button on the CarPlay screen | Voice search for users who haven't set up/don't use Siri; explicit control (press-speak-release) | MEDIUM | On-device `SFSpeechRecognizer`; visible listening state required (2.5.14); auto-stop on silence |
| Ad/sponsor skipping via injected scripts | The retained differentiator vs. official YouTube clients; existing capability | LOW (exists) | Keep — but never advertised in App Store metadata (review risk; see anti-features) |
| Now-playing takeover ("You were watching this in the YouTube app — continue here?") | Delightful continuity moment; unique to private-API era | — | **Removed this milestone** (MediaRemote private API); recorded here so the removal is a conscious decision, not a silent loss |
| Webview search fallback | Invisible continuity: when API quota is exhausted or key revoked, search still works | LOW | Existing `searchVideo` path (percent-encoded m.youtube.com results load) becomes the safety net |
| YouTube attribution on results | Policy III.F.2 compliance that doubles as trust signal | LOW | "Results from YouTube" line in the overlay |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Browse/search YouTube by full keyboard while driving | Familiar desktop-style interaction | Apple restricts keyboards on CarPlay; typing while driving is a safety and guideline violation; the custom keyboard relies on the private `_simulateTextEntered` path being severed | Voice search + tappable results list; keyboard entry stays on the phone |
| Scroll-heavy infinite results feed | Feels like "real YouTube" | Glance-time violations; each extra results page costs a full `search.list` call from the 100/day bucket | One page, ≤5–8 curated rows (`maxResults=10`), explicit "search again" |
| Search-as-you-type / live results | Feels responsive | Burns the shared quota bucket on every keystroke; CarPlay input friction | Explicit submit (tap/voice release) only; last-query cache |
| Advertising ad-blocking/SponsorBlock in App Store copy | Markets the differentiator | Reads as ToS-violation marketing to reviewers and YouTube brand protection (2.3.7, 5.2.1); pairs catastrophically with a registered Data API key (III.I.5) | Metadata describes "YouTube player for CarPlay"; ad-block stays functional but unadvertised |
| Video playback gated to parked-only (video entitlement category) | Legitimate Apple-sanctioned shape (June 2026 video category) | Contradicts the Core Value (driver opens any video while driving); requires AirPlay video support | Audio-category entitlement with webview surface; parked-gating documented as the fallback-ladder rung if rejected |
| Keeping the now-playing takeover via any means | Users loved it | No public API exists; every replacement path is another private-API marker | Feature removed; phone clipboard/URL entry remains the "resume" path |
| Telemetry/crash reporting | Field diagnosis of CarPlay issues | Privacy-label burden; this milestone already carries heavy review risk | Defer to a future milestone (already out of scope) |

## Feature Dependencies

```
[Siri voice search] ──requires──> [SearchCoordinator funnel]
[AInterim: AppIntents + deployment target ≥16]
        │
        ├──requires──> [YouTubeSearchService (API client)]
        │                    └──requires──> [API key delivery + quota strategy]
        │
        ├──requires──> [SearchResultsViewController overlay]
        │                    └──requires──> [CarPlayViewController wiring (child VC)]
        │
[Push-to-talk mic] ──requires──> [SpeechRecognizerService]
        │                    └──requires──> [Permission onboarding on phone]
        │                    └──requires──> [SearchResultsViewController overlay]
        │
[App Store build] ──requires──> [CarPlay entitlement (external)]
        │            └──requires──> [Private-API severance + signing]
        │
[All CarPlay-on-device work] ──blocked-by──> [CarPlay entitlement (simulator included)]
```

### Dependency Notes

- **Siri + push-to-talk require the coordinator:** both entry surfaces funnel through `SearchCoordinator.search(query)` so degradation and caching are implemented once.
- **Voice (any form) requires results display first:** building speech before the overlay exists leaves transcripts with nowhere to land.
- **Entitlement blocks on-device CarPlay work:** without it the CarPlay scene never connects under standard signing — phone-side mock development is the unblocking pattern.
- **Severance precedes extension:** MediaRemote/brightness removal touches the same files (`viewDidLoad`, `CarPlaySingleton`, `Utilities`) search will touch — delete first, build second.

## MVP Definition

### Launch With (v1)

Minimum viable product — what's needed to validate the concept.

- [ ] CarPlay entitlement application submitted (day 1) — external dependency gating all on-device work
- [ ] TrollStore pipeline removed (entitlements, ldid, `ipabuild.sh`) + standard signing — installs via TestFlight
- [ ] Private-API severance (MediaRemote, brightness, springboard reads) + `strings` scan gate — the submission is not auto-rejected in minutes
- [ ] Deployment target raised to iOS 16 + hook behavioral re-validation — AppIntents floor + modern SDK
- [ ] YouTubeSearchService with budgeted quota (100/day bucket) + 403 fallback to webview search — search works on day one and survives quota death
- [ ] SearchResultsViewController overlay (glanceable list, tap-to-play via existing `loadUrl`) — the driver interaction surface
- [ ] Push-to-talk mic button + phone-first permission onboarding — voice search without Siri setup
- [ ] Siri App Shortcut ("Search YouTube for X") — hands-free trigger
- [ ] YouTube attribution on results — policy III.F.2
- [ ] App Review notes + honest metadata — the submission package is a deliverable

### Add After Validation (v1.x)

Features to add once core is working.

- [ ] Quota extension request / key rotation tooling — after entitlement lands and usage patterns are known
- [ ] Last-query cache and "play it again" affordance — once real usage shows repeat-query patterns
- [ ] Replacement for now-playing takeover using any future public API — watch WWDC
- [ ] Hook kill-switch dashboard — if iOS updates break surviving hooks in the field

### Future Consideration (v2+)

Features to defer until product-market fit is established.

- [ ] Parked-video mode under the official CarPlay video category (requires AirPlay video support) — the sanctioned long-term shape
- [ ] Template-based CarPlay UI (audio-first) — if webview rejection becomes untenable
- [ ] Queued playback / playlists — contradicts single-cached-video model today
- [ ] Telemetry with privacy-label compliance — only after App Store survival is proven

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| CarPlay entitlement application | HIGH (blocking) | LOW (form + tracking) | P1 |
| TrollStore removal + standard signing | HIGH (blocking) | MEDIUM | P1 |
| Private-API severance + scan gate | HIGH (blocking) | HIGH | P1 |
| Deployment target raise + re-validation | HIGH (blocking) | MEDIUM | P1 |
| YouTubeSearchService + quota strategy | HIGH | MEDIUM | P1 |
| Results overlay + tap-to-play | HIGH | MEDIUM | P1 |
| Push-to-talk + permission onboarding | HIGH | MEDIUM | P1 |
| Siri App Shortcut | MEDIUM-HIGH | LOW (~40 lines over the funnel) | P1 |
| YouTube attribution | MEDIUM (compliance) | LOW | P1 |
| Review notes + metadata honesty | HIGH (submission gate) | LOW | P1 |
| Last-query cache | MEDIUM | LOW | P2 |
| Quota extension tooling | MEDIUM | LOW | P2 |
| Hook kill-switches | MEDIUM | LOW | P2 |
| Parked-video mode | LOW (this milestone) | HIGH | P3 |
| Template-based CarPlay rebuild | LOW (out of scope) | HIGH | P3 |

## Competitor Feature Analysis

| Feature | Official YouTube app | TrollStore-era CarTube | This Milestone |
|---------|---------------------|------------------------|----------------|
| YouTube on CarPlay | Not offered (audio-only ecosystem apps aside) | Webview video, private APIs | Webview video retained (accepted risk), private APIs gone |
| Voice search | Google Assistant ecosystem | None | Siri phrase + push-to-talk, on-device |
| Search results UX | Native app UI (not on CarPlay) | YouTube web results page in webview | Native glanceable list overlay |
| Ad/sponsor handling | Ads served | Skipped via scripts | Skipped, unadvertised in metadata |
| Distribution | App Store | TrollStore sideload | TestFlight → App Store |
| Continuity with YouTube app | N/A | Now-playing takeover | Removed (no public API) |

### Competitor Notes

No third-party app legitimately ships webview YouTube video on CarPlay while driving — the June 2026 video category (parked-only + AirPlay requirement) exists because Apple created a sanctioned path that this milestone deliberately does not take (per user decision). The competitor landscape for "YouTube on CarPlay" is: official-adjacent audio apps (compliant), sideload hacks (this app's current state), and nothing in between. This milestone positions CarTube as the first TestFlight-distributable attempt at the middle ground, with the fallback ladder documented.

## Sources

- App Review Guidelines — CarPlay guideline 1, 2.3.1, 2.3.7, 2.5.11, 2.5.14, 4.2, 5.2.1, 5.2.3 — HIGH (verified by Pitfalls research)
- CarPlay Developer Guide, June 2026 — categories, parked-only video, entitlement process — HIGH (verified by Pitfalls research)
- YouTube API Services Developer Policies III.C.5, III.F.2, III.I.5/6 — attribution, ad-block prohibition — HIGH (verified by Pitfalls research)
- CarPlay HIG — glanceability, no-phone-required flows, keyboard restrictions — HIGH (established, guideline-verified)
- Project decisions — `.planning/PROJECT.md` Key Decisions table

---
*Feature research for: CarTube App Store + voice search milestone*
*Researched: 2026-08-17*
