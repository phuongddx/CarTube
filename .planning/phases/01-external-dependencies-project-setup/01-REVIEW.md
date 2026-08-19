---
phase: 01-external-dependencies-project-setup
reviewed: 2026-08-19T00:00:00Z
depth: deep
files_reviewed: 6
files_reviewed_list:
  - .gitignore
  - CarTube.xcodeproj/project.pbxproj
  - CarTube/Info.plist
  - Config/Secrets.xcconfig.example
  - docs/runbooks/apple-carplay-entitlement-request.md
  - docs/runbooks/carplay-entitlement-grant-wiring.md
  - docs/runbooks/google-youtube-api-key.md
findings:
  critical: 0
  warning: 4
  info: 3
  total: 7
status: issues_found
---

# Phase 01: Code Review Report

**Reviewed:** 2026-08-19T00:00:00Z
**Depth:** deep
**Files Reviewed:** 6 (7 listed, `CarTube.xcodeproj/project.pbxproj` counted once)
**Status:** issues_found

## Summary

Reviewed the build-time YouTube API key injection pipeline (`Secrets.xcconfig.example` → `project.pbxproj` base configuration → `Info.plist` `$(YOUTUBE_API_KEY)` substitution), the `.gitignore` rule protecting the real secrets file, and the two CarPlay-entitlement runbooks plus the Google API key provisioning runbook.

The core wiring is sound: the project-level `baseConfigurationReference` on both Debug and Release `XCBuildConfiguration` entries correctly points at `Secrets.xcconfig`, no target overrides it, `GENERATE_INFOPLIST_FILE = YES` merges cleanly with `INFOPLIST_FILE`, the plist lints clean, no real API key or secret is anywhere in git history, and `Secrets.xcconfig` itself is correctly gitignored.

The findings below are concentrated in a documentation/reality gap: the CarPlay runbooks assert factual claims about the "current" state of `project.pbxproj` (team ID, bundle IDs) that no longer match the file as committed, which is exactly the kind of drift a "script to follow top to bottom" cannot tolerate if it is ever re-run or used as a reference by someone without side-channel context. There is also a minor branding leftover in `Info.plist` and a couple of small pbxproj/doc quality nits. No blockers were found — nothing here causes incorrect runtime behavior, a crash, or a security exposure beyond what the runbooks already explicitly and correctly disclose (client-embedded API keys are public-by-design).

## Warnings

### WR-01: CarPlay entitlement runbook's stated team ID no longer matches the committed project file

**File:** `docs/runbooks/apple-carplay-entitlement-request.md:12,16,21,28`
**Issue:** The runbook states as fact, in four places, that the submission must come from team `U67AKNW8PW` and that this is the team currently on the committed `project.pbxproj`. The actual `project.pbxproj` reviewed here has `DEVELOPMENT_TEAM = K2TYLYAWMK;` on every build configuration (lines 689, 732, 769, 796, 823, 846) — `U67AKNW8PW` does not appear anywhere in the file. A reader who follows only this runbook (without independently discovering the correction recorded elsewhere in `.planning/`) would sign in with the wrong Apple ID/team, register the App ID under the wrong team, and produce an entitlement grant that cannot attach to the actual signing team the project builds with — CarPlay entitlements are bound permanently to the App ID/team pair, so this is not a cosmetic mismatch if acted on literally.

Because the runbook explicitly frames itself as "the exact script to follow," it should not carry a load-bearing factual claim about repo state that has since diverged, with no in-document flag that the claim is stale.
**Fix:** Add a visible correction note at the top of the "Current state" section and every place `U67AKNW8PW` appears, e.g.:
```markdown
> **Correction:** the team ID above (`U67AKNW8PW`) is the upstream fork author's team and is
> stale as of Phase 2. The project's actual signing team is `K2TYLYAWMK`. Use `K2TYLYAWMK`
> if this runbook is ever re-run; do not sign in as `U67AKNW8PW`.
```
Or, since the actual submission already happened correctly under `K2TYLYAWMK` per project records, mark the entire runbook `[HISTORICAL — team ID superseded, see STATE.md]` so a future reader doesn't treat stale prerequisite text as current instructions.

### WR-02: Runbook's "current state" description of bundle IDs is stale relative to the reviewed pbxproj

**File:** `docs/runbooks/apple-carplay-entitlement-request.md:21`
**Issue:** This line asserts: "Committed project file still carries the upstream IDs: `PRODUCT_BUNDLE_IDENTIFIER = com.avangelista.CarTube;` ... The `com.cartube.carplay` values are a known Phase 2 change, not a reason to hesitate." The `project.pbxproj` reviewed here already has `PRODUCT_BUNDLE_IDENTIFIER = com.cartube.carplay` (lines 708, 751) and `com.cartube.carplay.playon` (lines 781, 808) in every Debug/Release configuration for both the app and share-extension targets — the "Phase 2 change" this runbook describes as pending has already landed. Same root cause as WR-01: a runbook that states current-file facts drifts out of sync with the file it describes and is not self-correcting.
**Fix:** Same remediation as WR-01 — mark the "Current state" section as a point-in-time historical snapshot rather than a live description, or update it to reflect the bundle IDs actually in the file today.

