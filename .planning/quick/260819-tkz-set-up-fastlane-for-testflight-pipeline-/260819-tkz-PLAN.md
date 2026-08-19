---
phase: quick-260819-tkz-set-up-fastlane-for-testflight-pipeline
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - Gemfile
  - Gemfile.lock
  - fastlane/Appfile
  - fastlane/Fastfile
  - .gitignore
  - docs/submission/fastlane-pipeline.md
autonomous: true
requirements: [SHIP-03]

estimate:
  tokens: 40000
  raw_tokens: 40000
  tasks: 2
  confidence: low

must_haves:
  truths:
    - "`bundle exec fastlane lanes` lists a beta lane and a tests lane after a plain `bundle install` from a fresh clone"
    - Running the beta lane without ASC_KEY_ID / ASC_ISSUER_ID set (or with the .p8 missing from ~/.private_keys) fails immediately with an actionable message naming both env vars and the expected key path — before any xcodebuild work starts
    - The beta lane order is fixed guard -> app_store_connect_api_key -> cloud-signed Release archive+export -> scan-private-apis.sh on BOTH archive binaries (app + appex) -> TestFlight upload; a non-zero scan exit aborts the lane before upload
    - No key material, key IDs, issuer IDs, or the stale upstream team ID exist in any tracked fastlane/bundler file; team identity is K2TYLYAWMK everywhere
  artifacts:
    - Gemfile + Gemfile.lock (fastlane pinned via bundler)
    - fastlane/Appfile (app_identifier com.cartube.carplay, team_id K2TYLYAWMK, no apple_id)
    - fastlane/Fastfile (tests + beta lanes)
    - .gitignore additions (vendor/, .bundle/)
    - docs/submission/fastlane-pipeline.md (env-var wiring, key creation click path, lane usage, 06-03 relationship)
  key_links:
    - ENV ASC_KEY_ID / ASC_ISSUER_ID -> app_store_connect_api_key -> both gym xcargs/export_xcargs authentication flags AND upload_to_testflight api_key (single env-derived credential source, zero repo residue)
    - gym archive_path build/CarTube.xcarchive -> scan-private-apis.sh binary paths under Products/Applications/ -> upload only after both scans exit 0
    - Appfile team_id K2TYLYAWMK -> export_options teamID (stale upstream team ID negative-gated)
---

<objective>
Set up fastlane as the CarTube TestFlight pipeline tooling: Gemfile-pinned fastlane, Appfile with the ground-truth team identity, and a Fastfile whose beta lane implements the same archive -> export -> private-API scan gate -> upload pipeline that phase plan 06-03 Task 3 specifies with raw xcodebuild + ExportOptions.plist + altool. fastlane is the user-chosen tooling to fulfill that pipeline; signing is automatic/cloud signing via an App Store Connect API key (no local Apple Distribution cert exists for team K2TYLYAWMK — the ASC key lets xcodebuild cloud-sign via -allowProvisioningUpdates-style authentication flags).

The ASC API key does NOT exist yet; the user creates it later. Everything here must therefore be verifiable without the key: lanes parse, the guard fails fast with a clear actionable message, and no credential shape ever enters the repo.

Purpose: one command (`bundle exec fastlane ios beta`) produces a scan-gated, cloud-signed TestFlight upload once the user provisions the ASC key — replacing the raw-script half of 06-03 with maintained tooling.
Output: Gemfile, Gemfile.lock, fastlane/Appfile, fastlane/Fastfile, .gitignore additions, docs/submission/fastlane-pipeline.md.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.planning/phases/06-testflight-submission-package/06-03-PLAN.md
@scripts/scan-private-apis.sh
@.gitignore
</context>

<tasks>

