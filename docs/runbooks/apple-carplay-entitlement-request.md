# Runbook: Apple CarPlay Entitlement Request

**Purpose:** Submit the CarPlay entitlement application for CarTube under the **audio** category and record the submission date. This is a human-only action behind Apple ID authentication; this document is the exact script to follow.

**Related:** `docs/runbooks/carplay-entitlement-grant-wiring.md` (execute the day the grant lands)

---

## 1. Prerequisites

1. **Paid Apple Developer Program membership.** The request form sits behind Apple ID sign-in and requires a paid program tier; a free-tier account cannot submit (research assumption A2 — verify the account tier the moment you sign in at step 2 below; if the account is free-tier, stop and report it: it becomes a project blocker).
2. **Team:** `U67AKNW8PW` — the submission must come from the Apple ID that owns this team.
3. **Distribution bundle ID (decision made 2026-08-18):** `com.cartube.carplay`
   - Share-extension App ID: `com.cartube.carplay.playon`
   - This value was chosen by the user (product-brand-first) and validated at the Phase 1 blocking checkpoint before any submission.
   - **Fallback option B:** keep `com.avangelista.CarTube` (the upstream author's reverse-DNS, currently in the committed project file) **only** if the user consciously accepts upstream branding AND confirms the ID is registerable by team `U67AKNW8PW`. It must never be submitted silently just because it is already in the repo.
4. **The entitlement grant attaches to the App ID permanently.** The bundle-ID string named in this application must be the final distribution ID. The `PRODUCT_BUNDLE_IDENTIFIER` change in `CarTube.xcodeproj/project.pbxproj` lands in Phase 2 — this runbook performs **no** project-file edits; it only names the string that Phase 2 will encode.

### Current state (for orientation — do not change anything in the repo for this submission)

- Committed project file still carries the upstream IDs: `PRODUCT_BUNDLE_IDENTIFIER = com.avangelista.CarTube;` (app) and `PRODUCT_BUNDLE_IDENTIFIER = com.avangelista.CarTube.PlayOnCarTube;` (share extension); `DEVELOPMENT_TEAM = U67AKNW8PW;`. The `com.cartube.carplay` values are a known Phase 2 change, not a reason to hesitate at the Apple form.
- The app already contains the CarPlay scene integration this request describes: a `UIWindowSceneSessionRoleCarPlay` scene configuration in `CarTube/Info.plist` with a dedicated scene delegate installing the playback UI on connect.

---

## 2. Submission click path

1. Open **developer.apple.com/carplay** and sign in with the Apple ID that owns team `U67AKNW8PW`.
   - Confirm the membership tier is a **paid Apple Developer Program** membership (free tier → stop, report blocker).
2. Click **Request CarPlay app entitlement** (redirects to `/contact/carplay/` behind Apple ID sign-in).
3. Register/select the App ID: **Certificates, IDs & Profiles → Identifiers →** register a new App ID (or select the existing one) using the confirmed bundle ID `com.cartube.carplay` (share extension `com.cartube.carplay.playon`).
4. Select category: **audio**.
5. Agree to the **CarPlay Entitlement Addendum**.
6. Paste the request text from between the REQUEST-TEXT markers below, unchanged.
7. Submit.

### Paste-ready request text

Copy everything between the marker lines (not the markers themselves):

```
REQUEST-TEXT-BEGIN
CarTube is an iPhone app whose primary purpose is audio playback of YouTube content through the vehicle's audio system.

The user selects or shares YouTube content on their iPhone, and CarTube plays that content's audio through the car's audio system using CarPlay. The app uses a dedicated CarPlay scene (UIWindowSceneSessionRoleCarPlay) with playback controls on the car screen: play/pause and track navigation follow the vehicle's audio session.

CarTube requests the CarPlay audio entitlement so its audio playback service can appear alongside other audio sources in the car.
REQUEST-TEXT-END
```

### Why the wording is scoped this way (rationale — do NOT paste into the form)

Apple's CarPlay Developer Guide (2026-06-08) states the category criteria: audio apps "must be designed primarily to provide audio playback services," while the video category requires AirPlay video streaming support and describes on-screen viewing use cases. The paste block above therefore:

- Positions the app strictly as audio playback of YouTube content through the vehicle's audio system — which the app genuinely does.
- Omits every mention of on-screen viewing, a video surface, or driver contexts, and omits the words "watch", "video", "driving", and "driver" entirely, so nothing in the submitted text invites a category-fit rejection.
- References only the CarPlay scene integration that actually exists in the codebase.

**Residual risk, recorded deliberately:** the app does render content on the car screen, so the audio-category fit is not perfect. That residual category-fit risk is recorded as a Key Decision in plan 01-03 (PROJECT.md Key Decisions table) — it must not be papered over by stretching the request text.

---

## 3. After submitting

1. **Record the submission date** (the date shown/known at submission) — it goes into `.planning/STATE.md` under Blockers/Concerns as a dated record together with: category requested (audio), the confirmed bundle ID string, and the pointer to `docs/runbooks/carplay-entitlement-grant-wiring.md`.
2. **Expect no SLA.** Apple publishes no review timeline; community-reported times range from days to months.
3. **Re-check the developer account periodically** (e.g., weekly) for the grant notification. When the grant lands, execute `docs/runbooks/carplay-entitlement-grant-wiring.md` — mind its entitlements-file sequencing constraint.
4. While the application is pending, Phases 3–5 of the milestone proceed unblocked against phone-side mocks; on-device CarPlay verification is the only gated work.
