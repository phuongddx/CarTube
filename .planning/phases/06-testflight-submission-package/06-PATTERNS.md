# Phase 6: TestFlight Submission Package - Pattern Map

**Mapped:** 2026-08-18
**Files analyzed:** 8 (3 docs created, 2 Swift modified, 1 gate re-run, 1 process, 1 conditional runbook execution)
**Analogs found:** 7 / 8

No `CONTEXT.md` or `RESEARCH.md` exists in this phase directory; the file list below is derived from ROADMAP.md Phase 6 success criteria 1-4 (SHIP-01..03), the orchestrator's scope statement, and PITFALLS.md Pitfall 10 + Security Mistakes table.

**Codebase state verified at mapping time (2026-08-18):** Phases 1-5 are **not executed** (STATE.md: 0 plans completed). `docs/` does not exist (created by Phase 1 plan 01-02); `scripts/scan-private-apis.sh` does not exist (created by Phase 2 plan 02-02); deployment target is still `14.0`; the repo has zero `Codable` usage. Phase 6 executes last, so the planner should assume the post-Phase-2..5 state: iOS 16 floor, scan gate + CI present, `docs/runbooks/` present, Phase 3's `Search/` Codable convention established. Current line numbers below are verified against today's tree and will have shifted by execution time — re-grep before editing.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `CarTube/CarTubeApp.swift` (MODIFY: harden `checkNewVersions`) | service / entry | request-response | itself — `checkNewVersions` (`CarTubeApp.swift:55-69`) + Phase 3 `Search/` typed-decode convention (`03-PATTERNS.md`) | exact (self) |
| `CarTube/Views/ContentView.swift` (MODIFY: explicit paste) | component | event-driven | itself — `onChange(of: scenePhase)` pasteboard block (`ContentView.swift:81-89`) + existing Section/Button rows (`ContentView.swift:46-52`) | exact (self) |
| `docs/submission/app-review-notes.md` (CREATE) | docs | n/a | Phase 1 runbook spec — `01-02-PLAN.md` (numbered steps, literal-marker paste blocks, grep wording gates) | role-match |
| `docs/submission/app-store-metadata.md` (CREATE) | docs | n/a | Phase 1 runbook spec — `01-02-PLAN.md` negative-grep verify pattern; in-app copy reference `CarTube/Views/HowTo.swift:16` | role-match |
| `docs/submission/fallback-ladder.md` (CREATE) | docs | n/a | Phase 1 runbook spec + PITFALLS.md Recovery Strategies row "Rejected on 4.2/5.2.3" | role-match |
| `scripts/scan-private-apis.sh` (RE-RUN on archive binaries, no modification) | gate | batch | itself — Phase 2 `02-02-PLAN.md` verify command (BUILT_PRODUCTS_DIR derivation, both binaries) | exact |
| Archive + TestFlight upload commands (process; optionally `scripts/release-archive.sh`) | build | batch | none — `ipabuild.sh` is the **anti-analog** (TrollStore pipeline, deleted by Phase 2); shell conventions only | none |
| `docs/runbooks/carplay-entitlement-grant-wiring.md` (CONDITIONAL EXECUTE if grant lands) | runbook | n/a | itself — written by Phase 1 plan 01-02; pbxproj signing sites verified below | exact |

---

## Pattern Assignments

### `CarTube/CarTubeApp.swift` (service/entry, request-response — SHIP-03 update-check hardening)

**Analog:** itself — `checkNewVersions` is the only URLSession call site in the app.

**Current shape to replace** (`CarTubeApp.swift:55-69`):
```swift
func checkNewVersions() {
    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, let url = URL(string: "https://api.github.com/repos/Avangelista/CarTube/releases/latest") {
        let task = URLSession.shared.dataTask(with: url) {(data, response, error) in
            guard let data = data else { return }
            
            if let json = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] {
                if (json["tag_name"] as? String)?.compare(version, options: .numeric) == .orderedDescending {
                    UIApplication.shared.confirmAlert(title: "Update Available", body: "A new version of CarTube is available.\n\(json["body"] as? String ?? "Updating is recommended to avoid bugs.")\nWould you like to view the releases page?", onOK: {
                        UIApplication.shared.open(URL(string: "https://github.com/Avangelista/CarTube/releases/latest")!)
                    }, noCancel: false, window: .main)
                }
            }
        }
        task.resume()
    }
}
```

