---
phase: 02-severance-signing-modernization
plan: 04
subsystem: infra
tags: [xcodeproj, deployment-target, spm, swiftui, autohook, debug-screen, private-api-scan]

# Dependency graph
requires:
  - phase: 02-severance-signing-modernization
    plan: 01
    provides: standard-signing baseline, entitlements emptied to zero private keys
  - phase: 02-severance-signing-modernization
    plan: 03
    provides: severance-complete Swift layer (INFRA-03), in-place settings application via CarPlaySingleton.applyConfiguration() (INFRA-06)
provides:
  - iOS 16.0 deployment floor across all six project configurations (project-level Debug/Release + CarTube target Debug/Release + PlayOnCarTube target Debug/Release)
  - Dynamic SPM package fully removed (all five object types: PBXBuildFile, packageProductDependencies, packageReferences, XCRemoteSwiftPackageReference, XCSwiftPackageProductDependency) and stale Package.resolved deleted
  - Real BUILD SUCCEEDED proof for scheme CarTube at the iOS 16 floor (both CarTube.app and PlayOnCarTube.appex) — closes 02-03's deferred D1/D2 verification items (previously blocked by a local SDK/simulator-runtime mismatch, now resolved)
  - scripts/scan-private-apis.sh passing against the actual compiled binaries (not just source-level grep) for both targets
  - Debug.swift extended with a Hook Verification section (4 runtime status rows) and a Script Re-validation section (3 force-injection rows)
affects: [02-04-checkpoint-human-verify, phase-3-search-and-voice]

# Actuals (#2632)
actuals:
  tokens: 9000
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "ObjC runtime install-detection from Swift: class_getInstanceMethod(UIWindow.self, NSSelectorFromString(\"original_setRootViewController:\")) != nil for hooks that leave an original_ stub; IMP-vs-superclass comparison via class_getMethodImplementation for hooks (HideScrollBar) that only declare hook_ with no original_ companion"
    - "Debug-screen rows stay singleton-only: every new row routes through CarPlaySingleton.shared, never retains CarPlayViewController, matching the existing Go Back/Go Home/Toggle Keyboard rows"
    - "Throwaway ruby xcodeproj-gem scripts for pbxproj mutation must be diffed post-save for unrelated churn — this gem version dropped an unrecognized dstSubfolder=PlugIns attribute and added a spurious empty dependencies array; both were restored by hand before commit"

key-files:
  created: []
  modified:
    - CarTube.xcodeproj/project.pbxproj
    - CarTube.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved (deleted)
    - CarTube/Views/Debug.swift

key-decisions:
  - "Restored dstSubfolder = PlugIns on the Embed Foundation Extensions PBXCopyFilesBuildPhase after the xcodeproj gem's save dropped it as an 'attribute it doesn't know about' (objectVersion 90 is very new; the gem's schema doesn't recognize this key). Left unrestored, the appex might not embed into the correct PlugIns subfolder — verified by diffing pbxproj before/after and confirming the build still succeeds with it restored."
  - "Removed an empty `dependencies = ();` array the same gem save spuriously added to the PlayOnCarTube native target (not present in the pre-mutation file) — harmless but unrelated churn the plan's acceptance criteria explicitly call out ('no unrelated pbxproj churn beyond the two mutation classes')."
  - "HideScrollBar's status row cannot reuse the original_-selector detection pattern AutoResize uses, because HideScrollBar.m declares only hook_layoutSubviews with no original_ companion (confirmed by reading the file directly). Detection instead compares class_getMethodImplementation on _UIStaticScrollBar against its superclass's IMP for the same selector — a different IMP means the swizzle replaced the method."
  - "The local Xcode/simulator SDK mismatch that blocked 02-01/02-02/02-03's build verification is resolved (iOS 26.3.1 simulator runtime now installed); this plan produces the first real BUILD SUCCEEDED and the first actual-binary scan-private-apis.sh pass of the whole phase, closing out several previously-deferred WINDOWS.md items for the files this plan touches."

requirements-completed: []  # INFRA-04 completes only after Task 3's human checkpoint (see Next Phase Readiness)

