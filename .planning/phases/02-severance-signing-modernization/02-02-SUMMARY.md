---
phase: 02-severance-signing-modernization
plan: 02
subsystem: infra
tags: [ci, private-api-scan, tdd, shell, github-actions]

# Dependency graph
requires:
  - phase: 02-severance-signing-modernization
    plan: 01
    provides: standard-signing baseline, shared CarTube.xcscheme (required for xcodebuild -scheme CarTube invocations)
provides:
  - scripts/scan-private-apis.sh — permanent removed-symbols-only marker scanner, reusable by every later phase's CI
  - scripts/tests/test-scan-private-apis.sh — hermetic six-case RED/GREEN suite
  - .github/workflows/scan.yml — Private API Scan CI workflow (push + PR, both binaries, no continue-on-error)
affects: [02-03-nosleep-idle-timer, 02-04-deployment-target-raise]

# Actuals (#2632)
actuals:
  tokens: 1900
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "Hermetic shell TDD via an env-var input override (SCAN_INPUT_FILE) so binary-scanning logic is unit-testable without a build"
    - "Removed-symbols-only marker list (not all-private-APIs) so surviving features can never fail their own regression gate"

key-files:
  created:
    - scripts/scan-private-apis.sh
    - scripts/tests/test-scan-private-apis.sh
    - .github/workflows/scan.yml
  modified:
    - .planning/WINDOWS.md
    - .planning/REQUIREMENTS.md
    - .planning/STATE.md

key-decisions:
  - "Marker array holds exactly the 15 removed-symbol strings named in the plan; the 4 survivor strings (_simulateTextEntered, _hasSleepDisabler, com.apple.springboard.hasBlankedScreen, com.apple.springboard.lockstate) are deliberately absent from the array and documented only in the script's header comment"
  - "CI workflow scans build/DerivedData/Build/Products/Debug-iphonesimulator/ paths for both CarTube.app/CarTube and PlugIns/PlayOnCarTube.appex/PlayOnCarTube, with no continue-on-error anywhere — the scan script's own exit code fails the job"

requirements-completed: [INFRA-05]

coverage:
  - id: D1
    description: "scripts/scan-private-apis.sh exits non-zero and names every matched marker when scanning input containing any of the 15 removed-symbol markers; exits zero on a clean binary; the 4 survivor strings never trip the gate"
    requirement: INFRA-05
    verification:
      - kind: unit
        ref: "bash scripts/tests/test-scan-private-apis.sh — 6/6 PASS, exit 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "The gate demonstrably catches real (not fixture) private-API markers, and passes a real clean binary"
    requirement: INFRA-05
    verification:
      - kind: unit
        ref: "Real linked PlayOnCarTube.appex Mach-O (target-mode build, bypassing the broken scheme-mode simulator destination resolution) scanned with scripts/scan-private-apis.sh: exit 0, clean"
        status: pass
      - kind: other
        ref: "scripts/scan-private-apis.sh run directly against the real pre-severance CarTube/Util/Utilities.swift source (SCAN_INPUT_FILE hook) detects MRMediaRemote, kMRMediaRemoteNowPlayingInfo, _MRNowPlayingClientProtobuf, BKSDisplayBrightness, SBGetScreenLockStatus, SBSSpringBoardServerPort, SBBacklightLevel, PrivateFrameworks/, platform-application, com.apple.private.security.no-container, com.apple.backboard.displaybrightness — 11 of the 15 markers present in real source text"
        status: pass
      - kind: other
        ref: "xcodebuild -project CarTube.xcodeproj -target CarTube -sdk iphonesimulator build (target-mode, bypassing -scheme destination resolution) against the real CarTube.app/CarTube binary"
        status: unknown
    human_judgment: true
    rationale: "Same environment limitation plan 02-01 hit and logged: this sandbox's Xcode 26.3 ships iphonesimulator SDK 26.2 (23C57) but only iOS 26.5 (23F77) simulator runtimes are installed. Scheme-mode xcodebuild enumerates zero destinations regardless of -destination flags (confirmed again this plan — -showBuildSettings with a destination returns empty BUILT_PRODUCTS_DIR). Target-mode build (bypassing scheme resolution) gets further than 02-01 documented: it links and produces a real PlayOnCarTube.appex binary (used for D2's first verification above), but CompileAssetCatalogVariant fails before the CarTube app target's own Swift compile/link ever starts, so no real CarTube.app/CarTube binary exists to scan in this sandbox. Logged to .planning/WINDOWS.md entry 4. A machine or CI runner with a simulator runtime matching the installed Xcode's bundled SDK will complete this specific check — the CI workflow itself (.github/workflows/scan.yml) will run it on every push once merged."
