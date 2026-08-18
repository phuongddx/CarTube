# Runbook: Google Cloud — Restricted YouTube Data API Dev Key

**Purpose:** Create a SECOND, dedicated Google Cloud project holding a development-only YouTube Data API v3 key, so local development and CI never touch the shipping project's shared 100 `search.list` calls/day bucket (`docs/runbooks/google-youtube-api-key.md`). This is the Phase 1 dev-key deferral, now resolved.

**Related:** `docs/runbooks/google-youtube-api-key.md` (the shipping-key runbook this one mirrors step-for-step, aside from project name and application-restriction strictness)

**Why a separate, dedicated project:** the YouTube Data API's default allocation is a bucket of 100 `search.list` calls per day for the entire project, shared across ALL installs of the shipped app. Every request — even an invalid one — costs at least 1 unit, and the bucket resets at midnight Pacific. If development or CI usage drew from the same project as the shipping key, a busy debugging session or a flaky CI run could exhaust the fleet's daily quota before a single real user searches. Per policy III.D.1.c (one API project per client), and per the milestone's Pitfall 7 finding, the dev key is created alone in its own project.

**Structural guarantee that keeps this safe even if the runbook is skipped:** every unit test in `CarTubeTests` runs against fixture JSON through `MockURLProtocol` (03-02) — no test can reach `googleapis.com`, so quota-spend-in-tests is impossible by construction, not by discipline. The dev key exists only for the optional live-smoke step in plan 03-03's Task 3, and for any future ad-hoc manual verification during Phase 4/5 development.

---

## 1. Console procedure (in this exact order)

**Enable the API before restricting the key** — Google requires an API to be enabled before a key can name it in an API restriction, and the Console mandates at least one API restriction when creating a key. Doing these out of order is the known trap (same as the shipping-key runbook).

1. Open **console.cloud.google.com** and sign in with the Google account that will own the dev key.
2. Project picker (top bar) → **New project** → name it **`cartube-dev`** (dedicated: nothing else lives in it, and it must NOT be the same project as `cartube-shipping`) → **Create**. Note the **project ID** shown at creation.
3. With the new project selected: **APIs & Services → Library** → search for **YouTube Data API v3** → open it → **Enable**.
4. Verify the enable step: **APIs & Services → Enabled APIs** lists **YouTube Data API v3** with status **ON**. Do not continue until this is true.
5. **APIs & Services → Credentials → Create credentials → API key**.
6. Copy the created key value (a string starting with `AIza`) somewhere temporary. It goes **only** into `Secrets.xcconfig` (section 3) — never into chat, docs, issues, or any git-tracked file.
7. Open the key (pencil icon) and set:
   - **API restrictions:** select **Restrict key** → check **YouTube Data API v3** only. Nothing else.
   - **Application restrictions:** optional for a dev key (unlike the shipping key, which restricts to the two `com.cartube.*` bundle IDs). If restricting, use **iOS apps** and list the same two bundle IDs; if left as **None**, the dev key still cannot call anything but YouTube Data API v3 because of the API restriction above. Either choice is acceptable for a key that never ships in a build.
8. **Save.**

### Only ONE application-restriction type

Same rule as the shipping-key runbook: Google allows exactly one application-restriction type per key. If you choose to restrict at all, use **iOS apps** — do not attempt to also add a Website, IP-address, or Android restriction on the same key.

---

## 2. Quota guard (billing-free alerting)

Optional but recommended, mirroring the shipping-key runbook's quota guard:

1. With the `cartube-dev` project selected: **APIs & Services → Enabled APIs → YouTube Data API v3 → Quotas** tab.
2. Find the daily-request quota row and use its alert control.
3. Set a threshold (e.g. 80% of the daily quota) and a notification channel.
4. No billing account is required — this uses Cloud Monitoring's included alerting.

---

## 3. Delivery into the build

**Separation rule (verbatim):** the shipping project's 100/day bucket is never used by development builds or tests — fixture tests never call the network, and any live verification uses the dev key.

- **For local development:** temporarily swap the dev key value into the root `Secrets.xcconfig`'s `YOUTUBE_API_KEY` line, replacing whatever value is currently there (the shipping key, or the sentinel). This is the same gitignored delivery slot Phase 1 proved — no new pipe is created. Swap the shipping value back in before any App Store build.
- **For CI:** pass the dev key via the `xcodebuild` command-line override documented in `Config/Secrets.xcconfig.example` (`xcodebuild ... YOUTUBE_API_KEY=<dev key>`), so the dev key never touches disk in CI either.

The dev key value goes **nowhere else**: not into `Config/Secrets.xcconfig.example` (keeps `REPLACE_ME`), not into any document, not into the Xcode project file, not into chat if avoidable.

---

## 4. Verification (the agent runs these once a key exists and a live smoke is approved)

### Key restrictions

```bash
gcloud services api-keys list --project=<PROJECT_ID>
gcloud services api-keys describe <KEY_NAME> --project=<PROJECT_ID>
```

Expected: the key's API restriction targets the service `youtube.googleapis.com`; if an application restriction was set, it lists the `com.cartube.*` bundle IDs.

### Live smoke search (one deliberate 2-unit spend)

With the dev key (or the shipping key, if the human explicitly approved spending 2 units from it instead) in `Secrets.xcconfig`, construct `YouTubeSearchService()` and `await search(query: "lofi beats")`. Assert a non-empty result with a filled `duration` field. Record here, from the actual observed run, not fabricated:

- **Query used:** _(recorded at smoke time)_
- **Result count:** _(recorded at smoke time)_
- **Observed `videos.list` duration value (first result):** _(recorded at smoke time)_
- **Key used:** deferred — no live request made

**Status of this section as of 2026-08-18:** deferred by explicit user decision at Task 4's checkpoint. Options presented: (1) provision the `cartube-dev` project now, (2) spend 2 units on the shipping key, (3) skip the smoke this phase. User chose (3) — no Google Cloud action taken, no key created, no network request made. Rationale: the shipping key itself doesn't exist yet either (Phase 1's Google Cloud checkpoint, Task 2, is still pending), so a smoke against either key would have required a fresh Console detour outside this phase's flow. This smoke will run on the first Phase 4 session where a real key (dev or shipping) is available and approved.

### Repo hygiene (must stay clean)

```bash
git grep -nE 'AIza[0-9A-Za-z_-]{30,}'    # must print nothing
git check-ignore -q Secrets.xcconfig     # must exit 0 (still gitignored)
```

---

## 5. Honesty note: the key is public-by-design

Same as the shipping key: any key that ends up embedded in a built IPA is public-by-design — readable via `plutil` on any extracted build, no `strings` needed. The dev key is not intended to ship at all (it only ever lives transiently in a local `Secrets.xcconfig` swap or a CI command-line override), which is the strongest mitigation available: a key that never leaves a developer's machine or a CI runner's environment cannot leak via the shipped binary.

---

## Scope note

This runbook provisions the **development** key only, resolving the Phase 1 deferral. The shipping key and its dedicated `cartube-shipping` project are provisioned separately per `docs/runbooks/google-youtube-api-key.md`. The two projects, and their keys, must never be merged or share application restrictions — that would reintroduce the exact quota-sharing risk this separation exists to prevent.