coverage:
  - id: D1
    description: "IPHONEOS_DEPLOYMENT_TARGET is 16.0 at all 6 sites and 14.0 nowhere; Dynamic SPM package fully removed (5 object types) and Package.resolved absent"
    requirement: INFRA-04
    verification:
      - kind: unit
        ref: "grep -c 'IPHONEOS_DEPLOYMENT_TARGET = 16.0' project.pbxproj = 6; grep -c '= 14.0' = 0; grep -q 'Dynamic'/'XCRemoteSwiftPackageReference' both absent; find Package.resolved absent"
        status: pass
    human_judgment: false
  - id: D2
    description: "A simulator build of scheme CarTube succeeds for both targets at the iOS 16 floor"
    requirement: INFRA-04
    verification:
      - kind: other
        ref: "xcodebuild -project CarTube.xcodeproj -scheme CarTube -destination 'id=F14D9B48-EF6B-4ACD-BB09-2D5951BF5D0A' build → BUILD SUCCEEDED (both CarTube.app and embedded PlayOnCarTube.appex), run after both Task 1 and Task 2"
        status: pass
    human_judgment: false
  - id: D3
    description: "scripts/scan-private-apis.sh passes on the actual compiled app + appex binaries (not source-level grep) at the new floor"
    requirement: INFRA-04
    verification:
      - kind: other
        ref: "scan-private-apis.sh run directly against CarTube.app/CarTube and CarTube.app/PlugIns/PlayOnCarTube.appex/PlayOnCarTube from the successful build's DerivedData — both exit 0"
        status: pass
    human_judgment: false
  - id: D4
    description: "Debug.swift exposes 4 hook-verification status rows and 3 script re-validation rows, all routed through CarPlaySingleton.shared with no CarPlayViewController reference"
    requirement: INFRA-04
    verification:
      - kind: unit
        ref: "grep assertions for original_setRootViewController, class_getMethodImplementation, _UIStaticScrollBar, _simulateTextEntered, isIdleTimerDisabled, CarPlaySingleton.shared.applyConfiguration, AdBlocker, SponsorBlock, AgeRestrictBypass all present; CarPlayViewController absent — all pass"
        status: pass
    human_judgment: false
  - id: D5
    description: "The four status rows render live PASS/FAIL at runtime on a connected/simulated device, and the three script rows exercise the reload path without crashing"
    requirement: INFRA-04
    verification:
      - kind: manual
        ref: "Task 3 checkpoint:human-verify — NOT executed by this agent; requires a human to launch the app on simulator, navigate to Debug, and read the rows"
        status: unknown
    human_judgment: true
    rationale: "This agent has no simulator-UI-driving capability per its execution instructions; Task 3 is explicitly deferred to the orchestrator's separate human-verify pass."

duration: 24min
completed: 2026-08-18
status: halted
---

# Phase 2 Plan 4: Deployment Target Raise + Hook Verification (Tasks 1-2) Summary

**Raised the iOS deployment floor to 16.0 across all six build configurations, fully removed the orphaned Dynamic SPM package (all five pbxproj object types plus the stale Package.resolved), and extended the Debug screen with a Hook Verification section reporting live PASS/FAIL for AutoResize, HideScrollBar, the keyboard private API, and idle-timer persistence, plus three force-injection rows for the surviving scripts — both tasks proven with a real `BUILD SUCCEEDED` and a passing `scan-private-apis.sh` run against the actual compiled binaries.**

## Status: HALTED at Task 3 (blocking human-verify checkpoint)

This plan has three tasks. **Tasks 1 and 2 are complete, committed, and independently verified.** Task 3 is `<task type="checkpoint:human-verify" gate="blocking">` — it requires launching the app on an iOS simulator and having a human visually read the Debug screen's hook-status rows and exercise the three script-force buttons. Per this execution's explicit instructions, that step was **not** attempted by this agent (no simulator-UI-driving capability in this run) and is left for the orchestrator's separate human-verify pass.

**What Task 3 still requires**, verbatim from `02-04-PLAN.md`:

