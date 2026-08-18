---
schema_version: 1
open_count: 1
waived_count: 0
fixed_count: 0
total_count: 1
last_updated: 2026-08-18T05:00:28.300Z
---

# Broken Windows Ledger

> Cross-phase defect register. With `workflow.windows_enforce` enabled, `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | 01 | deviation | .planning/REQUIREMENTS.md |  | INFRA-01 completion reverted: plan 01-01 delivered only the build-time key delivery; entitlement application (plans 01-02/01-03) still pending | open |  | 2026-08-18T05:00:28.300Z |  |

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
  }
]
````
