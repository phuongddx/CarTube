# Runbook: Google Cloud — Restricted YouTube Data API Key

**Purpose:** Create the restricted YouTube Data API v3 key CarTube's search feature will call, inside a **new dedicated Google Cloud project**, and drop the key value into the build-time delivery pipe (root `Secrets.xcconfig`) that plan 01-01 proved. This is a human-only action behind Google account authentication; this document is the exact script to follow top to bottom.

**Related:** `docs/runbooks/apple-carplay-entitlement-request.md` (the other Phase 1 external clock)

**Why a dedicated project and why both restrictions:** the YouTube Data API's default allocation is a bucket of **100 `search.list` calls per day for the entire project, shared across ALL installs of the app** (per the 2026-06 quota model), every request — even an invalid one — costs at least 1 unit, and the quota resets at midnight Pacific. A leaked key starves every user of search. The key is therefore created alone in its own project, restricted to exactly one API, restricted to exactly our two bundle IDs, and watched by a quota alert.

---

## 1. Console procedure (in this exact order)

**Enable the API before restricting the key** — Google requires an API to be enabled before a key can name it in an API restriction, and the Console now mandates at least one API restriction when creating a key. Doing these out of order is the known trap.

1. Open **console.cloud.google.com** and sign in with the Google account that will own the key.
2. Project picker (top bar) → **New project** → name it **`cartube-shipping`** (dedicated: nothing else lives in it) → **Create**. Note the **project ID** shown at creation (e.g. `cartube-shipping-123456`) — you will report it afterwards so the agent can run the gcloud verification.
3. With the new project selected: **APIs & Services → Library** → search for **YouTube Data API v3** → open it → **Enable**.
4. Verify the enable step: **APIs & Services → Enabled APIs** lists **YouTube Data API v3** with status **ON**. Do not continue until this is true.
5. **APIs & Services → Credentials → Create credentials → API key**. (Expect the flow to demand an API restriction at creation — that is current Console behavior, not an error.)
6. Copy the created key value (a string starting with `AIza`) somewhere temporary. It goes **only** into `Secrets.xcconfig` (section 3) — never into chat, docs, issues, or any git-tracked file.
7. Open the key (pencil icon) and set **both** restriction groups:
   - **API restrictions:** select **Restrict key** → check **YouTube Data API v3** only. Nothing else.
   - **Application restrictions:** select **iOS apps** → add exactly two bundle IDs:
     - `com.cartube.carplay`
     - `com.cartube.carplay.playon`
8. **Save.**

### The bundle IDs to type are the FUTURE ones

The committed project file still carries the upstream author's IDs — `com.avangelista.CarTube` (app) and `com.avangelista.CarTube.PlayOnCarTube` (extension; note the `.PlayOnCarTube` suffix). Phase 2 re-prefixes the distribution IDs to the two `com.cartube.*` strings above. **Type the future `com.cartube.*` IDs in the restriction**, not what the pbxproj currently says: Google matches the bundle ID the shipped binary is signed with, and the App Store build will carry the `com.cartube.*` IDs. Listing the upstream strings would leave the real build unable to use the key.

### Only ONE application-restriction type

Google allows **exactly one application restriction type per key**. Use **iOS apps** — that is the correct type here. Do not attempt to also add a Website, IP-address, or Android restriction on this key: a key cannot hold two application-restriction types, and switching types replaces the previous one.

---

## 2. Quota guard (billing-free alerting)

Enable usage alerting on the project so a leak is noticed before it quietly burns the fleet quota:

1. With the project selected: **APIs & Services → Enabled APIs → YouTube Data API v3 → Quotas** tab.
2. Find the daily-request quota row and use its alert control (**Create alert** / the bell icon on the quota row).
3. Set a threshold well under the limit — e.g. **80% of the daily quota** — and a notification channel (your email).
4. This uses Cloud Monitoring's included alerting; **no billing account is required**. If the Quotas-tab alert control is not offered on your account, the equivalent is **Cloud Monitoring → Alert policies** on the API request-count metric filtered to YouTube Data API v3 — the goal is an email before the 100/day bucket empties.

If the alert ever fires with the app unreleased, treat the key as leaked: rotate (section 5) immediately.

---

## 3. Delivery into the build

Put the created key into the **repo-root `Secrets.xcconfig`** (gitignored, created in plan 01-01) as the `YOUTUBE_API_KEY` value, replacing the sentinel so the single line reads:

```
YOUTUBE_API_KEY = <the created key value>
```

The value goes **nowhere else**: not into `Config/Secrets.xcconfig.example` (git-tracked template — it keeps `REPLACE_ME`), not into any document, not into the Xcode project file, not into chat if avoidable (you may paste it into `Secrets.xcconfig` yourself and just confirm completion plus the project ID).

No further wiring is needed: the xcconfig is attached as the project-level base configuration, and the build substitutes `$(YOUTUBE_API_KEY)` into `CarTube/Info.plist` — the pipe plan 01-01 proved end-to-end with the sentinel.

---

## 4. Verification (the agent runs these once you report the project ID)

### Key restrictions (gcloud, or restriction-page screenshots if gcloud auth is unavailable)

```bash
gcloud services api-keys list --project=<PROJECT_ID>
gcloud services api-keys describe <KEY_NAME> --project=<PROJECT_ID>
```

Expected: the key's restrictions show an **API restriction to the service `youtube.googleapis.com`** (the service name behind the Console label "YouTube Data API v3") and an **iOS application restriction listing both `com.cartube.*` bundle IDs**.

### Build-time delivery (fresh simulator build)

```bash
xcodebuild -project CarTube.xcodeproj -scheme CarTube \
  -destination 'platform=iOS Simulator,name=iPhone Air' build
PLIST="$(xcodebuild -project CarTube.xcodeproj -scheme CarTube \
  -destination 'platform=iOS Simulator,name=iPhone Air' -showBuildSettings 2>/dev/null | \
  awk '/BUILT_PRODUCTS_DIR/{print $3; exit}')/CarTube.app/Info.plist"
plutil -extract YOUTUBE_API_KEY raw "$PLIST"
```

Expected: prints the real key — matches `^AIza[0-9A-Za-z_-]{30,}$`, i.e. not the sentinel and not `REPLACE_ME`.

### Repo hygiene (must stay clean)

```bash
git grep -nE 'AIza[0-9A-Za-z_-]{30,}'    # must print nothing
git check-ignore -q Secrets.xcconfig     # must exit 0 (still gitignored)
```

---

## 5. Honesty note: the key is public-by-design

The key **ships inside the IPA** — it lands in the built app's `Info.plist`, readable on any extracted build with `plutil`, no `strings` needed. Client-embedded API keys are public-by-design; no obfuscation changes that, and this project does not pretend otherwise.

The two restrictions **reduce the abuse surface** (the key can only call YouTube Data API v3, nominally only from the two `com.cartube.*` bundle IDs) — but Google's own key-management documentation warns that bypassing the iOS bundle-ID restriction is "straightforward" (a modified client can claim any bundle identifier), so the restriction is a speed bump, not a wall.

What actually protects the fleet quota: the small shared daily bucket makes leaks visible fast, and **rotation is cheap**. If the quota alert fires or the key is suspected leaked: create a new key value in the same project, put it into `Secrets.xcconfig` (or pass it as a `xcodebuild YOUTUBE_API_KEY=...` command-line override in CI so it never touches disk there), delete the old key. That rotation path is the designed remediation.

---

## Scope note

This runbook provisions the **shipping** key only. A separate Google project for development keys is deliberately deferred to Phase 3 (recorded as a Key Decision) so Phase 1 does not block search work on it.
