---
phase: quick-260819-tkz-set-up-fastlane-for-testflight-pipeline
plan: 01
subsystem: release-pipeline
tags: [fastlane, testflight, match, ci, signing]
requires:
  - scripts/scan-private-apis.sh (INFRA-05 gate, Phase 02)
  - Config/Secrets.xcconfig.example CI recipe (Phase 02)
provides:
  - bundler-pinned fastlane with tests/setup_match/build_only/upload_beta lanes
  - match-based manual signing contract for com.cartube.carplay + .playon under K2TYLYAWMK
  - workflow_dispatch TestFlight deploy workflow (.github/workflows/deploy.yml)
affects:
  - 06-03 (fastlane upload_beta supersedes Task 3's raw release-archive.sh + altool pipeline)
tech-stack:
  added: [fastlane 2.238.0 (Gemfile ~> 2.236), xcpretty ~> 0.4, fastlane match]
  patterns:
    - env-only credential contract (APP_STORE_CONNECT_* / MATCH_*) mirrored from NextGen-Limited/ios-stress-app
    - scan gate between gym and pilot; fastlane sh raises on non-zero exit
key-files:
  created:
    - Gemfile
    - Gemfile.lock
    - fastlane/Appfile
    - fastlane/Matchfile
    - fastlane/Fastfile
    - fastlane/README.md
    - .github/workflows/deploy.yml
    - docs/submission/fastlane-pipeline.md
  modified:
    - .gitignore
decisions:
  - Mirror stress-app credential/signing contract (user directive) over the plan's ASC_KEY_ID cloud-signing design
  - Shared build_release_ipa/scan_private_apis helpers so build_only gets the identical scan-gated build as upload_beta
  - deploy.yml keeps gem cache, drops DerivedData AND SPM caches (pbxproj has zero SwiftPackage references — 02-04 removed the last one)
metrics:
  duration: 13m
  completed: 2026-08-19
status: complete
actuals:
  tokens: 8300
  tasks: 2
  commits: 3
---

# Quick Task 260819-tkz: Fastlane TestFlight Pipeline Summary

Match-signed fastlane TestFlight pipeline (upload_beta with dual private-API scan gate) mirroring the stress-app's credential contract, plus tests lane, workflow_dispatch deploy workflow, and a docs/submission runbook.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 (tracer) | Bundler scaffold through guarded upload pipeline | e67ba8c | Gemfile, Gemfile.lock, fastlane/{Appfile,Matchfile,Fastfile}, .gitignore |
| 2 | tests lane + deploy workflow + pipeline docs | 938e052 | fastlane/Fastfile, .github/workflows/deploy.yml, docs/submission/fastlane-pipeline.md |
| 2b | Track fastlane-generated lane README | aaf1cf5 | fastlane/README.md |

## Verification Evidence

- `bundle exec fastlane lanes` lists all four lanes (tests, setup_match, build_only, upload_beta)
- Guard branch proven by real run: `env -u APP_STORE_CONNECT_API_KEY_ID -u APP_STORE_CONNECT_ISSUER_ID bundle exec fastlane ios upload_beta` exits 1 with a message naming both env vars, the existing `~/.appstoreconnect/AuthKey.p8` path, and the Team Keys click path — before any xcodebuild work
- `bundle exec fastlane ios tests` ran the real suite: **96 tests, 0 failures** (Test Succeeded, run_tests 226s) — baseline preserved through the bundler-pinned fastlane
- Negative greps pass: no `U67AKNW8PW`, no `AuthKey_<ID>.p8` filename shapes in Gemfile or fastlane/
- `.gitignore` covers `vendor/`, `.bundle/` (build/, *.ipa, fastlane/report.xml, fastlane/test_output already ignored)
- deploy.yml parses as valid YAML; doc greps confirm env vars, Integrations click path, scan gate, and 06-03 cross-reference

## Deviations from Plan

All six orchestrator-supplied deviations (user's stress-app reference arrived after planning) were applied over the plan:

**1. [Authoritative] Env var contract replaced** — `APP_STORE_CONNECT_API_KEY_ID`/`APP_STORE_CONNECT_ISSUER_ID` (+ optional `APP_STORE_CONNECT_API_KEY_P8` content for CI, `APP_STORE_CONNECT_API_KEY_PATH` defaulting to `~/.appstoreconnect/AuthKey.p8`) instead of the plan's `ASC_KEY_ID`/`ASC_ISSUER_ID` + `~/.private_keys` path. The reference's `api_key` helper (writes P8 content to the path when absent — CI case) copied nearly verbatim. Guard message states the .p8 is already at `~/.appstoreconnect/AuthKey.p8` and points at Team Keys. Task 1 verify commands adapted to the new names.

**2. [Authoritative] Signing replaced: match manual signing, not automatic cloud signing** — added `fastlane/Matchfile` (MATCH_GIT_URL env, git storage, appstore type, K2TYLYAWMK, both bundle IDs), `setup_match` lane (readonly: false, force: true), and in the build path: `match(readonly: true)` → `update_code_signing_settings` to manual per target ("match AppStore com.cartube.carplay" / "...playon") → gym `export_options.provisioningProfiles` map. `MATCH_GIT_URL` unset triggers its own `UI.user_error!` pointing at the stress-app secrets. The plan's `-allowProvisioningUpdates`/authenticationKey xcargs are gone.

**3. [Authoritative] Lane names mirror the reference** — `upload_beta` (not `beta`), `build_only`, `setup_match`, `tests`. distribute_beta/release/increment_build/Slack omitted (documented as later copy-from-reference extensions).

**4. [Plan kept] Scan gate retained** — `scripts/scan-private-apis.sh` runs on BOTH xcarchive binaries (app + PlayOnCarTube.appex) after gym, before pilot; `sh` raises on non-zero exit, aborting before upload. Absolute paths built from `REPO_ROOT = File.expand_path("..", __dir__)` per the plan.

**5. [Authoritative] deploy.yml added** — workflow_dispatch only (no workflow_run — no CI chain to hook onto), macos-15, Xcode 26.3, stress-app secret names, APP_IDENTIFIER/EXTENSION_IDENTIFIER/TEAM_ID env, `bundle exec fastlane upload_beta`. **Sub-deviation:** SPM cache dropped along with DerivedData cache — the deviation said "keep SPM cache" but the pbxproj has zero `XCRemoteSwiftPackageReference`/`XCLocalSwiftPackageReference` entries (STATE 02-04: Dynamic SPM package fully removed), so the cache would key on a nonexistent Package.resolved; the deviation's own "if not applicable" conditional covers this.

**6. [Rule 2 — missing critical functionality] Secrets.xcconfig provisioning in CI** — a fresh checkout fails the build without root `Secrets.xcconfig` (intentional, Phase 02 design). deploy.yml provisions it from `Config/Secrets.xcconfig.example` and passes the real key via a new `YOUTUBE_API_KEY` repo secret; the Fastfile appends `YOUTUBE_API_KEY=<env>` to gym xcargs only when the env var is set — exactly the CI recipe documented in the example file (key never touches disk in CI; GitHub masks it in logs). Without this, every CI deploy run would fail at the base-configuration reference.

## Authentication Gates

None hit. The full upload path's dependency on missing credentials is the designed guard behavior, not a gate encountered mid-run.

## Known Limitations (by design, documented in the runbook)

- Full upload_beta path unexecuted until the user exports the API key identifiers, sets MATCH_GIT_URL/MATCH_PASSWORD, enables CarPlay on the App ID in the portal, and runs `setup_match` once (recorded in .planning/WINDOWS.md as unrun-verify)
- `build_only`/`upload_beta` mutate project.pbxproj signing settings via update_code_signing_settings (reference behavior); local revert command documented
- GitHub secrets must be added to phuongddx/CarTube (table in docs/submission/fastlane-pipeline.md)

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: information-disclosure | .github/workflows/deploy.yml | New secret-handling surface: six ASC/match secrets + YOUTUBE_API_KEY flow through Actions env; YOUTUBE_API_KEY rides gym xcargs (masked by Actions log redaction) |
| threat_flag: file-write | fastlane/Fastfile | api_key helper writes APP_STORE_CONNECT_API_KEY_P8 env content to ~/.appstoreconnect/AuthKey.p8 when absent (CI-only path, outside repo; mirrored from reference) |

## Self-Check: PASSED

- FOUND: Gemfile, Gemfile.lock, fastlane/Appfile, fastlane/Matchfile, fastlane/Fastfile, fastlane/README.md, .github/workflows/deploy.yml, docs/submission/fastlane-pipeline.md
- FOUND commits: e67ba8c, 938e052, aaf1cf5
