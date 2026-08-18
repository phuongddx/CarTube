---
phase: 03-search-core
plan: 01
subsystem: testing
tags: [xctest, xcodeproj-gem, xcscheme, regex, nsregularexpression]

requires:
  - phase: 01-external-dependencies-project-setup
    provides: ruby-xcodeproj gem-mutation recipe (throwaway script, gem 1.28.1), Secrets.xcconfig build-time secret injection
  - phase: 02-severance
    provides: iOS 16.0 deployment target (6 pbxproj sites), standard code signing under team K2TYLYAWMK
provides:
  - CarTubeTests unit-test target (bundle.unit-test product type) wired into project.pbxproj
  - Shared CarTube.xcscheme TestAction running CarTubeTests — the first working `xcodebuild test` pipeline in the repo
  - Regression-locked extractYouTubeVideoID covering every URL class in TESTING.md's candidate list (13 tests)
affects: [03-search-core (plans 02, 03 build on this proven test pipeline), any future phase using xcodebuild test]

actuals:
  tokens: 3655
  tasks: 2
  commits: 3

tech-stack:
  added: []
  patterns:
    - "xcodebuild test -scheme CarTube ... is now the house verification command for the repo"
    - "Unit-test targets against an app binary that has Xcode's debug-dylib split (CarTube + CarTube.debug.dylib) require the TEST_HOST/BUNDLE_LOADER=$(TEST_HOST) pair, not BUNDLE_LOADER alone — bundle_loader-only linking cannot resolve symbols that live in the split debug dylib rather than the thin trampoline executable"
    - "Lazily-built static NSRegularExpression (try?, guard-optional) instead of try! inside the hot function — construct once per process"

key-files:
  created:
    - CarTubeTests/UtilitiesTests.swift
  modified:
    - CarTube.xcodeproj/project.pbxproj
    - CarTube.xcodeproj/xcshareddata/xcschemes/CarTube.xcscheme
    - CarTube/Util/Utilities.swift

key-decisions:
  - "BUNDLE_LOADER alone (no TEST_HOST) failed to link: this Xcode toolchain (26.3.1 simulator SDK) splits the app's Debug build into a thin `CarTube` trampoline executable plus a companion `CarTube.debug.dylib` holding the actual compiled symbols. Static bundle_loader linking against the trampoline cannot resolve `extractYouTubeVideoID`, which lives in the dylib. Switched to the plan's own sanctioned fallback: TEST_HOST = $(BUILT_PRODUCTS_DIR)/CarTube.app/CarTube plus BUNDLE_LOADER = $(TEST_HOST), which runs tests injected into the host app process at runtime and resolves correctly."
  - "The xcodeproj gem's new_target helper did not populate PRODUCT_NAME on the generated Debug/Release configs, producing a bare '.xctest' product path and a 'Multiple commands produce .xctest' link collision against the CarTube target. Added PRODUCT_NAME = \"$(TARGET_NAME)\" explicitly to both CarTubeTests configs."
  - "Repeated the Phase 2 precedent: the gem's project.save dropped dstSubfolder = PlugIns from the Embed Foundation Extensions phase and added a spurious empty dependencies = (); array to the PlayOnCarTube target. Both restored/removed by hand before committing, matching the 02-04 fix."
  - "The scheme file already existed (committed in Phase 2 plan 02-01) with an empty TestAction, contradicting 03-PATTERNS.md's mapping-time note that only user-local auto-schemes existed. Regenerated it via Xcodeproj::XCScheme#save_as, which preserved the existing BuildAction/LaunchAction/ProfileAction/ArchiveAction content and only changed the TestAction (added CarTubeTests) and the LastUpgradeVersion/version header attributes."

requirements-completed: [SRCH-04]

