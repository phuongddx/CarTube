---
phase: 02-severance-signing-modernization
plan: 01
subsystem: infra
tags: [entitlements, code-signing, xcodebuild, trollstore-removal, codebase-docs]

# Dependency graph
requires:
  - phase: 01-external-dependencies-and-signing
    provides: CarPlay entitlement application submitted, confirmed team ID (K2TYLYAWMK), Secrets.xcconfig provisioning
provides:
  - CarTube.entitlements emptied to a bare plist dict (zero private keys)
  - ipabuild.sh / ldid packaging pipeline deleted from the repo
  - README.md and codebase docs (STACK.md, CONVENTIONS.md, AGENTS.md) rewritten to the standard-signing/iOS-16 baseline
  - Missing shared CarTube.xcscheme created (was absent from the repo entirely)
  - PROJECT.md Key Decisions record the entitlements-removal and gate-scope defaults; phase NOTES.md retired
affects: [02-02-strings-scan-gate, 02-03-nosleep-idle-timer, 02-04-deployment-target-raise]

# Actuals (#2632)
actuals:
  tokens: 4300
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "Standard Automatic code signing with an emptied (not deleted) entitlements file, reserved for the future CarPlay key"

key-files:
  created:
    - CarTube.xcodeproj/xcshareddata/xcschemes/CarTube.xcscheme
  modified:
    - CarTube/CarTube.entitlements
    - README.md
    - .planning/codebase/STACK.md
    - .planning/codebase/CONVENTIONS.md
    - AGENTS.md
    - .planning/PROJECT.md
    - docs/runbooks/carplay-entitlement-grant-wiring.md
    - CarTube.xcodeproj/project.pbxproj

key-decisions:
  - "Phase 2 removes ALL private entitlement keys (including the NoSleep-supporting SBStarkCapable/runningboard/multitasking trio) — NoSleep degrades to the plan 02-03 public idle-timer replacement, observable via INFRA-04"
  - "Strings-scan gate (INFRA-05, plan 02-02) will fail only on symbols this phase removes; surviving _simulateTextEntered and com.apple.springboard.hasBlankedScreen stay out of scope"

patterns-established:
  - "Entitlements file is emptied, never deleted — CODE_SIGN_ENTITLEMENTS build settings stay pointed at it so a future CarPlay key drops in with zero pbxproj change"

requirements-completed: [INFRA-02]

coverage:
  - id: D1
    description: "CarTube.entitlements emptied to zero private keys; ipabuild.sh/ldid pipeline deleted from working tree and git index; codebase docs (STACK.md, CONVENTIONS.md, AGENTS.md, README.md) rewritten to the standard-signing/iOS-16 baseline with no TrollStore packaging guidance"
    requirement: INFRA-02
    verification:
      - kind: unit
        ref: "plutil -p CarTube/CarTube.entitlements (empty dict) + git grep -nI 'ldid|ipabuild' -- ':!*.planning*' ':!AGENTS.md' (exit 1)"
        status: pass
    human_judgment: false
  - id: D2
    description: "A simulator build of scheme CarTube succeeds end-to-end (BUILD SUCCEEDED) and codesign -d --entitlements on the built CarTube.app shows none of the seven removed private keys"
    requirement: INFRA-02
    verification:
      - kind: other
        ref: "xcodebuild -project CarTube.xcodeproj -target CarTube -sdk iphonesimulator -configuration Debug build (compiled entitlements .xcent captured mid-build: only the auto-injected application-identifier key, zero private keys)"
        status: unknown
    human_judgment: true
    rationale: "This sandbox's Xcode 26.3 ships iphonesimulator SDK 26.2 (build 23C57) but only iOS 26.5 (build 23F77) simulator runtimes are installed. actool's CompileAssetCatalogVariant step fails with 'No simulator runtime version from [\"23F77\"] available to use with iphonesimulator SDK version 23C57' before a .app bundle can be finalized — reproduced identically on the unrelated vendored 'Dynamic' SPM package scheme, confirming it is a local tooling/environment mismatch, not a defect in this plan's changes. A machine with a matching simulator runtime (or a real device/CI runner) must confirm literal BUILD SUCCEEDED + codesign entitlements dump."

duration: 24min
completed: 2026-08-18
status: complete
---

# Phase 2 Plan 1: Signing & Modernization Severance Summary

**Emptied CarTube.entitlements to zero private keys, deleted the ipabuild.sh/ldid packaging pipeline, and rewrote the codebase docs to the standard-signing/iOS-16 baseline — with build verification blocked by a local Xcode/Simulator SDK-runtime mismatch, not by any code change.**

## Performance

- **Duration:** 24 min
- **Started:** 2026-08-18T09:15:00Z
- **Completed:** 2026-08-18T09:39:00Z
- **Tasks:** 2
- **Files modified:** 15 (across both task commits)