<task type="tracer">
  <name>Task 1: End-to-end fastlane beta lane — bundler scaffold through guarded upload pipeline</name>
  <files>Gemfile, Gemfile.lock, fastlane/Appfile, fastlane/Fastfile, .gitignore</files>
  <precondition>ruby 3.2+ with bundler on PATH (ground truth: ruby 3.2.3, bundler available, fastlane 2.x at /opt/homebrew/bin/fastlane) and network access to rubygems.org for bundle install.</precondition>
  <reversibility rating="reversible">Plain config files plus regenerable vendor/ gem install; deleting Gemfile + fastlane/ restores prior state.</reversibility>
  <action>
  Wire the ONE pipeline path end to end: bundler -> Appfile -> Fastfile beta lane (guard -> api key -> archive/export -> scan gate -> upload). No other lanes yet; Task 2 expands.

  1. Gemfile at repo root: source rubygems.org, gem "fastlane". Install with `bundle config set --local path vendor/bundle` then `bundle install`; commit Gemfile and Gemfile.lock. Append `vendor/` and `.bundle/` to the existing .gitignore fastlane section (build/, *.ipa, *.dSYM, fastlane/report.xml, fastlane/Preview.html, fastlane/test_output are already ignored — do not duplicate; fastlane/README.md, if fastlane generates it, stays tracked).

  2. fastlane/Appfile: app_identifier "com.cartube.carplay", team_id "K2TYLYAWMK". No apple_id line — auth is API-key only. The stale upstream team ID recorded in STATE.md decision 06-02 as superseded must appear nowhere in fastlane files or the Gemfile (the verify gate enforces this; do not mention it in code or comments).

  3. fastlane/Fastfile with default_platform(:ios) and a single `beta` lane implementing this exact order:
     a. Guard FIRST, before any action: read ENV["ASC_KEY_ID"] and ENV["ASC_ISSUER_ID"]; derive key_path via File.expand_path from the home directory pattern ~/.private_keys/AuthKey_ + key id + .p8. If either env var is nil/empty or File.exist?(key_path) is false, call UI.user_error! with one message that names both env var names, prints the derived key path it expected, and points at the App Store Connect click path (Users and Access -> Integrations -> App Store Connect API -> Team Keys). This is the lane's failure mode until the user creates the key — it must be self-explanatory.
     b. api_key = app_store_connect_api_key(key_id:, issuer_id:, key_filepath: key_path). Values come only from ENV / the derived path — never literals.
     c. Compute repo_root = File.expand_path("..", __dir__) inside the Fastfile and build absolute paths from it for every filesystem argument (archive path, output dir, scan script, binaries) so fastlane's working-directory behavior can never misresolve them.
     d. build_app (gym): project CarTube.xcodeproj, scheme "CarTube", configuration "Release", export_method "app-store-connect", archive_path {repo_root}/build/CarTube.xcarchive, output_directory {repo_root}/build/export, output_name "CarTube.ipa", export_options hash with signingStyle "automatic" and teamID "K2TYLYAWMK". Pass the cloud-signing authentication flags -allowProvisioningUpdates, -authenticationKeyPath {key_path}, -authenticationKeyID, -authenticationKeyIssuerID through BOTH xcargs and export_xcargs — archive and exportArchive each need them, since no local Apple Distribution certificate exists for this team and cloud signing via the ASC key is the chosen direction.
     e. Scan gate BETWEEN export and upload: invoke {repo_root}/scripts/scan-private-apis.sh twice via fastlane's sh action — once on {archive}/Products/Applications/CarTube.app/CarTube and once on {archive}/Products/Applications/CarTube.app/PlugIns/PlayOnCarTube.appex/PlayOnCarTube. sh raises on non-zero exit, which is exactly the contract: any marker hit aborts the lane before upload. Both invocations must precede step f unconditionally.
     f. upload_to_testflight(api_key: api_key, ipa: {repo_root}/build/export/CarTube.ipa, skip_waiting_for_build_processing: true).

  The full archive path cannot run yet (no ASC key exists); the runnable end-to-end proof for this task is the guard branch plus lane parsing — run the verify command for real and record its output in the SUMMARY.
  </action>
  <verify>
    <automated>test -f Gemfile.lock && bundle exec fastlane lanes 2>&1 | grep -q 'beta' && ! env -u ASC_KEY_ID -u ASC_ISSUER_ID bundle exec fastlane ios beta >/dev/null 2>&1 && env -u ASC_KEY_ID -u ASC_ISSUER_ID bundle exec fastlane ios beta 2>&1 | grep -q 'ASC_KEY_ID' && ! grep -rq 'U67AKNW8PW' Gemfile fastlane/ && ! grep -rqE 'AuthKey_[A-Z0-9]{6,}\.p8' Gemfile fastlane/ && grep -q '^vendor/' .gitignore && grep -q '^\.bundle/' .gitignore</automated>
  </verify>
  <done>bundle exec fastlane lanes parses and lists beta; running the beta lane with the ASC env vars unset exits non-zero with a message naming ASC_KEY_ID (and ASC_ISSUER_ID plus the expected .p8 path); the lane body encodes guard -> api key -> gym (automatic cloud signing, deterministic build/ paths) -> dual scan gate -> upload_to_testflight in that order; no hardcoded key IDs and no stale team ID anywhere in tracked bundler/fastlane files.</done>
</task>

