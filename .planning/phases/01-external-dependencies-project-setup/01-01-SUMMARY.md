---
phase: 01
plan: 01
subsystem: build-config
tags: [xcconfig, secrets, info-plist, repo-hygiene, build-system]
requires: []
provides:
  - "Build setting YOUTUBE_API_KEY delivered at build time into CarTube.app/Info.plist via Secrets.xcconfig base configuration"
  - "Config/Secrets.xcconfig.example template (committed) with copy + CI-override instructions"
  - ".gitignore gate keeping Secrets.xcconfig out of git"
affects:
  - CarTube.xcodeproj/project.pbxproj
  - CarTube/Info.plist
tech-stack:
  added: []
  patterns:
    - "xcconfig base-configuration reference (project-level Debug+Release) → $(YOUTUBE_API_KEY) Info.plist substitution"
key-files:
  created:
    - Config/Secrets.xcconfig.example
  modified:
    - .gitignore
    - CarTube/Info.plist
    - CarTube.xcodeproj/project.pbxproj
decisions:
  - "xcconfig attached at project level (not target level) — project settings layer first, no target defines YOUTUBE_API_KEY, so layering is unambiguous"
  - "Secrets.xcconfig lives at repo root and is gitignored; example committed at Config/Secrets.xcconfig.example"
  - "Sentinel value BUILD_TIME_SENTINEL_REPLACE_WITH_REAL_KEY (not AIza-shaped) so verification greps can't false-positive; real key lands in plan 01-03"
metrics:
  duration: 25m
  completed: 2026-08-18
status: complete
actuals:
  tokens: 3400
  tasks: 2
  commits: 2
---

# Phase 01 Plan 01: Build-Time Secret Injection Summary

Xcode xcconfig base configuration → `$(YOUTUBE_API_KEY)` Info.plist substitution wired end-to-end, with gitignore and AIza-grep hygiene gates proving no key material can enter the public fork.

## What Was Done

- `Config/Secrets.xcconfig.example` committed — placeholder `YOUTUBE_API_KEY = REPLACE_ME` with header documenting the mandatory copy step, the observed missing-file error, the gitignore rule, and the CI recipe (copy example + `xcodebuild YOUTUBE_API_KEY=...` command-line override).
- Root `Secrets.xcconfig` created (gitignored, never committed) holding `YOUTUBE_API_KEY = BUILD_TIME_SENTINEL_REPLACE_WITH_REAL_KEY`.
- `.gitignore` gained the section `# Build-time secrets — never commit (public fork)` with entry `Secrets.xcconfig`.
- `CarTube/Info.plist` gained top-level `YOUTUBE_API_KEY` → `$(YOUTUBE_API_KEY)`, alongside the existing `$(PRODUCT_MODULE_NAME)` substitution.
- `CarTube.xcodeproj/project.pbxproj` — via throwaway ruby/xcodeproj script (deleted after use): `Secrets.xcconfig` file reference in the main group (no build phase membership — it is configuration input, not a resource) and `baseConfigurationReference` on project-level Debug and Release configurations only. No target-level attachment.
- Task 2 proved the fresh-clone trade-off empirically: with `Secrets.xcconfig` moved aside the build fails before compiling with `error: Unable to open base configuration reference file '<repo>/Secrets.xcconfig'`; restore → `BUILD SUCCEEDED`. Template updated with the observed wording.

## Verification Evidence

- `xcodebuild -project CarTube.xcodeproj -scheme CarTube -destination 'platform=iOS Simulator,name=iPhone Air' build` → `** BUILD SUCCEEDED **`
- `-showBuildSettings` → `YOUTUBE_API_KEY = BUILD_TIME_SENTINEL_REPLACE_WITH_REAL_KEY`
- `plutil -extract YOUTUBE_API_KEY raw <BUILT_PRODUCTS_DIR>/CarTube.app/Info.plist` → `BUILD_TIME_SENTINEL_REPLACE_WITH_REAL_KEY` (substitution proven into the product)
- `git check-ignore -q Secrets.xcconfig` → exit 0; `git status` does not list it as untracked
- `git grep -nE 'AIza[0-9A-Za-z_-]{30,}'` → zero matches across tracked files (after both tasks)
- Missing-file build failure captured verbatim (see above) and rebuild-green after restore

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 (tracer) | cb64a56 | feat(01-01): wire build-time YouTube API key delivery via xcconfig |
| 2 | 7172e50 | docs(01-01): document mandatory Secrets.xcconfig copy step from observed failure |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Task 1 pbxproj staging nearly committed the user's unrelated uncommitted pbxproj modifications**
- **Found during:** Task 1 (pre-commit)
- **Issue:** `CarTube.xcodeproj/project.pbxproj` carried pre-existing local modifications (objectVersion 55→90 bump, Assets.xcassets path fix, DEVELOPMENT_TEAM and bundle-ID changes, build-phase attribute removals). The xcodeproj-gem rewrite produced a full-file diff, and a plain `git add` would have mixed the user's unrelated WIP into the task commit. During safe staging the working-tree copy of those user mods was temporarily overwritten; they were fully restored afterwards from the captured diff inventory.
- **Fix:** Staged a version equal to HEAD + exactly the 4 additive Secrets lines (file reference, main-group entry, two `baseConfigurationReference` lines), then re-applied the user's deltas to the working tree. Verified post-commit: working-tree pbxproj diff contains zero Secrets-related lines and only the user's original modifications; `plutil -lint` OK; xcodeproj re-parse shows base configuration attached on Debug and Release.
- **Files modified:** CarTube.xcodeproj/project.pbxproj (staging only; working tree restored)
- **Commit:** cb64a56 (task commit contains only plan-scoped lines)

## Notes for Downstream Plans

- `CarTube.xcodeproj/project.pbxproj` had pre-existing local (uncommitted) modifications at execution start — Xcode-26-era objectVersion 90 bump, Assets.xcassets path normalization, per-config DEVELOPMENT_TEAM (57RCRLS3QS / K2TYLYAWMK) and Debug bundle IDs (`com.cartube.carplay` / `com.cartube.carplay.playon`), plus `defaultConfigurationIsVisible`/`buildActionMask` removals. These remain uncommitted in the working tree, untouched by this plan's commits, and belong to the user/phase-02+ work.
- Phase 3 reads the key with `Bundle.main.object(forInfoDictionaryKey: "YOUTUBE_API_KEY") as? String`.
- The key is public-by-design once inside the IPA (T-01-02 accepted); plan 01-03 pairs it with Google API + bundle-ID restrictions and quota alerting.
- CI never needs the gitignored file on disk: `xcodebuild ... YOUTUBE_API_KEY="$YOUTUBE_API_KEY" build` overrides at the command line.

## Self-Check: PASSED

- Files exist: Config/Secrets.xcconfig.example, .gitignore, CarTube/Info.plist, CarTube.xcodeproj/project.pbxproj — FOUND
- Secrets.xcconfig gitignored (not untracked) — FOUND
- Commits cb64a56, 7172e50 — FOUND
