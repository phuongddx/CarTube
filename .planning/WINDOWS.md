---
schema_version: 1
open_count: 4
waived_count: 0
fixed_count: 0
total_count: 4
last_updated: 2026-08-18T09:54:35.125Z
---

# Broken Windows Ledger

> Cross-phase defect register. With `workflow.windows_enforce` enabled, `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | 01 | deviation | .planning/REQUIREMENTS.md |  | INFRA-01 completion reverted: plan 01-01 delivered only the build-time key delivery; entitlement application (plans 01-02/01-03) still pending | open |  | 2026-08-18T05:00:28.300Z |  |
| 2 | 01 | unrun-verify | Secrets.xcconfig |  | 01-03 Task 2 checkpoint open: restricted Google key not yet created/injected; plutil+gcloud verification unrun until user completes console runbook | open |  | 2026-08-18T07:07:02.911Z |  |
| 3 | 02 | unrun-verify | CarTube.xcodeproj/project.pbxproj |  | 02-01 tracer <verify> could not complete a literal simulator BUILD SUCCEEDED + codesign entitlements dump — local sandbox Xcode 26.3 SDK (iphonesimulator26.2/23C57) has no matching installed simulator runtime (only iOS 26.5/23F77 present); actool CompileAssetCatalogVariant fails on runtime/SDK version mismatch, reproduced on unrelated Dynamic SPM scheme too. Entitlements confirmed empty via plutil and via compiled .xcent during partial build (zero private keys). | open |  | 2026-08-18T09:40:18.811Z |  |
| 4 | 02 | unrun-verify | .github/workflows/scan.yml |  | 02-02 Task 2 real-binary proof-of-detection on the CarTube app executable could not run locally — same Xcode 26.3 SDK 26.2 vs installed-runtime 26.5 mismatch as 02-01: CompileAssetCatalogVariant aborts before the CarTube target's own Swift compile/link, even in target-mode builds bypassing scheme resolution. The real PlayOnCarTube.appex extension binary DID link and was scanned clean (exit 0, genuine Mach-O, not a fixture). Supplementary source-level scan of the real pre-severance CarTube/Util/Utilities.swift confirms MRMediaRemote, BKSDisplayBrightness, SBGetScreenLockStatus, SBSSpringBoardServerPort, PrivateFrameworks/, platform-application markers are present and detected. CI on a matching runtime (or a real device/CI runner) will complete the binary-level proof. | open |  | 2026-08-18T09:54:35.125Z |  |

````json
[
  {
    "id": 1,
    "kind": "deviation",
    "phase": "01",
    "file": ".planning/REQUIREMENTS.md",
    "line": null,
    "description": "INFRA-01 completion reverted: plan 01-01 delivered only the build-time key delivery; entitlement application (plans 01-02/01-03) still pending",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-18T05:00:28.300Z",
    "resolved_at": null
  },
  {
    "id": 2,
    "kind": "unrun-verify",
    "phase": "01",
    "file": "Secrets.xcconfig",
    "line": null,
    "description": "01-03 Task 2 checkpoint open: restricted Google key not yet created/injected; plutil+gcloud verification unrun until user completes console runbook",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-18T07:07:02.911Z",
    "resolved_at": null
  },
  {
    "id": 3,
    "kind": "unrun-verify",
    "phase": "02",
    "file": "CarTube.xcodeproj/project.pbxproj",
    "line": null,
    "description": "02-01 tracer <verify> could not complete a literal simulator BUILD SUCCEEDED + codesign entitlements dump — local sandbox Xcode 26.3 SDK (iphonesimulator26.2/23C57) has no matching installed simulator runtime (only iOS 26.5/23F77 present); actool CompileAssetCatalogVariant fails on runtime/SDK version mismatch, reproduced on unrelated Dynamic SPM scheme too. Entitlements confirmed empty via plutil and via compiled .xcent during partial build (zero private keys).",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-18T09:40:18.811Z",
    "resolved_at": null
  },
  {
    "id": 4,
    "kind": "unrun-verify",
    "phase": "02",
    "file": ".github/workflows/scan.yml",
    "line": null,
    "description": "02-02 Task 2 real-binary proof-of-detection on the CarTube app executable could not run locally — same Xcode 26.3 SDK 26.2 vs installed-runtime 26.5 mismatch as 02-01: CompileAssetCatalogVariant aborts before the CarTube target's own Swift compile/link, even in target-mode builds bypassing scheme resolution. The real PlayOnCarTube.appex extension binary DID link and was scanned clean (exit 0, genuine Mach-O, not a fixture). Supplementary source-level scan of the real pre-severance CarTube/Util/Utilities.swift confirms MRMediaRemote, BKSDisplayBrightness, SBGetScreenLockStatus, SBSSpringBoardServerPort, PrivateFrameworks/, platform-application markers are present and detected. CI on a matching runtime (or a real device/CI runner) will complete the binary-level proof.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-18T09:54:35.125Z",
    "resolved_at": null
  }
]
````
