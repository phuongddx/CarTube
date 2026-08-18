# Runbook: Wiring the CarPlay Entitlement Grant

**Purpose:** Execute this the day Apple grants the CarPlay entitlement for App ID `com.cartube.carplay` — regardless of which milestone phase is active when the grant lands. It follows the post-grant sequence from Apple's CarPlay Developer Guide (2026-06-08).

**Related:** `docs/runbooks/apple-carplay-entitlement-request.md` (the submission script)

---

## ⚠️ Sequencing constraint — read before step 1

The current `CarTube/CarTube.entitlements` file contains **only** TrollStore private keys, none of which are grantable by a real provisioning profile:

| # | Ungrantable key currently in `CarTube/CarTube.entitlements` |
|---|---|
| 1 | `SBStarkCapable` |
| 2 | `com.apple.runningboard.assertions.webkit` |
| 3 | `com.apple.multitasking.systemappassertions` |
| 4 | `com.apple.backboard.displaybrightness` |
| 5 | `platform-application` |
| 6 | `com.apple.private.security.no-container` |
| 7 | `com.apple.private.security.container-manager` |

A standard-profile build signs against the entitlements file as-is, so **signing fails until the file holds only grantable keys**. Stripping these keys is Phase 2 (INFRA-02) scope and must not be pulled forward casually — the TrollStore `ipabuild.sh` path still needs them until Phase 2 removes it. Therefore, before step 8 below:

- **If Phase 2 is already complete:** the entitlements file is clean; just add the CarPlay key per step 8.
- **If the grant lands before Phase 2 completes:** either finish Phase 2's entitlements cleanup first, or — as part of executing this runbook — swap in a clean entitlements file (back up the TrollStore file if the `ipabuild.sh` path is still needed) containing only:

```xml
<key>com.apple.developer.carplay-audio</key>
<true/>
```

Then rebuild and verify per steps 10–11. Any other keys desired later (e.g., app-group identifiers used by real signing) must each be individually grantable by the provisioning profile.

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