<task type="auto">
  <name>Task 2: tests lane + pipeline documentation under docs/</name>
  <files>fastlane/Fastfile, docs/submission/fastlane-pipeline.md</files>
  <precondition>iPhone 17 simulator runtime installed — the existing baseline `xcodebuild test -scheme CarTube -destination "platform=iOS Simulator,name=iPhone 17"` already passes on this machine.</precondition>
  <reversibility rating="reversible">One added lane and one markdown file.</reversibility>
  <action>
  1. Add a `tests` lane to fastlane/Fastfile: run_tests with project CarTube.xcodeproj, scheme "CarTube", destination "platform=iOS Simulator,name=iPhone 17" (mirror of the established baseline test command). Output lands in fastlane/test_output, which is already gitignored. No credential guard — this lane must run with zero env setup.

  2. Create docs/submission/fastlane-pipeline.md (hand-written docs belong under docs/ per repo convention; docs/submission/ already holds the 06-02 deliverables). Cover, in numbered-runbook style matching the existing docs/runbooks/ convention:
     - ASC API key creation click path: App Store Connect -> Users and Access -> Integrations -> App Store Connect API -> Team Keys -> Generate API Key (Admin or App Manager role); the .p8 downloads exactly once and cannot be re-downloaded.
     - Key placement: ~/.private_keys/AuthKey_&lt;KEYID&gt;.p8, outside the repo, never committed; export ASC_KEY_ID and ASC_ISSUER_ID in the shell before running the beta lane.
     - Usage: `bundle install` once, `bundle exec fastlane ios tests` for the suite, `bundle exec fastlane ios beta` for the pipeline; document the beta lane's fixed order (guard -> api key -> cloud-signed Release archive/export -> scan-private-apis.sh on both the app and PlayOnCarTube.appex binaries -> TestFlight upload) and that any scan hit aborts before upload.
     - Signing model: automatic cloud signing via the ASC key under team K2TYLYAWMK (no local Apple Distribution cert required); note the team ID ground-truth decision from STATE.md.
     - Relationship to phase 06-03: the beta lane is the user-chosen tooling fulfilling 06-03 Task 3's archive -> export -> scan -> upload pipeline; when 06-03 executes, `bundle exec fastlane ios beta` supersedes the planned raw scripts/release-archive.sh + ExportOptions.plist + altool combination, and 06-03's teamID must-have carries the stale upstream ID — the fastlane setup is the corrected ground truth.
     - Secrets hygiene: no key material, key IDs, or issuer IDs in the repo; Gemfile.lock pins the fastlane version.

  3. Run `bundle exec fastlane ios tests` for real once and record the pass/fail summary line in the SUMMARY (this proves the destination string and bundler-pinned fastlane drive the existing suite; expect a few minutes of wall time).
  </action>
  <verify>
    <automated>bundle exec fastlane ios tests && grep -q 'ASC_KEY_ID' docs/submission/fastlane-pipeline.md && grep -q 'ASC_ISSUER_ID' docs/submission/fastlane-pipeline.md && grep -q 'Integrations' docs/submission/fastlane-pipeline.md && grep -q 'scan-private-apis' docs/submission/fastlane-pipeline.md && grep -q '06-03' docs/submission/fastlane-pipeline.md</automated>
  </verify>
  <done>`bundle exec fastlane ios tests` runs the existing suite green via the pinned fastlane; docs/submission/fastlane-pipeline.md documents key creation, env-var wiring, both lanes, the scan-gate ordering, and the 06-03 relationship.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| ASC credential material -> repo/git history | upload credential on a public fork; any commit is a permanent leak |
| Release binaries -> TestFlight upload | private-API regression shipped past the scan gate is a 2.5.1 rejection |
| rubygems.org -> vendor/bundle | fastlane plus transitive gems installed at bundle install time |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-Q-01 | Information Disclosure | ASC key ID / issuer ID / .p8 in tracked files | critical | mitigate | Fastfile reads only ENV ASC_KEY_ID/ASC_ISSUER_ID and derives the .p8 path under ~/.private_keys; Task 1 verify negative-greps the AuthKey filename pattern across Gemfile and fastlane/; guard message instructs placement outside the repo |
| T-Q-02 | Tampering | upload path bypassing the private-API scan | high | mitigate | scan-private-apis.sh runs on both archive binaries inside the beta lane between export and upload_to_testflight; fastlane sh raises on non-zero exit, aborting the lane before upload |
| T-Q-03 | Spoofing | archive signed under the stale upstream team identity | medium | mitigate | Appfile team_id and export_options teamID both K2TYLYAWMK; Task 1 verify negative-greps the stale ID across Gemfile and fastlane/ |
| T-Q-SC | Tampering | rubygems installs (fastlane + transitive) | low | accept | fastlane is the user-directed, canonical tool already installed globally on this machine; Gemfile.lock pins the resolved dependency set; no other new packages |
</threat_model>

<verification>
- Task 1: lanes parse via bundler; guard branch proven by real run with env vars unset (non-zero exit + ASC_KEY_ID in output); negative greps for stale team ID and hardcoded key filenames pass; gitignore covers vendor/ and .bundle/
- Task 2: tests lane runs the existing suite green; doc greps confirm env vars, key click path, scan gate, and 06-03 cross-reference
- Full beta pipeline (archive -> scan -> upload) remains unexecutable by design until the user creates the ASC key; the guard's actionable failure IS the verified behavior for that state
</verification>

<success_criteria>
- `bundle install && bundle exec fastlane lanes` works from a fresh clone and lists tests + beta
- beta lane fails fast and self-explanatorily without the ASC key; once the key exists, one command performs cloud-signed archive, dual-binary scan gate, and TestFlight upload in a fixed order
- Zero credential shapes and zero stale team ID in tracked files; team K2TYLYAWMK everywhere
- Pipeline documented under docs/submission/ including how it supersedes 06-03 Task 3's raw-script pipeline
</success_criteria>

<output>
Create `.planning/quick/260819-tkz-set-up-fastlane-for-testflight-pipeline-/260819-tkz-SUMMARY.md` when done
</output>
