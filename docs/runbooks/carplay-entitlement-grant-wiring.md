# Runbook: Wiring the CarPlay Entitlement Grant

**Purpose:** Execute this the day Apple grants the CarPlay entitlement for App ID `com.cartube.carplay` — regardless of which milestone phase is active when the grant lands. It follows the post-grant sequence from Apple's CarPlay Developer Guide (2026-06-08).

**Related:** `docs/runbooks/apple-carplay-entitlement-request.md` (the submission script)

---

## ⚠️ Sequencing constraint — read before step 1

**Resolved (Phase 2, INFRA-02):** `CarTube/CarTube.entitlements` was emptied to a bare plist dict — the seven private keys once listed here (`SBStarkCapable`, `com.apple.runningboard.assertions.webkit`, `com.apple.multitasking.systemappassertions`, `com.apple.backboard.displaybrightness`, `platform-application`, `com.apple.private.security.no-container`, `com.apple.private.security.container-manager`) are gone, and the private-signing packaging pipeline that required them was deleted in the same phase. The file now holds no keys at all, so it is ready for the CarPlay key to be added directly — no cleanup step is needed before step 8 below.

If this runbook is ever executed against an older checkout where that phase has not yet run, finish that cleanup first: a standard-profile build signs against the entitlements file as-is, so signing fails until the file holds only grantable keys.

## ⚠️ The wiring alone does not make CarPlay work (2026-08-29)

Completing this runbook attaches the entitlement. It does **not** produce a working CarPlay
surface: the app's scene manifest declares the undocumented `UIWindowSceneSessionRoleCarPlay`
role, which iOS 26 does not vend a scene for. That is a separate code change — see
`plans/reports/carplay-scene-regression-root-cause-260827-2356-template-migration-report.md`.

**The simulator cannot validate any of this.** Xcode strips
`com.apple.developer.carplay-audio` from simulator builds under ad-hoc "Sign to Run
Locally" (verified: both the generated `.xcent` and the signed app carry an empty
entitlements dict), yet the app still appears on the simulator's CarPlay home screen. A
green simulator run therefore proves nothing about the entitlement path — only a device
build signed with the real CarPlay provisioning profile does.

## Post-grant sequence

1. Log in to **developer.apple.com/account**.
2. **Certificates, IDs & Profiles → Identifiers.**
3. Select the App ID `com.cartube.carplay`.
4. Enable the CarPlay entitlements.
5. **Save.**
6. **Provisioning Profiles →** create a new provisioning profile for the App ID.
7. Import the profile into Xcode (Xcode and Simulator require a provisioning profile that supports CarPlay).
8. Add the key `com.apple.developer.carplay-audio` with value `true` to the entitlements file (per the sequencing constraint above, the file must contain only grantable keys at this point):

```xml
<key>com.apple.developer.carplay-audio</key>
<true/>
```

9. Xcode **Signing & Capabilities →** turn **OFF** "Automatically manage signing" and select the imported profile.
10. Confirm **Build Settings → Code Signing Entitlements** still points at `CarTube/CarTube.entitlements` (current project already sets `CODE_SIGN_ENTITLEMENTS = CarTube/CarTube.entitlements;`).
11. Verify the CarPlay scene connects using the **CarPlay Simulator** from **Additional Tools for Xcode** (download from developer.apple.com/download/all → "Additional Tools for Xcode" when the grant lands).

## While the grant is still pending

No action. Phases 3–5 of the milestone proceed against phone-side mocks; only on-device CarPlay verification is gated on this grant. The dated pending record lives in `.planning/STATE.md` under Blockers/Concerns.