### WR-03: Test target bundle ID was never rebranded, unlike the app and share-extension targets

**File:** `CarTube.xcodeproj/project.pbxproj:831,854`
**Issue:** `CarTubeTests`'s `PRODUCT_BUNDLE_IDENTIFIER` is `com.avangelista.CarTubeTests` in both Debug and Release, while the app (`com.cartube.carplay`) and share extension (`com.cartube.carplay.playon`) were rebranded. This is not documented as an intentional exception anywhere in the reviewed files — it reads as an overlooked target rather than a deliberate scope boundary. Test bundle IDs don't get distributed or need entitlements, so this isn't functionally broken, but it's an inconsistency that will look like an unfinished rebrand to the next person auditing bundle identifiers project-wide (e.g., via `git grep avangelista`).
**Fix:** Either rebrand it for consistency (`com.cartube.carplay.tests` or similar) or add a one-line note to the rebrand decision record explaining the test target is deliberately left alone (it never ships and has no entitlement dependency).

### WR-04: App Store category (`video`) sits in tension with the CarPlay entitlement category being requested (`audio`), and the runbook's residual-risk note doesn't mention it

**File:** `CarTube.xcodeproj/project.pbxproj:695,738` and `docs/runbooks/apple-carplay-entitlement-request.md:51-59`
**Issue:** `INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.video"` classifies the app as a video app for the App Store, while the CarPlay entitlement request is deliberately worded to position the app as audio-only ("Residual risk, recorded deliberately: the app does render content on the car screen..."). The runbook already candidly flags the on-screen-rendering residual risk but doesn't mention that the app's own declared App Store category is `video` — an additional, easily-checked data point a CarPlay reviewer could cite against the audio-category framing. This compounds a risk the team has already chosen to accept, so it's not a blocker, but it's a fact the existing "residual risk" paragraph should have surfaced since it's a one-line pbxproj lookup away from contradicting the submitted request text.
**Fix:** Add one sentence to the "Why the wording is scoped this way" section noting the App Store category is `video` and that this was a known/accepted part of the same residual risk, so it doesn't read as an omission if raised during Apple's review.

## Info

### IN-01: `Info.plist` still carries the pre-rebrand app name in `CFBundleURLName`

**File:** `CarTube/Info.plist:11`
**Issue:** `CFBundleURLName` is `com.avangelista.TrollTube` — the upstream fork's old product name — while `CFBundleURLSchemes` correctly uses the new `cartube` scheme (line 14) and the bundle-ID rebrand elsewhere uses `com.cartube.*`. `CFBundleURLName` has no functional effect on URL handling (only `CFBundleURLSchemes` does), so this is cosmetic, but it's a visible branding leftover in a file this phase touched for the API key wiring.
**Fix:**
```xml
<key>CFBundleURLName</key>
<string>com.cartube.carplay</string>
```

### IN-02: `CarTubeTests` build-configuration list orders Release before Debug, inconsistent with every other target

**File:** `CarTube.xcodeproj/project.pbxproj:891-899`
**Issue:** The `XCConfigurationList` for `CarTubeTests` (`609660AD72215C94C3D2FC8F`) lists `buildConfigurations` as `(Release, Debug)`, while the project-level, `CarTube`, and `PlayOnCarTube` lists all use `(Debug, Release)`. `defaultConfigurationName = Release` still resolves correctly regardless of array order, so this has no build-behavior impact, but it's an inconsistency that stands out on diff review and suggests a hand-edit rather than an Xcode-generated change.
**Fix:** Reorder to `(ADCF53AF25183D9AF7AC4DB4 /* Debug */, C17D7BE8B050E005C833E454 /* Release */)` to match the rest of the file.

### IN-03: `Info.plist`'s `UIApplicationSceneManifest` key lacks the leading-tab indentation of its siblings

**File:** `CarTube/Info.plist:20-34`
**Issue:** Every top-level key in the dict is indented one tab except `<key>UIApplicationSceneManifest</key>` (line 20), which starts at column 0. `plutil -lint` confirms the file is still valid XML/plist, so this is purely a formatting inconsistency, likely from a manual edit that didn't match the surrounding indentation style.
**Fix:** Add the leading tab to match `CFBundleURLTypes` and `YOUTUBE_API_KEY` above it.

---

_Reviewed: 2026-08-19T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_
