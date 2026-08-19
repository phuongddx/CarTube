# App Store Metadata — CarTube

Paste-ready store copy for App Store Connect. The block between the markers is the only
store-facing text; everything outside the markers is internal position and gating.

The hard rule for this document: **no store-facing field references the enhancement
scripts' effects.** The negative wording gate at the bottom enforces it mechanically.

## Prerequisites

1. **Bundle IDs:** `com.cartube.carplay` (app), `com.cartube.carplay.playon` (share
   extension). Team `K2TYLYAWMK`.
2. **Field limits (App Store Connect):** name ≤ 30 chars, subtitle ≤ 30 chars,
   promotional text ≤ 170 chars, description ≤ 4000 chars, keywords ≤ 100 chars.
3. The copy below is written in the app's existing user-facing voice
   (`CarTube/Views/HowTo.swift`).

## Store copy (paste-ready)

METADATA-BEGIN

**App name:** CarTube

**Subtitle:** Videos on your car screen

**Promotional text:**
Open any video on your car screen — by voice, search, or a share from any app. Playback
runs through your vehicle's sound system.

**Description:**
Get in your car, plug in your phone, and start CarTube on CarPlay. Enjoy a full YouTube
experience in the car!

CarTube puts YouTube playback on your car screen, playing through your vehicle's sound
system. The phone app is your launcher and settings editor — the car screen does the
playing.

FIND SOMETHING TO PLAY
- Paste or type a YouTube link or video ID on your phone and it plays in the car.
- Share a video to CarTube from any app — it opens straight on the car screen.
- Search on the car screen: glanceable results, one tap to play. Results from YouTube.
- Search by voice: push-to-talk on the car screen with on-device speech recognition, or
  ask Siri to search CarTube — no setup needed.

MADE FOR THE CAR
- Big, glanceable search results: thumbnail, title, channel, and duration.
- A zoom control sizes the YouTube interface for your car's display.
- Screen persistence keeps playback running without babysitting your phone.

CarTube is an independent app and is not affiliated with or endorsed by YouTube or
Google.

**Keywords:**
youtube,carplay,video,car screen,voice search,share,player,drive

METADATA-END

## Position: in-app copy is not App Store metadata

App Store metadata is a different surface from in-app copy, and only metadata is gated
here. The Settings screen keeps its shipped toggle names (`CarTube/Views/Settings.swift`)
because disclosed features, honestly described in the review notes
(`docs/submission/app-review-notes.md`), are not hidden functionality — Guideline 2.3.1
concerns *hidden or undocumented* behavior.

The metadata gate exists for a different threat: marketing the enhancement scripts'
effects in public store copy reads as ToS-violation advertising — both to App Review and
to YouTube's brand-protection teams — and this project carries a registered YouTube Data
API v3 key, exactly the pairing an auditor notices first (PITFALLS Pitfall 8). The store
copy therefore describes the experience (open, play, search, share, voice) and never the
scripts' effects.

## Name and icon constraints (2.3.7, 5.2.1)

- Guideline 2.3.7: the app name and subtitle must not include third-party trademarks in
  a way that implies an official product, and metadata must not contain irrelevant
  or misleading terms. "CarTube" plus a descriptive subtitle satisfies this; never
  rename toward anything that reads as an official YouTube product.
- Guideline 5.2.1: the icon and branding must not use YouTube's logo, play-button mark,
  or trade dress. The icon stays CarTube's own.
- Referring to YouTube factually in the description ("plays YouTube content") is
  accurate description of interoperability, not a branding claim; the independence
  disclaimer in the description makes the relationship explicit.

## Screenshots follow the same gate

Store screenshots are metadata. They must show the actual shipped UI, with no captions,
callouts, or overlays referencing the enhancement scripts' effects — the same vocabulary
gate below applies to any text rendered inside a screenshot. Showing the Settings screen
in a screenshot is allowed only if no caption draws attention to those toggles; prefer
screenshots of playback, search results, and voice search.

## Verification gate

The extracted block must produce **zero** hits. The command builds the marker names from
a variable so this section never re-opens the marker-scoped sed range itself:

```bash
M=METADATA
sed -n "/${M}-BEGIN/,/${M}-END/p" docs/submission/app-store-metadata.md \
  | grep -icE 'ad[- ]?block|sponsorblock|sponsor|age[- ]?restrict|bypass'
# must print 0
```
