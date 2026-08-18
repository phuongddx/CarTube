# Temporary working notes — Phase 2 planning defaults (user declined to choose; defaults applied)

## NoSleep entitlement keys — REMOVE ALL PRIVATE KEYS

INFRA-02 ("All TrollStore artifacts removed (private entitlement keys, ipabuild.sh, ldid pipeline)")
is the approved requirement and wins over keeping SBStarkCapable/runningboard for NoSleep.
Consequence: NoSleep may stop working under standard signing. Plans must:
- Replace/guard NoSleep with a public `UIScreen`/idle-timer strategy where possible
  (milestone research Performance Traps table suggests exactly this)
- Treat NoSleep breakage as detectable via the INFRA-04 hook-verification debug screen,
  not as a blocker
- The hidden second WKWebView (NoSleep-only) is a candidate for removal per CONCERNS.md —
  planner decides based on whether the idle-timer replacement lands

## Strings scan gate — REMOVED SYMBOLS ONLY

Gate fails on markers this phase removes: MRMediaRemote*, BKSDisplayBrightness*,
SBGetScreenLockStatus, SBSSpringBoardServerPort, kMRMediaRemoteNowPlayingInfo*,
PrivateFrameworks/ paths, com.apple.springboard.* notify keys, TrollStore entitlement keys
(platform-application, no-container, container-manager, backboard.displaybrightness).
Surviving private WebKit calls (_simulateTextEntered, _hasSleepDisabler) and remaining
AutoHook swizzling are OUT of the gate — part of the user-accepted webview-video risk
("Remove riskiest, keep webview" decision, PROJECT.md Key Decisions).

## Status

To be superseded by plans/Key Decisions. Delete before milestone completion.
