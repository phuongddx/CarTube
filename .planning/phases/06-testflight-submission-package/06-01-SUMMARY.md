---
phase: 06-testflight-submission-package
plan: 01
subsystem: security
tags: [codable, jsondecoder, pastebutton, github-releases, private-api-scan]

requires:
  - phase: 03-search-core
    provides: CarTubeTests target, MockURLProtocol, Fixtures resource-loading convention, Codable house style
  - phase: 02-severance-signing-modernization
    provides: scripts/scan-private-apis.sh gate, iOS 16 deployment floor (PasteButton availability)
provides:
  - Hardened checkNewVersions — typed GitHubRelease Codable decode, HTTPURLResponse 200 gate, fork-targeted URLs, fixed-copy alert with zero remote-text interpolation
  - Explicit PasteButton paste interaction replacing the activation-time pasteboard read (zero UIPasteboard code repo-wide)
  - GITHUB_RELEASES_API_URL / GITHUB_RELEASES_PAGE_URL constants (phuongddx/CarTube fork)
  - Five fixture-driven GitHubRelease unit tests via MockURLProtocol
affects: [06-02 submission docs, 06-03 archive-upload, app review notes]

actuals:
  tokens: 3000
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "Update-check gating isolated in static GitHubRelease.validated(data:response:) — pure, testable without touching URLSession.shared"
    - "PasteButton (first use in repo): system paste affordance, payloadType String.self, validation via existing isYouTubeURL"

key-files:
  created:
    - CarTubeTests/GitHubReleaseTests.swift
    - CarTubeTests/Fixtures/github-release.json
  modified:
    - CarTube/CarTubeApp.swift
    - CarTube/Views/ContentView.swift
    - CarTube/Util/Constants.swift
    - CarTube.xcodeproj/project.pbxproj

key-decisions:
  - "Harden, not remove: update check kept and validated (ROADMAP criterion 3); removal was the rejected alternative"
  - "Fork, not upstream: both GitHub URLs retargeted at phuongddx/CarTube — upstream Avangelista releases never match App Store builds"
  - "Remote body dropped: GitHubRelease.body exists for schema completeness but no user-facing string interpolates it; alert copy is fixed local text plus tagName only"
  - "PasteButton (option a) over explicit Button (option b): no pasteboard code in app logic, no paste-permission banner, iOS 16 floor makes it available"

patterns-established:
  - "Static validated(data:response:) gating function: status-check + typed decode as a pure seam, unit-testable via MockURLProtocol without dependency-injecting the session"

requirements-completed: [SHIP-03]

coverage:
  - id: D1
    description: "GitHub update check decodes typed GitHubRelease only after HTTPURLResponse 200 gate; schema drift (missing tag_name) fails to nil without crash"
    requirement: SHIP-03
    verification:
      - kind: unit
        ref: "CarTubeTests/GitHubReleaseTests.swift#testValidReleaseFixtureDecodesTagName"
        status: pass
      - kind: unit
        ref: "CarTubeTests/GitHubReleaseTests.swift#testNon200StatusNeverProducesReleaseEvenWithValidBody"
        status: pass
      - kind: unit
        ref: "CarTubeTests/GitHubReleaseTests.swift#testMissingTagNameFailsDecodeToNil"
        status: pass
      - kind: unit
        ref: "CarTubeTests/GitHubReleaseTests.swift#testNewerTagIsDetectedAgainstInstalledVersion"
        status: pass
    human_judgment: false
  - id: D2
    description: "Update alert renders fixed local copy only — decoded remote body never reaches any user-facing string"
    requirement: SHIP-03
    verification:
      - kind: unit
        ref: "CarTubeTests/GitHubReleaseTests.swift#testAlertCopyNeverInterpolatesRemoteBody"
        status: pass
      - kind: other
        ref: "grep -rq --include='*.swift' JSONSerialization CarTube/ (zero hits)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Pasteboard is read only via user-tapped PasteButton (isYouTubeURL-gated); activation-time read deleted repo-wide"
    requirement: SHIP-03
    verification:
      - kind: other
        ref: "BUILD SUCCEEDED + grep gates: PasteButton present, zero UIPasteboard repo-wide, zero scenePhase in ContentView"
        status: pass
    human_judgment: false
  - id: D4
    description: "Hardened code is scan-clean on both binaries and full suite green (tracer proof for 06-02/06-03)"
    requirement: SHIP-03
    verification:
      - kind: integration
        ref: "scripts/scan-private-apis.sh on CarTube.app/CarTube (exit 0) and PlayOnCarTube.appex/PlayOnCarTube (exit 0); xcodebuild test 96/96 TEST SUCCEEDED"
        status: pass
    human_judgment: false

duration: 12min
completed: 2026-08-19
status: complete
---

# Phase 06 Plan 01: Update-Check Hardening + Explicit Paste Summary

**Typed, status-gated GitHubRelease decode targeting the phuongddx fork with fixed-copy alert, plus PasteButton replacing the activation pasteboard read — 96/96 tests green, both binaries scan-clean**

## Performance

