# Fastlane TestFlight Pipeline

CarTube's TestFlight pipeline mirrors the NextGen-Limited/ios-stress-app setup (same Apple team `K2TYLYAWMK`, same Apple ID, same credential contract). One command — `bundle exec fastlane upload_beta` — produces a match-signed Release build, runs the private-API scan gate on both binaries, and uploads to TestFlight.

This pipeline **supersedes phase 06-03 Task 3's raw-script approach** (`scripts/release-archive.sh` + `ExportOptions.plist` + `altool`). When 06-03 executes, `bundle exec fastlane upload_beta` is the corrected ground truth for the archive → export → scan → upload pipeline. Note also that 06-03's must-haves carry the stale upstream team ID `U67AKNW8PW`; the fastlane setup pins the correct team `K2TYLYAWMK` everywhere.

## Lanes

| Lane | Purpose |
|------|---------|
| `tests` | Runs the unit test suite on the iPhone 17 simulator (no credentials needed) |
| `setup_match` | One-time bootstrap: generates the distribution cert + App Store profiles into the Match repo |
| `build_only` | Builds and scan-gates the IPA without uploading (CI validation) |
| `upload_beta` | Full pipeline: build → scan gate → TestFlight upload |

### upload_beta fixed order

1. Credential guard — fails fast with an actionable message if the ASC env vars are missing
2. `app_store_connect_api_key` — auth from env, never from repo files
3. `match` (readonly) — fetches the App Store profiles for `com.cartube.carplay` and `com.cartube.carplay.playon`
4. `update_code_signing_settings` — switches both targets to manual match profiles
5. `gym` — Release archive at `build/CarTube.xcarchive`, IPA export to `build/export/CarTube.ipa`
6. **Private-API scan gate** — `scripts/scan-private-apis.sh` runs on BOTH archive binaries (`CarTube.app/CarTube` and `PlugIns/PlayOnCarTube.appex/PlayOnCarTube`); any marker hit exits non-zero and **aborts the lane before upload**
7. `pilot` — uploads to TestFlight with `skip_waiting_for_build_processing: true`

## 1. One-time setup

1. Install gems (project-local, gitignored):

   ```sh
   bundle config set --local path vendor/bundle
   bundle install
   ```

2. App Store Connect API credentials. The `.p8` key file is already at `~/.appstoreconnect/AuthKey.p8` on this machine (shared with the stress-app setup) — only the identifiers need exporting:

   ```sh
   export APP_STORE_CONNECT_API_KEY_ID=<key id>
   export APP_STORE_CONNECT_ISSUER_ID=<issuer id>
   ```

   Find both in App Store Connect → Users and Access → Integrations → Team Keys. If the key file is ever missing, `APP_STORE_CONNECT_API_KEY_PATH` overrides the path, and CI provides the content via `APP_STORE_CONNECT_API_KEY_P8` (the Fastfile writes it to the path at runtime).

3. Match repo access (same values as the stress-app repo's GitHub secrets):

   ```sh
   export MATCH_GIT_URL=<match repo url>
   export MATCH_PASSWORD=<match encryption passphrase>
   ```

4. Enable the CarPlay capability on the `com.cartube.carplay` App ID at developer.apple.com (Certificates, IDs & Profiles) **before** generating profiles — the entitlement was granted to team K2TYLYAWMK on 2026-08-18 but must be attached to the App ID by a human in the portal.

5. Bootstrap certs and profiles into the Match repo (one time, `readonly: false, force: true`):

   ```sh
   bundle exec fastlane setup_match
   ```

## 2. Local usage

```sh
bundle exec fastlane tests        # unit suite on the iPhone 17 simulator, zero env setup
bundle exec fastlane build_only   # Release build + scan gate, no upload
bundle exec fastlane upload_beta  # full pipeline to TestFlight
```

Note: `build_only` and `upload_beta` flip both targets to manual signing in `CarTube.xcodeproj/project.pbxproj` (via `update_code_signing_settings`). In CI the checkout is ephemeral; locally, revert with `git checkout -- CarTube.xcodeproj/project.pbxproj` afterwards.

## 3. GitHub Actions (`.github/workflows/deploy.yml`)

Manual trigger only (`workflow_dispatch`) — CarTube has no CI workflow chain to hook a `workflow_run` trigger onto yet. Runs `bundle exec fastlane upload_beta` on `macos-15` with Xcode 26.3.

Repository secrets to add at github.com/phuongddx/CarTube → Settings → Secrets and variables → Actions. All but the last are copied verbatim from the stress-app repo's settings (same names, same values):

| Secret | Source |
|--------|--------|
| `APP_STORE_CONNECT_API_KEY_ID` | stress-app repo secret (same team key) |
| `APP_STORE_CONNECT_ISSUER_ID` | stress-app repo secret |
| `APP_STORE_CONNECT_API_KEY_P8` | stress-app repo secret (full `.p8` content) |
| `MATCH_PASSWORD` | stress-app repo secret |
| `MATCH_GIT_URL` | stress-app repo secret |
| `MATCH_GIT_BASIC_AUTHORIZATION` | stress-app repo secret |
| `YOUTUBE_API_KEY` | CarTube-specific: the shipping key from the Google Console runbook (`docs/runbooks/google-youtube-api-key.md`) |

CI provisions `Secrets.xcconfig` from `Config/Secrets.xcconfig.example` (satisfies the base-configuration file requirement) and injects the real `YOUTUBE_API_KEY` as an xcodebuild override per the documented CI recipe — the key never touches disk in CI.

## 4. Signing model

Manual signing via fastlane match under team `K2TYLYAWMK` (STATE.md ground truth — the upstream `U67AKNW8PW` from the original pbxproj is superseded and must not be used). Match stores the Apple Distribution cert and both App Store profiles ("match AppStore com.cartube.carplay", "match AppStore com.cartube.carplay.playon") encrypted in a private git repo; CI and local runs fetch them readonly.

## 5. Secrets hygiene

- No key material, key IDs, or issuer IDs live in the repo — all auth is env-var driven
- The `.p8` stays outside the repo (`~/.appstoreconnect/AuthKey.p8` locally, secret-injected in CI)
- `Gemfile.lock` pins the fastlane version; gems install to gitignored `vendor/bundle`
- `Secrets.xcconfig` (YouTube key) remains gitignored; CI uses the example + override recipe

## 6. Later extensions

The stress-app reference also carries `distribute_beta` (TestFlight group distribution), `release` (ASC metadata upload), `increment_build` (TestFlight-driven build numbering), and Slack notifications. Deliberately omitted here — copy them from the reference Fastfile when needed.