**The four weaknesses the hardening must close** (PITFALLS Security Mistakes table: "Unvalidated GitHub update-check response rendered in an alert"):
1. `response` is ignored — no `HTTPURLResponse` status check (line 57-58)
2. `try?` swallows decode failure silently (line 60)
3. `as? [String: Any]` dictionary-cast is schema-drift-fragile (line 60)
4. `json["body"] as? String ?? ...` interpolates **arbitrary remote text** into an alert body (line 62)

**Typed-decode replacement shape** — mirror Phase 3's convention (per `03-PATTERNS.md`: decode with `Codable`, not `JSONSerialization`; the analog's dictionary-cast is the pattern to *replace*). By Phase 6 the `Search/` service establishes the house `Codable` style; the update check follows it:
```swift
struct GitHubRelease: Codable {
    let tagName: String
    let body: String?
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case body
    }
}

guard let http = response as? HTTPURLResponse, http.statusCode == 200,
      let release = try? JSONDecoder().decode(GitHubRelease.self, from: data),
      release.tagName.compare(version, options: .numeric) == .orderedDescending else { return }
```
Keep unchanged: the `URLSession.shared.dataTask` completion shape, `task.resume()`, version comparison via `.numeric`, and the `UIApplication.shared.confirmAlert` display (`CarTubeApp.swift:62-65`) — `confirmAlert` is already main-dispatched (`Alert++.swift:24-33`), so no extra `DispatchQueue.main` hop is needed.

**Planner decision points (encode explicitly):**
- **Harden vs. remove.** PITFALLS suggests "consider removing the GitHub check for the App Store build." ROADMAP criterion 3 requires validation, so hardening is the requirement; removal is the alternative to present. Supporting fact: the URL points at the **upstream** repo (`Avangelista/CarTube`), but this is a fork (`phuongddx/CarTube` per `01-01-PLAN.md`) — upstream releases never match App Store versions anyway, so the check is arguably meaningless for the shipped build.
- **Remote `body` text in the alert.** Even schema-validated, `release.body` is remote-rendered content. Validated decode + HTTPS + status check satisfies "validated before display"; dropping the body interpolation in favor of static copy eliminates it entirely. Either is defensible; pick one.
- **URL constant.** Move both GitHub URLs (`Constants.swift` convention: SCREAMING_SNAKE_CASE beside `YT_HOME`/`YT_EMBED`/`YT_SEARCH`, `Constants.swift:10-13`) — no inline URL strings in Swift, matching how every existing URL is handled.
- **No new UserDefaults key** unless a toggle is added; if one is, the three-file contract applies (see Shared Patterns).

---

### `CarTube/Views/ContentView.swift` (component, event-driven — SHIP-03 explicit paste)

**Analog:** itself — the activation-read block is the deletion target; sibling rows are the placement template.

**Current shape to replace** (`ContentView.swift:81-89`):
```swift
}.onChange(of: scenePhase) { newPhase in
    if newPhase == .active {
        let clipboard = UIPasteboard.general
        if clipboard.hasURLs {
            if let clipboardUrl = clipboard.url?.absoluteString {
                if isYouTubeURL(clipboardUrl) {
                    urlString = clipboardUrl
                }
            }
        }
    }
}
```
This is the **only** pasteboard access in the repo (verified by grep: `UIPasteboard` appears solely at `ContentView.swift:83`). Deleting the whole `onChange` modifier also removes the last use of `scenePhase` — delete `@Environment(\.scenePhase) var scenePhase` (`ContentView.swift:18`) in the same edit (verified: lines 18 and 81 are its only uses). The deprecated single-parameter `onChange` form dies with it, which `02-PATTERNS.md` already flagged.