- **Duration:** ~12 min (16:11–16:23 local)
- **Started:** 2026-08-19T09:11:00Z
- **Completed:** 2026-08-19T09:22:21Z
- **Tasks:** 3
- **Files modified:** 6

## Accomplishments

- `checkNewVersions` hardened: `GitHubRelease` Codable struct (tag_name CodingKey), `validated(data:response:)` gate requiring HTTPURLResponse 200 before JSONDecoder decode, `.numeric` version compare via `isNewer(than:)`, and a fixed-copy alert that interpolates only the tag name — the last `JSONSerialization` dictionary-cast in the app is gone (repo-wide grep: zero hits)
- Both GitHub URLs live in `Constants.swift` as `GITHUB_RELEASES_API_URL` / `GITHUB_RELEASES_PAGE_URL`, pointed at the fork `phuongddx/CarTube`; no GitHub URL literal remains in `CarTubeApp.swift`
- Activation-time `UIPasteboard` read and its `scenePhase` environment deleted; `PasteButton(payloadType: String.self)` added to the URL-input Section with `isYouTubeURL` gating; `playVideo()` / `urlString` / invalid-link alert untouched downstream
- Five fixture-driven unit tests (decode, 404 gate, version predicate, schema drift, alert-copy isolation) via the Phase 3 MockURLProtocol + Fixtures convention; suite went 91 → 96, all passing
- Tracer proof-of-clean: `scan-private-apis.sh` exit 0 on the app binary and exit 0 on the share-extension binary; final full suite run TEST SUCCEEDED

## Task Commits

1. **Task 1 (RED): failing GitHubRelease tests + fixture + pbxproj wiring** - `9895022` (test)
2. **Task 1 (GREEN): hardened update check + fork constants** - `0c7829f` (feat)
3. **Task 2: PasteButton replacing activation pasteboard read** - `bb3e7a3` (feat)
4. **Task 3: scan gate + full suite** - no file changes (verification-only); results recorded below

## Files Created/Modified

- `CarTube/CarTubeApp.swift` - GitHubRelease struct + validated/isNewer/updateAlertBody; checkNewVersions reads constants, gates on 200, shows fixed copy
- `CarTube/Util/Constants.swift` - GITHUB_RELEASES_API_URL, GITHUB_RELEASES_PAGE_URL (fork)
- `CarTube/Views/ContentView.swift` - PasteButton row; scenePhase + onChange activation read deleted
- `CarTubeTests/GitHubReleaseTests.swift` - five behavior tests
- `CarTubeTests/Fixtures/github-release.json` - minimal releases/latest fixture (tag_name v9.9.9)
- `CarTube.xcodeproj/project.pbxproj` - test file in Sources, fixture in Resources of CarTubeTests

## Decisions Made

- Harden-not-remove, fork-not-upstream, remote-body-dropped — the three pattern-mapper decision points, all resolved to their recommended defaults (recorded in frontmatter key-decisions)
- PasteButton over explicit pasteboard-reading Button: leaves zero `UIPasteboard` code anywhere in the repo
- Gating logic exposed as static `GitHubRelease.validated(data:response:)` rather than dependency-injecting URLSession into `checkNewVersions` — keeps the dataTask/resume/confirmAlert shape unchanged per the plan while making every gate branch unit-testable

## Deviations from Plan

None - plan executed exactly as written.

Note on one acceptance-criterion wording: "grep Avangelista across CarTube/ Swift sources returns zero" — the plan's authoritative automated verify scopes this to `CarTube/CarTubeApp.swift` (passes: zero hits). `ContentView.swift` retains the author credit line and the upstream GitHub/ko-fi toolbar links, which are attribution UI, not update-check retargeting; changing them is outside this plan's task actions and the must_haves truth ("update-check URLs point at this fork").

## Issues Encountered

- The `xcodeproj` gem again dropped `dstSubfolder = PlugIns` from the Embed Foundation Extensions phase (recurring since Phase 2) — restored immediately after the gem run, before the RED commit. No spurious empty `dependencies` array this time.

## Scan Gate + Suite Proof (Task 3)

- `scripts/scan-private-apis.sh $BP/CarTube.app/CarTube` → exit 0
- `scripts/scan-private-apis.sh $BP/CarTube.app/PlugIns/PlayOnCarTube.appex/PlayOnCarTube` → exit 0
- `xcodebuild test` (iPhone Air simulator) → Executed 96 tests, 0 failures, TEST SUCCEEDED

## Self-Check: PASSED

- Both created files exist on disk
- `git log --grep="06-01"` returns 3 commits
- All task acceptance criteria re-verified (grep gates + TEST SUCCEEDED + scan exits)

## Next Phase Readiness

- SHIP-03 code half done; requirement stays open until sibling plan(s) declaring SHIP-03 finish (shared-ID gate: 0/1 ready at this plan's close)
- 06-02 (submission docs) can proceed on disjoint files; the tracer proves Constants → networking → UI → tests all build and test green under the scan gate

---
*Phase: 06-testflight-submission-package*
*Completed: 2026-08-19*
