# Fallback Ladder — Webview Rejection Contingencies

If App Review rejects the CarPlay webview surface, the next move is already decided
here. Every rung is **contingency documentation only** — nothing in this ladder is
implemented now, and no rung is entered until a rejection actually names its trigger
guideline. The ladder exists because a rejection with a pre-decided response is a
fast-follow; a rejection without one is a redesign under pressure (PITFALLS Pitfall 10).

The rejection vectors this ladder maps (Pitfall 10's four): CarPlay template rules,
Guideline 4.2 (minimum functionality / repackaged website), Guidelines 5.2.2/5.2.3
(third-party content and ToS), and Guideline 2.3.1 (notes adequacy — handled as a
general row, not a rung).

## Ladder at a glance

| Rung | Trigger guideline | What changes | Cost | Effort |
|------|-------------------|--------------|------|--------|
| Rung 0 | none — submission passes | nothing | none | none |
| Rung 1 | CarPlay template rules / video-while-driving (CarPlay App Guideline; the 2026 video category's parked-only shape) | video surface gated on parked state | contradicts the Core Value while driving | medium |
| Rung 2 | 4.2, or 5.2.2/5.2.3 rejections that survive Rung 1 | webview scene replaced by template-based CarPlay audio surface | on-screen video is gone entirely | large |
| — (any time) | 2.3.1 (notes deemed inadequate) | sharpen the review notes; the app does not change | resubmission cycle | small |

## Rung 0 — webview survives

- **Trigger:** none. The submission passes review as shipped.
- **What changes:** nothing — no action.
- **What it costs:** nothing.
- **Effort:** none.

This is the primary expected outcome given the accepted-risk Key Decision
(PROJECT.md: keep webview video on CarPlay for App Store submission; the user
prioritized the core video experience over approval odds).

## Rung 1 — parked-gate variant

- **Trigger:** rejection citing CarPlay template violations (a non-template
  `UIWindow`/WKWebView scene) or video-while-driving concerns — the shape the 2026
  CarPlay video category formalizes as parked-only.
- **What changes:** the video surface on CarPlay is gated on the vehicle's
  driving/parked state — video renders only while parked; while driving the surface
  degrades (audio continues, screen shows a restricted state).
- **What it costs:** this rung directly contradicts the milestone's **Core Value** — "a
  driver can open any YouTube video on their car screen" — because gating video to
  parked means the driver no longer watches while driving. That contradiction is named
  here deliberately and accepted as the trade-off *of this rung*: it is what a
  video-while-driving rejection leaves on the table, not a plan to implement now.
- **Effort:** medium — a drive-state gate over the existing scene, no search/voice rework.

## Rung 2 — audio-UI variant

- **Trigger:** Guideline 4.2 (the CarPlay experience is a repackaged website) or
  5.2.2/5.2.3 (third-party content / streaming that may violate the source's ToS —
  5.2.3 names YouTube explicitly) — rejections that a parked gate does not answer,
  because they object to the webview surface itself, not to when it is visible.
- **What changes:** the raw webview CarPlay scene is replaced with a template-based
  CarPlay audio surface (CPListTemplate/CPNowPlayingTemplate-class UI); playback becomes
  audio-first through the vehicle's system.
- **What it costs:** the largest rework of the ladder — the on-screen video experience
  is gone, the scene delegate/view controller pair is rebuilt on CarPlay framework
  templates, and the injected-script feature set no longer applies on the car screen.
- **Effort:** large.

## General row — 2.3.1 (review notes deemed inadequate)

If a rejection cites Guideline 2.3.1, the response is to **sharpen the notes, not change
the app**: revise `docs/submission/app-review-notes.md` to answer the specific gap the
reviewer named, keeping the mechanism disclosure exact. The app already ships nothing
the notes do not disclose, so a 2.3.1 rejection is a documentation defect with a
small-effort resubmission, available at every rung.

## Reusability guarantee — search and voice survive every rung

No rung discards the search or voice work. Phases 3–5 kept both decoupled from the
webview surface by design:

- All search inputs (typed keyboard, push-to-talk, Siri) funnel through a single
  `SearchCoordinator` (`CarTube/Search/SearchCoordinator.swift`, ROADMAP Phase 4
  criterion 3), which owns the query → results → selection flow independently of how
  the selected video is rendered.
- Voice input (Phase 5) lands on that same funnel — `SpeechRecognizerService`, MicButton,
  and the Siri App Shortcut know nothing about the webview.
- The Data API client, quota budget, cache, and fallback logic (Phase 3) are a leaf
  module behind the coordinator.

At Rung 1 the funnel is untouched. At Rung 2 the coordinator's selection handler is
re-pointed from the webview loader to the template surface's playback path — the funnel,
results data, voice capture, and Siri entry all carry over. This decoupling was kept
deliberately so that a webview rejection never forfeits the milestone's search and voice
investment (PITFALLS Recovery Strategies, "Rejected on 4.2/5.2.3").