**Placement template** — the URL-input Section the paste affordance joins (`ContentView.swift:46-52`):
```swift
Section {
    TextField("YouTube URL", text: $urlString, onCommit: { playVideo() })
    Button("Play on CarPlay") {
        hideKeyboard()
        playVideo()
    }
}
```

**Replacement options (planner picks one):**

**(a) SwiftUI `PasteButton`** — iOS 16+ (available: deployment target is 16.0 after Phase 2), system paste affordance, **no paste-permission banner**, no `UIPasteboard` code at all:
```swift
PasteButton(payloadType: String.self) { strings in
    if let pasted = strings.first, isYouTubeURL(pasted) {
        urlString = pasted
    }
}
```
Caveats: `PasteButton` brings its own label/tint styling and does not inherit `Button` styles; `payloadType: URL.self` is the natural fit but YouTube URLs arriving as text (shared strings) argue for `String.self` + the existing `isYouTubeURL` check. First use in the repo — no in-repo precedent.

**(b) Explicit `Button` reading the pasteboard on tap** — matches the sibling-row style exactly (`ContentView.swift:48-51`), keeps `isYouTubeURL`:
```swift
Button("Paste YouTube Link") {
    if let pasted = UIPasteboard.general.string, isYouTubeURL(pasted) {
        urlString = pasted
    }
}
```
User-initiated read: iOS may still show the system paste notification, but it is user-consented — the PITFALLS concern ("Reading general pasteboard on activation") is the *activation* read, which this removes. `.string` (not `.url`) handles both shared URLs and bare text through the one parser.

Either option keeps the downstream path untouched: `urlString` state (`ContentView.swift:20`) → `playVideo()` (`ContentView.swift:22-29`) → `extractYouTubeVideoID` → `YT_EMBED` → `CarPlaySingleton.shared.loadUrl`. No CarPlay-file changes.

---

### `docs/submission/app-review-notes.md` (docs — SHIP-01)

**Analog:** the Phase 1 runbook spec (`01-02-PLAN.md`) — the project's established convention for reviewer/facing documents. The runbooks themselves don't exist yet at mapping time (Phase 1 unexecuted), so the PLAN text is the authority: `01-02-PLAN.md:75-79` prescribes their structure.