1. Launch CarTube on the iOS simulator (this agent's environment note confirms `xcodebuild ... -destination 'id=F14D9B48-EF6B-4ACD-BB09-2D5951BF5D0A'` now works — the SDK/runtime mismatch that blocked 02-01/02-02/02-03 is resolved), navigate ContentView → Debug.
2. Read the four status rows: AutoResize and HideScrollBar should show PASS (hooks installed at the iOS 16 runtime); keyboard API row shows whether `_simulateTextEntered` still responds; idle-timer row shows current state. Any FAIL on AutoResize/HideScrollBar is Pitfall 5 materialized — record which hook died before proceeding.
3. Tap each script row (AdBlocker, SponsorBlock, AgeRestrictBypass): confirm the alert appears and no crash follows.
4. Settings screen: confirm no Lock Screen Dimming toggle; change Block Ads, tap Save — app stays running (no quit), change applies in place.
5. Optional but decisive if a CarPlay-capable environment is available: connect the CarPlay simulator/scene and visually confirm safe-area resize and hidden scroll bar; absent the entitlement, phone-side Debug rows are the accepted verification level.

**Resume signal for Task 3:** "approved" if the four status rows render and script rows exercise without crash, or a description of failures (e.g. "HideScrollBar FAIL, keyboard FAIL").

Once Task 3 resolves, the plan's `requirements: [INFRA-04]` frontmatter completes, ROADMAP.md plan progress updates, and the phase-close verification (`scripts/scan-private-apis.sh` on final binaries + hook-verification checklist) is fully satisfied.

## Performance

- **Duration:** 24 min (Tasks 1-2 only; Task 3 not run)
- **Tasks:** 2 of 3 (Task 3 deliberately not attempted — see Status above)
- **Files modified:** 3 (`project.pbxproj`, `Package.resolved` deleted, `Debug.swift`)

## Accomplishments

- `IPHONEOS_DEPLOYMENT_TARGET` raised from 14.0 to 16.0 at all six sites: project-level Debug/Release, CarTube target Debug/Release, PlayOnCarTube target Debug/Release
- Dynamic SPM package fully removed: `PBXBuildFile`, the `Dynamic in Frameworks` build-phase entry, `packageProductDependencies` on the CarTube target, `packageReferences` on the project root object, the `XCRemoteSwiftPackageReference` object, and the `XCSwiftPackageProductDependency` object — all five object types gone, verified by post-save grep
- Stale `Package.resolved` (tracked at `CarTube.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/`) deleted
- Caught and corrected two unrelated side effects of the `xcodeproj` gem's save (see Deviations below) before they could silently regress the build
- **First real `BUILD SUCCEEDED` of the whole phase** — the Xcode 26.3/SDK 26.2 vs. installed-runtime mismatch that blocked build verification in 02-01, 02-02, and 02-03 (see their SUMMARYs and `.planning/WINDOWS.md` entries 4-5) is resolved in this environment; ran successfully against `iPhone 17e` simulator (`id=F14D9B48-EF6B-4ACD-BB09-2D5951BF5D0A`)
- **First actual-binary `scan-private-apis.sh` pass of the whole phase** — ran directly against the built `CarTube.app/CarTube` and `CarTube.app/PlugIns/PlayOnCarTube.appex/PlayOnCarTube` Mach-O binaries (not source-level grep); both exit 0. This closes 02-03's deferred D1/D2 coverage items for the files that plan touched, since they are unmodified by this plan and this plan's build is the first to actually compile them.
- `Debug.swift` extended with:
  - A **Hook Verification** section: `AutoResize` (checks `original_setRootViewController:` presence on `UIWindow` — the swizzle's install-time side effect), `HideScrollBar` (IMP comparison between `_UIStaticScrollBar.layoutSubviews` and its superclass's implementation, since this hook declares no `original_` companion selector), `Keyboard Private API` (`WKWebView.instancesRespond(to:)` for `_simulateTextEntered:`), `Idle Timer Disabled` (`UIApplication.shared.isIdleTimerDisabled`) — a Refresh Status button and `onAppear` both recompute all four
  - A **Script Re-validation** section: three buttons (AdBlocker, SponsorBlock, AgeRestrictBypass) that force the corresponding `UserDefaults` key on, call `CarPlaySingleton.shared.applyConfiguration()` (reusing plan 02-03's extraction), and confirm via `UIApplication.shared.alert`
  - Existing Go Back / Go Home / Toggle Keyboard rows, `.navigationBarTitle`, and the `PreviewProvider` stub left untouched

## Task Commits

Each task was committed atomically:

1. **Task 1: Raise deployment target to 16.0, remove Dynamic SPM package via ruby-xcodeproj** - `aa9bb3d` (feat)
2. **Task 2: Hook-verification debug section — runtime status rows + per-script re-validation rows** - `66eb281` (feat)

**Task 3 (checkpoint:human-verify) not attempted this session — plan halted here by design.**

## Files Created/Modified

- `CarTube.xcodeproj/project.pbxproj` — 6 deployment-target sites raised to 16.0; all 5 Dynamic SPM object types removed; two unrelated gem-save side effects (dropped `dstSubfolder`, spurious empty `dependencies`) corrected before commit
- `CarTube.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` — deleted (stale resolution for the removed package)
- `CarTube/Views/Debug.swift` — added Hook Verification section (4 status rows) and Script Re-validation section (3 force-injection rows); existing rows and structure untouched

## Decisions Made

- Restored `dstSubfolder = PlugIns` on the `Embed Foundation Extensions` copy-files build phase after the `xcodeproj` gem's `project.save` silently dropped it (gem warned: "Xcodeproj doesn't know about the following attributes {\"dstSubfolder\"=>\"PlugIns\"}"). This project's `objectVersion = 90` is newer than the installed gem's schema recognizes for this attribute; leaving it dropped risked the `PlayOnCarTube.appex` not embedding into the correct app-bundle subfolder. Diffed the file post-save, identified the drop, and hand-restored the exact original line before running the build gate — confirmed the build still succeeds with it present.
- Removed a spurious empty `dependencies = ();` array the same gem save added to the `PlayOnCarTube` native target (absent from the pre-mutation file, confirmed via `git show HEAD:...`). Harmless (empty array), but the plan's own acceptance criteria call out "no unrelated pbxproj churn beyond the two mutation classes," so it was removed to keep the diff exactly matching the plan's two mutation classes (deployment-target raise + Dynamic package removal).
- HideScrollBar's status row uses IMP-vs-superclass comparison rather than an `original_`-selector probe, because `HideScrollBar.m` (read directly before writing the check) declares only `hook_layoutSubviews` with no `original_` companion — an `original_layoutSubviews` probe would always report FAIL even when the hook is correctly installed. This follows the plan's explicit `<read_first>` instruction verbatim.
- Task 3 (blocking human-verify checkpoint) intentionally not attempted in this execution — per this run's scope, the executor completes and commits only Tasks 1-2 and halts, leaving the simulator-driven verification to a separate pass.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Restored `dstSubfolder = PlugIns` dropped by the xcodeproj gem's save**
- **Found during:** Task 1, diffing `project.pbxproj` immediately after the ruby mutation script ran
- **Issue:** The gem printed `Xcodeproj doesn't know about the following attributes {"dstSubfolder"=>"PlugIns"} for the 'PBXCopyFilesBuildPhase' isa` and silently omitted the attribute from its re-serialized output — an unrelated side effect of using the gem to make two targeted edits, not something the plan asked for.
- **Fix:** Added the line back with an `Edit` call, verified position matches the original file exactly.
- **Files modified:** `CarTube.xcodeproj/project.pbxproj`
- **Verification:** `git diff` after the fix shows only the two intended mutation classes (deployment target + Dynamic removal); build still succeeds with the appex embedding correctly.
- **Committed in:** `aa9bb3d` (Task 1 commit)

**2. [Rule 1 - Bug] Removed spurious empty `dependencies = ();` array the gem's save introduced**
- **Found during:** Task 1, same diff review
- **Issue:** The gem's save added `dependencies = (\n\t\t\t);` to the `PlayOnCarTube` native target, which had no `dependencies` key at all in the original file (confirmed via `git show HEAD:CarTube.xcodeproj/project.pbxproj`). Harmless (empty array) but unrelated churn.
- **Fix:** Removed the added lines via `Edit`.
- **Files modified:** `CarTube.xcodeproj/project.pbxproj`
- **Verification:** Post-fix `git diff` matches exactly the plan's stated two mutation classes; build still succeeds.
- **Committed in:** `aa9bb3d` (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (both unrelated tool-generated pbxproj churn, corrected before commit; zero functional/behavioral changes beyond the plan's intended scope)
**Impact on plan:** None on scope — both fixes restore the file to exactly the plan's two intended mutation classes.

## Issues Encountered

None. The local SDK/simulator-runtime mismatch that blocked build verification in every prior Phase 2 plan (02-01, 02-02, 02-03 — see their SUMMARYs and `.planning/WINDOWS.md` entries 4-5) is resolved in this environment (iOS 26.3.1 simulator runtime installed), so both tasks' automated `<verify>` gates ran for real with no environment workaround needed.

## TDD Gate Compliance

Neither task in this plan carries `tdd="true"`. Not applicable.

## Next Phase Readiness

- Tasks 1-2 are fully verified and committed; the project builds clean at the iOS 16 floor with zero SPM dependencies and a passing binary-level private-API scan.
- **Task 3 (blocking human-verify checkpoint) is the only remaining step to close this plan and the phase.** It requires a human (or a simulator-UI-driving agent) to launch the app, navigate to the Debug screen, read the four hook-status rows, exercise the three script rows, and verify the Settings apply-in-place behavior — see the "What Task 3 still requires" section above for the exact steps and resume signal.
- Until Task 3 resolves: `requirements: [INFRA-04]` remains open in REQUIREMENTS.md, and ROADMAP.md plan progress for 02-04 should not be marked complete.
- The orchestrator should drive Task 3 in a follow-up pass (per this plan's own `<checkpoint_handling>` instructions) and then close out this plan's STATE.md/ROADMAP.md finalization.

---
*Phase: 02-severance-signing-modernization*
*Completed: 2026-08-18 (Tasks 1-2 only; Task 3 pending)*

## Self-Check: PASSED

- `CarTube.xcodeproj/project.pbxproj`, `CarTube/Views/Debug.swift` confirmed present on disk with expected content
- `CarTube.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` confirmed absent
- Both task commits (`aa9bb3d`, `66eb281`) confirmed present in `git log --oneline`
- `git diff --diff-filter=D --name-only` after each commit reviewed — only the intentional `Package.resolved` deletion (Task 1), documented above