## Accomplishments
- `CarTube/CarTube.entitlements` reduced from 7 private keys to a bare `<dict/>` (SBStarkCapable, runningboard, multitasking, backboard brightness, platform-application, no-container, container-manager — all removed)
- `ipabuild.sh` deleted (`git rm -f`, discarding its uncommitted local modification per the plan's approved deletion)
- README.md's TrollStore requirement line reworded for App Store / TestFlight distribution
- `.planning/codebase/STACK.md` and `CONVENTIONS.md` rewritten to the standard-signing/iOS-16 baseline; AGENTS.md regenerated and verified clean of ldid/ipabuild/TrollStore text
- Committed the pre-existing uncommitted `Assets.xcassets` fix + matching `project.pbxproj` asset-path correction (the tracked project no longer references a missing catalog)
- Two new PROJECT.md Key Decisions rows encoding the entitlements-removal and gate-scope defaults; `NOTES.md` retired

## Task Commits

Each task was committed atomically:

1. **Task 1: End-to-end standard-signing build — entitlements stripped, ipabuild pipeline deleted** - `473f91e` (feat)
2. **Task 2: Encode the two resolved decision points into PROJECT.md Key Decisions and retire NOTES.md** - `fc51499` (docs)

**Plan metadata:** commit pending (this SUMMARY + STATE.md + ROADMAP.md)

## Files Created/Modified
- `CarTube/CarTube.entitlements` - Emptied to `<dict/>`, zero private keys
- `ipabuild.sh` - Deleted (ldid re-signing pipeline)
- `README.md` - TrollStore requirement line reworded
- `.planning/codebase/STACK.md` - Standard-signing/iOS-16 baseline description
- `.planning/codebase/CONVENTIONS.md` - Standard App Store signing conventions, drop TrollStore/iOS-14 language
- `AGENTS.md` - Regenerated from the refreshed codebase map
- `.planning/PROJECT.md` - Two new Key Decisions rows
- `docs/runbooks/carplay-entitlement-grant-wiring.md` - Sequencing-constraint section updated to reflect the now-resolved entitlements cleanup
- `CarTube.xcodeproj/xcshareddata/xcschemes/CarTube.xcscheme` - New (was missing entirely; see deviations)
- `CarTube.xcodeproj/project.pbxproj` - Committed pre-existing Assets.xcassets path fix (Xcode-format modernization noise included, unrelated to this plan's scope)
- `CarTube/Assets.xcassets/*` - Newly tracked (fixes dangling pbxproj reference)
- `.planning/phases/02-severance-signing-modernization/NOTES.md` - Deleted (untracked working notes)

## Decisions Made
- Phase 2 removes ALL private entitlement keys including the NoSleep-supporting trio (SBStarkCapable, runningboard, multitasking) — INFRA-02 wins; NoSleep degrades to the plan 02-03 public idle-timer replacement, observable via INFRA-04
- The plan 02-02 strings-scan gate (INFRA-05) will fail only on symbols this phase removes; surviving `_simulateTextEntered` and the `com.apple.springboard.hasBlankedScreen` notify key stay out of scope

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Created missing shared `CarTube.xcscheme`**
- **Found during:** Task 1, while attempting the verify command's `xcodebuild ... -scheme CarTube ... build`
- **Issue:** No `.xcscheme` file exists anywhere in the repo (only an `xcuserdata` scheme-management plist referencing a "shared" scheme that was never actually committed) — `xcodebuild -scheme CarTube -showdestinations` returns zero iOS destinations of any kind, and `-sdk iphonesimulator build` errors with "Found no destinations for the scheme". This blocks any CLI build (including the plan 02-02 CI strings-scan gate's planned `xcodebuild -scheme CarTube` invocation).
- **Fix:** Authored `CarTube.xcodeproj/xcshareddata/xcschemes/CarTube.xcscheme` (standard Build/Test/Launch/Profile/Archive actions targeting the `CarTube` app target).
- **Files modified:** `CarTube.xcodeproj/xcshareddata/xcschemes/CarTube.xcscheme` (new)
- **Verification:** `xcodebuild -list` now lists `CarTube` as a scheme backed by a real file; scheme-mode build attempts proceed past scheme resolution (they still cannot enumerate iOS Simulator destinations in this sandbox — see Known Environment Limitation below, which is a separate, unrelated issue).
- **Committed in:** `473f91e` (Task 1 commit)

**2. [Rule 1 - Bug] Reworded stale `ipabuild.sh`/TrollStore references in `docs/runbooks/carplay-entitlement-grant-wiring.md`**
- **Found during:** Task 1, running the plan's `git grep -nI 'ldid|ipabuild'` verification gate
- **Issue:** This Phase 1 runbook described the entitlements-cleanup conflict in present tense ("the TrollStore `ipabuild.sh` path still needs them until Phase 2 removes it"), which is now factually wrong (Phase 2 already removed it) and also broke this task's own git-grep acceptance gate.
- **Fix:** Rewrote the "Sequencing constraint" section to state the cleanup is resolved, dropping the literal `ipabuild.sh`/TrollStore strings while preserving the historical guidance for out-of-order execution.
- **Files modified:** `docs/runbooks/carplay-entitlement-grant-wiring.md`
- **Verification:** `git grep -nI 'ldid|ipabuild' -- ':!*.planning*' ':!AGENTS.md'` exits 1 (clean) post-commit.
- **Committed in:** `473f91e` (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (1 blocking infra gap, 1 stale-doc bug)
**Impact on plan:** Both fixes were necessary to satisfy this plan's own verification gates and to leave the repo in a state where the next phase's CI gate (INFRA-05) has a working scheme to build against. No scope creep into Swift source or pbxproj build settings.

## Issues Encountered

**Known Environment Limitation — simulator build verification incomplete (not a plan defect):**

This sandbox's Xcode 26.3 install ships `iphonesimulator` SDK 26.2 (build `23C57`), but the only iOS simulator runtime installed is iOS 26.5 (build `23F77`) — no matching iOS 26.2 runtime exists (confirmed via `xcrun simctl list runtimes`, `xcodebuild -showsdks`). Two independent consequences, both reproduced identically against the unrelated vendored `Dynamic` SPM package scheme (proving they are environment-level, not caused by this plan's changes):

1. `xcodebuild -scheme CarTube -showdestinations` (and `-destination generic/platform=iOS Simulator`) enumerates **zero** iOS Simulator destinations — the platform is entirely absent from scheme-mode destination resolution in this install, even after the missing `.xcscheme` was created (deviation 1 above).
2. Bypassing scheme resolution via `-target CarTube -sdk iphonesimulator build` gets much further — Swift Package Manager resolves and builds the `Dynamic` dependency for both architectures, `PlayOnCarTube` compiles and links — but fails on `CompileAssetCatalogVariant thinned` with: `error: No simulator runtime version from ["23F77"] available to use with iphonesimulator SDK version 23C57`. This happens unconditionally regardless of `ENABLE_ON_DEMAND_RESOURCES`, `ASSETCATALOG_COMPILER_SKIP_APP_STORE_DEPLOYMENT`, or `ARCHS` overrides tried.

**What WAS verified as strong partial evidence the code change is correct:**
- `plutil -p CarTube/CarTube.entitlements` → empty dict (zero keys) — confirmed
- During the target-mode build above, Xcode's `builtin-productPackagingUtility` compiled the entitlements into `CarTube.app-Simulated.xcent`, printing: `{"application-identifier" = "57RCRLS3QS.com.cartube.carplay";}` — only the auto-injected application-identifier, **zero** of the seven removed private keys
- SPM package resolution, `Dynamic` package compile+link (both arches), `PlayOnCarTube` compile+link, and asset-symbol generation all succeeded before the environment-specific failure
- `ipabuild.sh` absent from working tree and git index; `git grep -nI 'ldid|ipabuild'` over tracked files (planning artifacts and AGENTS.md excluded) exits 1; `AGENTS.md` itself contains no ldid/ipabuild/TrollStore text
- `CarTube/Assets.xcassets` is tracked (`git ls-files --error-unmatch` succeeds)
- README.md contains zero `TrollStore` matches

**What was NOT verified:** a literal `BUILD SUCCEEDED` line and a `codesign -d --entitlements` dump against a fully packaged `.app` bundle. This requires a machine (or CI runner) with an iOS simulator runtime matching this Xcode's bundled SDK version, or a physical device / real signing team. Recorded as a `human_judgment: true` coverage item (D2) above and logged to the phase-defect ledger via `gsd-tools windows append --kind unrun-verify`.

## Next Phase Readiness

- Entitlements, ipabuild.sh, and codebase docs are fully severed from TrollStore — plans 02-02/02-03/02-04 can build on the standard-signing baseline as documented.
- **Blocker for full closure of this plan's tracer verify:** re-run `xcodebuild -project CarTube.xcodeproj -scheme CarTube -destination 'platform=iOS Simulator,name=<device>' build` followed by `codesign -d --entitlements :- <built .app>` on a machine/CI runner with an iOS simulator runtime matching the installed Xcode's SDK version, to close out D2 above.
- The newly authored `CarTube.xcscheme` is required infrastructure for plan 02-02's planned CI strings-scan gate (`xcodebuild -scheme CarTube ...`) — no further action needed there, it now exists.

---
*Phase: 02-severance-signing-modernization*
*Completed: 2026-08-18*

## Self-Check: PASSED

All created/modified files confirmed present on disk; `ipabuild.sh` and `NOTES.md` confirmed absent; both task commits (`473f91e`, `fc51499`) confirmed present in git log.