**Conventions to copy from the runbook spec:**
- Numbered-step click-path sections for anything portal-side
- Paste-ready blocks delimited by **literal marker lines** (`REQUEST-TEXT-BEGIN` / `REQUEST-TEXT-END`, `01-02-PLAN.md:77`) so copy text is machine-extractable
- Prerequisites section up front (the runbook's names team `U67AKNW8PW`, paid membership, bundle-ID decision — the review-notes doc should restate the confirmed bundle ID and audio category as its ground truth)
- Grep-based verify gates on wording (see Shared Patterns)

**Content anchors for the honest description (PITFALLS Pitfall 10):**
- Review notes must "describe the webview-video mechanism specifically" (guideline 2.3.1) — the mechanism, from the codebase: `UIWindowSceneSessionRoleCarPlay` scene (`CarTube/Info.plist` `UIApplicationSceneManifest`) → `CarPlaySceneDelegate` → `CarPlayViewController` hosting a `WKWebView` loading `https://m.youtube.com/` (`Constants.swift:10-13`) with feature scripts injected at `.atDocumentEnd` (`CarPlayViewController.swift` per `02-PATTERNS.md` excerpt).
- Honest framing under the **audio** category (Pitfall 2: the app provides audio playback of YouTube content through the vehicle's system; the video surface carries residual risk, recorded as a Key Decision in Phase 1).

**Tension the planner must reconcile explicitly:** the Phase 1 entitlement request text is *deliberately* negative-gated to omit `watch|driving|video|driver` (`01-02-PLAN.md:85` verify gate), while review notes are required to honestly describe the video surface. These are different documents with different contracts — the request states the app's purpose; the review notes disclose the implementation. Do not copy the request text into the review notes; write the notes to satisfy 2.3.1 while remaining consistent with the audio-category positioning. Name this reconciliation in the plan.

---

### `docs/submission/app-store-metadata.md` (docs — SHIP-01)

**Analog:** same runbook spec; plus a negative-wording gate modeled on `01-02-PLAN.md:85`:
```bash
sed -n '/METADATA-BEGIN/,/METADATA-END/p' docs/submission/app-store-metadata.md | grep -icE 'ad[- ]?block|sponsorblock|sponsor|age[- ]?restrict|bypass'
# must print 0
```
PITFALLS Pitfall 8 warning sign: "'Ad blocking' is marketed in App Store metadata while the Data API key is registered — the pairing an auditor/reviewer notices first." Pitfall 10: copy describes "YouTube player for CarPlay" without ad-block/age-bypass claims (2.3.7/5.2.1 also constrain name/icon branding).

**In-repo copy reference:** `HowTo.swift:16` shows the app's current user-facing voice ("Enjoy a full-feature YouTube experience in the car!") — the register to write metadata in, minus the feature-specific claims.

**Planner decision point:** in-app copy is *not* App Store metadata. `Settings.swift:38-51` ships visible toggles named "Block Ads (Beta)", "SponsorBlock", "Age Restriction Bypass". 2.3.1 concerns *hidden* functionality — disclosed in-app features described honestly in review notes are not hidden — but the planner should state this position in the doc rather than leave it implicit. Renaming in-app toggles is out of Phase 6 scope (no roadmap criterion asks for it).

---

### `docs/submission/fallback-ladder.md` (docs — SHIP-02)

**Analog:** runbook structure + the PITFALLS Recovery Strategies row that already defines the ladder:
> "Rejected on 4.2/5.2.3 (webview video) — HIGH (accepted risk) — Invoke fallback ladder: parked-gating or audio-UI variant as fast-follow; search/voice assets are reusable — this is why they are kept decoupled"

**Ladder content to document** (from Pitfall 10 "How to avoid"):
1. **Rung 0 — webview survives** (submission passes): no action
2. **Rung 1 — parked-gate variant**: detect CarPlay driving/parked state; video surface available only when parked (note: this is the video-category shape and contradicts the milestone's Core Value — document as accepted trade-off of the rung, not a plan)
3. **Rung 2 — audio-UI variant**: template-based CarPlay audio surface replacing the raw webview scene
4. Under every rung: search/voice assets are reusable because Phases 3-5 kept them decoupled behind `SearchCoordinator` (ROADMAP Phase 4 criterion 3)

Each rung should follow the runbook convention: what changes, what it costs, what triggers moving to it (the specific rejection guideline: 4.2, 5.2.2/5.2.3, CarPlay template rules, per Pitfall 10's four vectors).

---

### `scripts/scan-private-apis.sh` re-run on archive binaries (gate, batch — ROADMAP Phase 6 criterion 4)

**Analog:** itself — Phase 2 plan 02-02's verify command shape (`02-02-PLAN.md:106`):
```bash
BP=$(xcodebuild -project CarTube.xcodeproj -scheme CarTube -destination 'platform=iOS Simulator,name=iPhone Air' -showBuildSettings 2>/dev/null | grep -m1 'BUILT_PRODUCTS_DIR = ' | awk '{ print $3 }')
scripts/scan-private-apis.sh "$BP/CarTube.app/CarTube"
scripts/scan-private-apis.sh "$BP/CarTube.app/PlugIns/PlayOnCarTube.appex/PlayOnCarTube"
```
The script's contract (any binary-path argument; `SCAN_INPUT_FILE` override) supports scanning archive products directly. For the **final archive**, scan the Release archive's binaries, not the CI Debug-simulator products:
```bash
scripts/scan-private-apis.sh build/CarTube.xcarchive/Products/Applications/CarTube.app/CarTube
scripts/scan-private-apis.sh build/CarTube.xcarchive/Products/Applications/CarTube.app/PlugIns/PlayOnCarTube.appex/PlayOnCarTube
```
Exit 0 on both = scan-clean (ROADMAP Phase 6 criterion 4: "final scan-clean archive of app + share extension"). No modification to the script or its 15-marker list is in Phase 6 scope; a hit means a Phase 2-5 regression, not a gate change.

---

### Archive + TestFlight upload (build, batch — ROADMAP Phase 6 criterion 4) — no analog

**No in-repo analog.** `ipabuild.sh` is the **anti-analog**: its pipeline (`CODE_SIGNING_ALLOWED="NO"` line 25, `codesign --remove` line 32, `ldid -S...entitlements` line 44, unsigned `Payload/` zip lines 46-53) is precisely the TrollStore path Phase 2 deletes and Phase 6 must not resurrect. Only its shell conventions transfer: `set -e` (line 3), `cd "$(dirname "$0")"` (line 5), and `rm -rf` of the stale target before any `cp -r` (lines 28-29).

**Standard command shapes to document in the plan (verified platform-standard, no repo precedent):**
```bash
xcodebuild -project CarTube.xcodeproj -scheme CarTube \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/CarTube.xcarchive \
  archive

xcodebuild -exportArchive \
  -archivePath build/CarTube.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath build/export

xcrun altool --upload-app -f build/export/CarTube.ipa \
  --apiKey $ASC_KEY_ID --apiIssuer $ASC_ISSUER_ID
```
Notes for the planner:
- The `xcodebuild` invocation mirrors the shapes already in-repo: `-destination 'generic/platform=iOS'` is exactly `ipabuild.sh:23`; `-derivedDataPath`/`-project/-scheme` conventions come from `01-01-PLAN.md:86` and `02-02-PLAN.md`.
- `ExportOptions.plist` does not exist (none in repo) — must be created: `method` = `app-store-connect` (aka `app-store`), `teamID` = `U67AKNW8PW`, and `signingStyle`/`provisioningProfiles` tied to the entitlement-switch decision below.
- `altool` App Store Connect API auth requires a key created in App Store Connect (Users and Access → Integrations); key material is a secret — follow the Phase 1 hygiene pattern (gitignored, never committed, `git grep` negative gate) exactly as `Secrets.xcconfig` is handled (`01-01-PLAN.md:88-89`).
- "Upload under standard signing" = the archive signs with the real team identity; there is nothing to strip or re-sign afterward — the opposite of `ipabuild.sh`.

---

### Entitlement-era provisioning switch (conditional — ROADMAP Notes: "re-verified in Phase 6 with the new provisioning profile and automatic signing off")

**Analog:** `docs/runbooks/carplay-entitlement-grant-wiring.md` (authored by Phase 1 plan 01-02) — if the grant lands before/during Phase 6, **execute that runbook verbatim**; do not re-derive the sequence. Its prescribed steps (`01-02-PLAN.md:79`): portal capability enable → new provisioning profile → import into Xcode → add `com.apple.developer.carplay-audio` = true to `CarTube/CarTube.entitlements` → **turn OFF "Automatically manage signing"** → confirm `CODE_SIGN_ENTITLEMENTS` still points at `CarTube/CarTube.entitlements` → verify the CarPlay scene connects in the CarPlay Simulator.

**pbxproj edit sites for automatic-signing-off** (verified today; lines will shift): `CODE_SIGN_STYLE = Automatic` + `DEVELOPMENT_TEAM = U67AKNW8PW` on all four target configs at `project.pbxproj:558/561, 601/604, 639/641, 666/668`. Switching to manual adds `PROVISIONING_PROFILE_SPECIFIER` per config. Mutate via the house method — throwaway ruby `xcodeproj` gem script, deleted after running (`01-01-PLAN.md:79` recipe), never hand-edited.

**Dependency note:** the runbook's sequencing constraint (only grantable keys in the entitlements file) is Phase 2's `INFRA-02` outcome — by Phase 6 the file already holds only grantable keys, so the runbook executes without its fallback branch.

---

## Shared Patterns

### Typed network decode (applies to the update check)
Established by Phase 3 (`03-PATTERNS.md` deviation 2): `Codable` + `JSONDecoder`, never `JSONSerialization` dictionary-casting. `CarTubeApp.swift:60` is the last remaining dictionary-cast in the app after this phase — the planner should assert that (grep `JSONSerialization` returns zero post-phase).

### URL constants
All URLs live in `CarTube/Util/Constants.swift` as SCREAMING_SNAKE_CASE (`Constants.swift:10-13`: `YT_HOME`, `YT_EMBED`, `YT_SEARCH`). GitHub release URLs move there; no inline `URL(string:)` literals in Swift bodies.

### Alert routing
All user-facing popups route through `UIApplication.shared.alert` / `confirmAlert` (`Alert++.swift:23-43`), main-dispatched internally — the update alert keeps its existing `confirmAlert` call unchanged.

### Docs/deliverable convention (applies to all three `docs/submission/` files)
From the Phase 1 runbook spec (`01-02-PLAN.md:75-79, 85`): numbered steps, prerequisites naming team ID and confirmed bundle ID, paste-ready blocks between literal `*-BEGIN`/`*-END` marker lines, and grep-extractable verify gates on the machine-checkable invariants (wording negatives for metadata; category/key presence for review notes).

### Shell script conventions
`set -e`, `cd "$(dirname "$0")"`, derived-path derivation via `xcodebuild -showBuildSettings | grep BUILT_PRODUCTS_DIR` (`ipabuild.sh:3-5`, `02-02-PLAN.md:106`) — applies if the archive/upload steps are scripted rather than run ad hoc.

### Secrets hygiene (applies to any App Store Connect API key material)
The `Secrets.xcconfig` pattern (`01-01-PLAN.md`): committed example/placeholder only, real value gitignored, `git grep -nE '<key-pattern>'` negative gate in acceptance criteria.

### Settings-key three-file contract — expected NOT to apply
Phase 6 adds no UserDefaults key (paste interaction and update-check hardening are stateless). If a plan adds one anyway, it must touch registration (`CarTubeApp.swift registerDefaults`), state+write (`Settings.swift`), and consumption together (CONVENTIONS.md).

---

## No Analog Found

| File/Item | Role | Data Flow | Reason |
|------|------|-----------|--------|
| Archive / `ExportOptions.plist` / `xcrun altool` upload | build / config | batch | No standard-signing archive or upload tooling exists in the repo. `ipabuild.sh` is the anti-analog (TrollStore: unsigned build, signature stripped, `ldid` re-sign, zip) and is deleted in Phase 2. Use the standard command shapes quoted above; treat every `ipabuild.sh` signing step as a do-not-copy. |
| `PasteButton` / `UIPasteControl` usage | component | event-driven | Zero paste-affordance components in the repo; `UIPasteboard.general` is accessed only at the activation-read site being deleted (`ContentView.swift:83`). First use; standard SwiftUI shape quoted above. |
| App Store Connect API key handling | config / secret | n/a | No ASC credentials anywhere in repo; nearest convention is the Phase 1 xcconfig secret pattern — apply its hygiene gates verbatim. |

## Metadata

**Analog search scope:** `CarTube/` (all Swift sources — update-check, pasteboard, alert, constants, views), `CarTube.xcodeproj/project.pbxproj` (signing/deployment sites), repo root (`ipabuild.sh`, `.gitignore`), `.planning/phases/01-*` (runbook + secret conventions), `.planning/phases/02-*` (scan-gate, pbxproj recipes), `.planning/phases/03-PATTERNS.md` (Codable convention), `.planning/research/PITFALLS.md` (Pitfall 10, Security Mistakes, Recovery Strategies), `.planning/ROADMAP.md` (Phase 6 criteria + Notes)
**Files scanned:** 14 source/config files + 6 planning artifacts; grep across `.swift/.m/.h` for `UIPasteboard|PasteButton|JSONSerialization|Codable|altool|scenePhase`
**Pattern extraction date:** 2026-08-18