coverage:
  - id: D1
    description: "xcodebuild test runs a real XCTest target (CarTubeTests) against real app source through a committed shared scheme — the project's first passing test run"
    requirement: "SRCH-04"
    verification:
      - kind: integration
        ref: "xcodebuild -project CarTube.xcodeproj -scheme CarTube -destination 'id=DEEDE6B8-C5F2-4DB5-8819-E1AC3BA20E4A' test"
        status: pass
    human_judgment: false
  - id: D2
    description: "extractYouTubeVideoID passes a fixture-class matrix (watch, mobile-watch, youtu.be, embed, shorts, nocookie-embed, non-leading query param, hyphen/underscore ID, non-YouTube URL, plain text, empty string, 10-char and 12-char boundary) with the regex built once and no force-try"
    requirement: "SRCH-04"
    verification:
      - kind: unit
        ref: "CarTubeTests/UtilitiesTests.swift#testExtractVideoIDFromShortsURL"
        status: pass
      - kind: unit
        ref: "CarTubeTests/UtilitiesTests.swift#testExtractVideoIDReturnsNilForTwelveCharacterID"
        status: pass
      - kind: unit
        ref: "CarTubeTests/UtilitiesTests.swift (13 test methods total)"
        status: pass
    human_judgment: false

duration: 18min
completed: 2026-08-18
status: complete
---

# Phase 3 Plan 01: Test Pipeline Tracer + Hardened Parser Summary

**First working `xcodebuild test` pipeline in the repo — CarTubeTests unit-test target wired through a shared scheme, with extractYouTubeVideoID hardened (shorts support, once-built regex, no try!) and regression-locked by a 13-test URL-class matrix.**

## Performance

- **Duration:** 18 min
- **Started:** 2026-08-18T15:11:00Z
- **Completed:** 2026-08-18T15:28:45Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- CarTubeTests PBXNativeTarget (bundle.unit-test) created via the house ruby-xcodeproj recipe, depending on the CarTube target, with Debug+Release configs
- Shared CarTube.xcscheme's TestAction now runs CarTubeTests — `xcodebuild test -scheme CarTube` is a real, reproducible command
- extractYouTubeVideoID hardened: shorts path form added, right-boundary lookahead added (prevents 12+ char false-positive truncation), regex hoisted to a lazily-built static, try! replaced with try?
- 13-test URL-class matrix locks in every fixture class from TESTING.md's candidate list, RED-then-GREEN on shorts + the 12-char boundary case

## Task Commits

Each task was committed atomically:

1. **Task 1: End-to-end xcodebuild test tracer** - `cb57fef` (feat)
2. **Task 2: Parser test matrix (RED)** - `5bb5dbb` (test)
2. **Task 2: Parser test matrix (GREEN)** - `015ae58` (feat)

_TDD task (Task 2) produced separate test → feat commits per the RED/GREEN protocol; no refactor commit was needed._

## Files Created/Modified
- `CarTube.xcodeproj/project.pbxproj` - New CarTubeTests unit-test target, Debug+Release configs, dependency on CarTube, group/product entries
- `CarTube.xcodeproj/xcshareddata/xcschemes/CarTube.xcscheme` - TestAction now includes CarTubeTests
- `CarTubeTests/UtilitiesTests.swift` - New file; 13 test methods covering the full extractYouTubeVideoID input-class matrix
- `CarTube/Util/Utilities.swift` - extractYouTubeVideoID hardened (shorts, boundary lookahead, static regex, no try!)

## Decisions Made
- TEST_HOST + BUNDLE_LOADER=$(TEST_HOST) instead of BUNDLE_LOADER-only, because this Xcode toolchain's Debug-dylib split means the app's real symbols live in a companion `.debug.dylib`, not the thin trampoline executable BUNDLE_LOADER-only linking would target
- Added PRODUCT_NAME = "$(TARGET_NAME)" explicitly to the generated test target configs (the xcodeproj gem's `new_target` helper did not populate it, causing an empty-named product path collision)
- Restored `dstSubfolder = PlugIns` and removed a spurious empty `dependencies = ();` array the gem's save introduced on unrelated targets — same fix pattern documented in Phase 2 plan 02-04
- Regenerated the existing (previously empty-TestAction) shared scheme via `Xcodeproj::XCScheme#save_as` rather than creating a new file — it already existed as of Phase 2 plan 02-01

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] BUNDLE_LOADER-only linking failed; switched to TEST_HOST + BUNDLE_LOADER=$(TEST_HOST)**
- **Found during:** Task 1 (test target link step)
- **Issue:** `xcodebuild test` failed with "Undefined symbols... CarTube.extractYouTubeVideoID" — the toolchain splits Debug app builds into a thin `CarTube` executable plus `CarTube.debug.dylib`; BUNDLE_LOADER pointed at the thin executable, which exports no application symbols
- **Fix:** Set TEST_HOST = $(BUILT_PRODUCTS_DIR)/CarTube.app/CarTube and BUNDLE_LOADER = $(TEST_HOST) on both Debug and Release configs — this is the plan's own explicitly sanctioned fallback ("the sanctioned in-task correction is to add the standard pair TEST_HOST ... plus keeping BUNDLE_LOADER = $(TEST_HOST)")
- **Files modified:** CarTube.xcodeproj/project.pbxproj
- **Verification:** xcodebuild test reports TEST SUCCEEDED, Executed 1 test / 0 failures
- **Committed in:** cb57fef (Task 1 commit)