---

# Phase 2 Plan 2: Private API CI Scan Gate Summary

**Built and TDD-verified the permanent private-API regression scanner (INFRA-05) with a removed-symbols-only 15-marker list, wired it into a GitHub Actions workflow scanning both app binaries on every push, and proved detection against the real pre-severance codebase — with the final compiled-app-binary proof blocked by the same local Xcode/Simulator SDK-runtime mismatch plan 02-01 already logged, not by any defect in this plan's script or workflow.**

## Performance

- **Duration:** ~14 min
- **Started:** 2026-08-18T09:41:13Z
- **Completed:** 2026-08-18T09:54:50Z
- **Tasks:** 2
- **Files created:** 3 (scripts/scan-private-apis.sh, scripts/tests/test-scan-private-apis.sh, .github/workflows/scan.yml)
- **Files modified:** 1 (.planning/WINDOWS.md, defect ledger entry)

## Accomplishments

- `scripts/scan-private-apis.sh`: a 15-entry named-array scanner covering exactly the symbols Phase 2 removes (MediaRemote, BackBoardServices brightness, SpringBoard lock/port, TrollStore entitlement keys), with a `SCAN_INPUT_FILE` hermetic test hook, prints-every-hit-then-exit-1 semantics, and a header comment documenting why the 4 survivor strings are deliberately excluded
- `scripts/tests/test-scan-private-apis.sh`: six-case suite proven RED (script temporarily removed → all 6 fail with a clear "no such file" error) then GREEN (script restored → 6/6 PASS) — genuine TDD, not simulated
- `.github/workflows/scan.yml`: single-job "Private API Scan" workflow on `push`/`pull_request`, macOS runner, provisions `Secrets.xcconfig` from the Phase 1 example template, builds both targets with a `YOUTUBE_API_KEY=CI_PLACEHOLDER` override, scans `CarTube.app/CarTube` and `CarTube.app/PlugIns/PlayOnCarTube.appex/PlayOnCarTube`, contains no `continue-on-error` anywhere
- Real (non-fixture) proof-of-detection: a genuinely linked `PlayOnCarTube.appex` Mach-O binary (built via a target-mode `xcodebuild` invocation that works around this sandbox's broken scheme-mode destination resolution) scans clean (exit 0); the real pre-severance `CarTube/Util/Utilities.swift` source, scanned directly through the same script, is detected as violating 11 of the 15 markers
- INFRA-05 marked complete in REQUIREMENTS.md (checkbox + traceability table)

## Task Commits

Each task was committed atomically:

1. **Task 1: RED/GREEN scan script — marker match, clean pass, survivor exclusion** - `6150f3b` (test)
2. **Task 2: Prove the gate on real binaries + wire the CI workflow** - `045cbc5` (feat)

**Plan metadata:** commit pending (this SUMMARY + STATE.md)

## Files Created/Modified

- `scripts/scan-private-apis.sh` — new, executable, 15-marker array + SCAN_INPUT_FILE hook
- `scripts/tests/test-scan-private-apis.sh` — new, executable, six-case hermetic suite
- `.github/workflows/scan.yml` — new, Private API Scan workflow
- `.planning/WINDOWS.md` — new entry (id 4) logging the app-binary build blocker as unrun-verify
- `.planning/REQUIREMENTS.md` — INFRA-05 marked complete
- `.planning/STATE.md` — position/decisions updated for this plan (below)

## Decisions Made

- Marker array holds exactly the 15 strings the plan specified (removed symbols only); the 4 survivor strings are excluded from the array by design and documented only in the header comment, so surviving features (screen-off warning label, on-CarPlay keyboard) can never fail their own regression gate
- CI workflow has zero `continue-on-error` steps anywhere — the scanner's exit code is what fails the job, matching the plan's threat-model mitigation for T-02-05 (workflow bypass)
- Kept the CI recipe identical to Phase 1's Secrets.xcconfig pattern: copy the committed example, override `YOUTUBE_API_KEY` on the command line so no real key ever touches CI disk

## Deviations from Plan

### Auto-fixed Issues

None — no bugs, missing functionality, or blocking issues were found in the plan's own scope. The one deviation below is a re-confirmation of a pre-existing, already-logged environment limitation, not new plan-execution work.

---

**Total deviations:** 0
**Impact on plan:** None — both tasks completed per plan, verification requirements met to the extent this sandbox's tooling allows.

## Issues Encountered

**Known Environment Limitation — confirmed again, not a new defect (see plan 02-01 SUMMARY for the original report):**

This sandbox's Xcode 26.3 bundles `iphonesimulator` SDK 26.2 (build `23C57`); only the iOS 26.5 (build `23F77`) simulator runtime is installed. Two independent, reproduced-again symptoms:

1. `xcodebuild -project CarTube.xcodeproj -scheme CarTube -destination 'platform=iOS Simulator,name=iPhone Air' -showBuildSettings` returns an empty `BUILT_PRODUCTS_DIR` — scheme-mode destination resolution finds nothing, exactly as 02-01 documented, even with the shared `CarTube.xcscheme` that plan 02-01 added.
2. Target-mode build (`xcodebuild -target CarTube -sdk iphonesimulator ... build`, bypassing scheme/destination resolution entirely) gets further than plain scheme-mode: it resolves the `Dynamic` SPM package, links the `PlayOnCarTube` share-extension binary successfully (both x86_64 and arm64, real Mach-O, verified with `file`), but fails on `CompileAssetCatalogVariant thinned` with `No simulator runtime version from ["23F77"] available to use with iphonesimulator SDK version 23C57` — and this failure blocks the whole `CarTube` app target before its own Swift sources are ever compiled or linked (confirmed by inspecting `ObjRoot/CarTube.build/.../Objects-normal`, which contains only build metadata files, no `.o` objects, for the `CarTube` target specifically — while the `PlayOnCarTube` target's objects and final linked binary are present).

**What WAS verified as strong, real (non-fixture) evidence the scanner works correctly:**
- `bash scripts/tests/test-scan-private-apis.sh` — 6/6 PASS on the hermetic fixture suite (both RED-phase failure with the script absent, and GREEN-phase all-pass with it restored, were actually run, not just asserted)
- The real, target-mode-linked `PlayOnCarTube.appex/PlayOnCarTube` Mach-O binary scans clean: `scripts/scan-private-apis.sh` on that binary exits 0
- `SCAN_INPUT_FILE=CarTube/Util/Utilities.swift scripts/scan-private-apis.sh CarTube/Util/Utilities.swift` (feeding the scanner the real pre-severance source text, not a synthetic fixture) detects 11 of the 15 markers: `MRMediaRemote`, `kMRMediaRemoteNowPlayingInfo`, `_MRNowPlayingClientProtobuf`, `BKSDisplayBrightness`, `SBGetScreenLockStatus`, `SBSSpringBoardServerPort`, `SBBacklightLevel`, `PrivateFrameworks/`, `platform-application`, `com.apple.private.security.no-container`, `com.apple.backboard.displaybrightness` — confirming the same 11 dlopen-path/dlsym-name/doc-comment strings independently identified in `01-01-PLAN.md`/`PITFALLS.md`'s researched caller map are exactly what this scanner catches
- YAML validated with `python3 -c "import yaml; yaml.safe_load(...)"` — valid
- `.github/workflows/scan.yml` contains both binary paths, the `YOUTUBE_API_KEY` override, and zero `continue-on-error`

**What was NOT verified:** a literal `strings` scan of the fully-linked `CarTube.app/CarTube` binary itself (the app target's own compiled Mach-O). This requires a machine or CI runner with an iOS simulator runtime matching the installed Xcode's bundled SDK version — exactly the condition plan 02-01 also could not meet locally. Recorded as a `human_judgment: true` coverage item (D2) above and logged to `.planning/WINDOWS.md` (entry 4, `unrun-verify`). The CI workflow committed in this plan will run this exact check on every future push/PR once a runner with a matching runtime executes it (GitHub's `macos-latest` runners are expected to have matching SDK/runtime pairs, unlike this local sandbox).

## Next Phase Readiness

- `scripts/scan-private-apis.sh` and its marker vocabulary are now the permanent gate referenced by every later phase's CI, per the plan's stated purpose
- Expected CI behavior for pushes made between this plan and plan 02-03/02-04's completion: the workflow **fails**, because the markers are still present in the app binary (confirmed at the source level in this plan) — that is the gate working as designed, not a regression. The phase-close green run happens after plans 02-03 (Swift-layer severance) and 02-04 (deployment-target raise) land.
- Plan 02-03 is unblocked to proceed with the actual Swift-layer removal now that the detection gate exists and is proven against the pre-severance source

---
*Phase: 02-severance-signing-modernization*
*Completed: 2026-08-18*

## Self-Check: PASSED

`scripts/scan-private-apis.sh`, `scripts/tests/test-scan-private-apis.sh`, and `.github/workflows/scan.yml` confirmed present on disk and executable where applicable; both task commits (`6150f3b`, `045cbc5`) confirmed present in `git log`; `.planning/WINDOWS.md` entry 4 confirmed present.