**2. [Rule 3 - Blocking] Missing PRODUCT_NAME caused a duplicate-output-file build error**
- **Found during:** Task 1 (first test build attempt)
- **Issue:** `xcodeproj` gem's `new_target` helper left PRODUCT_NAME unset on the generated CarTubeTests configs, producing a bare `.xctest` product path that collided with the CarTube target's own build output ("Multiple commands produce '.../.xctest'")
- **Fix:** Added `PRODUCT_NAME = "$(TARGET_NAME)";` to both Debug and Release configs
- **Files modified:** CarTube.xcodeproj/project.pbxproj
- **Verification:** Build proceeds past the link step; xcodebuild test succeeds
- **Committed in:** cb57fef (Task 1 commit)

**3. [Rule 1 - Bug] Doubled file path from group.new_file on an already-pathed group**
- **Found during:** Task 1 (first test build attempt)
- **Issue:** `cartube_tests_group.new_file('CarTubeTests/UtilitiesTests.swift')` on a group whose own path is already `CarTubeTests` produced a PBXFileReference path of `CarTubeTests/CarTubeTests/UtilitiesTests.swift`, which doesn't exist on disk
- **Fix:** Corrected the PBXFileReference path to `UtilitiesTests.swift` (relative to its already-CarTubeTests-pathed group)
- **Files modified:** CarTube.xcodeproj/project.pbxproj
- **Verification:** SwiftDriver compiles UtilitiesTests.swift successfully
- **Committed in:** cb57fef (Task 1 commit)

**4. [Rule 1 - Bug] Restored dstSubfolder=PlugIns; removed spurious empty dependencies array**
- **Found during:** Task 1 (pbxproj diff review before commit)
- **Issue:** The xcodeproj gem's project.save dropped `dstSubfolder = PlugIns;` from the Embed Foundation Extensions copy-files phase and added an empty `dependencies = ();` array to the unrelated PlayOnCarTube target — the same gem quirk already documented and fixed in Phase 2 plan 02-04
- **Fix:** Manually restored `dstSubfolder = PlugIns;` and removed the spurious empty `dependencies = ();` before committing
- **Files modified:** CarTube.xcodeproj/project.pbxproj
- **Verification:** git diff scoped to only the intended CarTubeTests-related additions plus these two known-quirk corrections
- **Committed in:** cb57fef (Task 1 commit)

---

**Total deviations:** 4 auto-fixed (all Rule 1/3 — blocking build/link issues and a known gem-save quirk)
**Impact on plan:** All four were necessary to reach a working `xcodebuild test` pipeline; none expanded scope beyond the tracer's stated goal. No search/service code was touched.

## Issues Encountered
None beyond the deviations documented above — all resolved within the fix-attempt budget on Task 1 before Task 2 began.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Plans 03-02 and 03-03 can add files directly to the now-proven CarTubeTests target/scheme pipeline without any further scaffold work
- `xcodebuild test -project CarTube.xcodeproj -scheme CarTube -destination '...'` is the house verification command going forward
- extractYouTubeVideoID is regression-locked; any future change to the URL-parsing regex must keep all 13 tests green
- No blockers for the next two plans in this phase

---
*Phase: 03-search-core*
*Completed: 2026-08-18*
