#!/bin/bash
#
# scan-private-apis.sh — permanent private-API regression gate (INFRA-05).
#
# Scans a built Mach-O binary for string markers of the private APIs Phase 2
# (severance-signing-modernization) REMOVES from CarTube: MediaRemote
# now-playing interception, BackBoardServices brightness control,
# SpringBoard lock-state/port reads, and the TrollStore-era entitlement
# keys. Prints every marker it finds, then fails — a clean binary exits 0.
#
# Deliberately NOT markers (do not add these — they are load-bearing
# survivors, not regressions):
#   - com.apple.springboard.hasBlankedScreen — powers the surviving
#     screen-off warning label (ROADMAP success criterion 2); permanent
#     exclusion.
#   - com.apple.springboard.lockstate — removed by plan 02-03, but kept out
#     of the marker list on purpose: a regression that re-adds
#     registerForUnlockNotification always ships with brightness code, which
#     the BKSDisplayBrightness/SBGetScreenLockStatus family markers already
#     catch, so excluding this notify key alone lets the surviving notify
#     mechanism itself never trip the gate.
#   - _simulateTextEntered, _hasSleepDisabler — surviving private WebKit
#     selectors (on-CarPlay keyboard input, NoSleep webview); out of scope
#     per the accepted webview-video risk.
#
# Usage:
#   scan-private-apis.sh <path-to-binary>
#
# Test hook (hermetic, bypasses `strings`):
#   SCAN_INPUT_FILE=<path> scan-private-apis.sh <ignored-arg>

set -eu
set -o pipefail

MARKERS=(
  "MRMediaRemote"
  "kMRMediaRemoteNowPlayingInfo"
  "_MRNowPlayingClientProtobuf"
  "BKSDisplayBrightness"
  "SBGetScreenLockStatus"
  "SBSSpringBoardServerPort"
  "SBBacklightLevel"
  "PrivateFrameworks/"
  "platform-application"
  "com.apple.private.security.no-container"
  "com.apple.private.security.container-manager"
  "com.apple.backboard.displaybrightness"
  "SBStarkCapable"
  "com.apple.runningboard.assertions.webkit"
  "com.apple.multitasking.systemappassertions"
)

usage() {
  echo "Usage: $0 <path-to-binary>" >&2
}

if [ -n "${SCAN_INPUT_FILE:-}" ]; then
  if [ ! -f "$SCAN_INPUT_FILE" ]; then
    usage
    echo "scan-private-apis.sh: SCAN_INPUT_FILE not found: $SCAN_INPUT_FILE" >&2
    exit 1
  fi
  SCAN_OUTPUT="$(cat "$SCAN_INPUT_FILE")"
else
  if [ "$#" -lt 1 ] || [ -z "${1:-}" ]; then
    usage
    exit 1
  fi
  BINARY_PATH="$1"
  if [ ! -f "$BINARY_PATH" ]; then
    usage
    echo "scan-private-apis.sh: binary not found: $BINARY_PATH" >&2
    exit 1
  fi
  SCAN_OUTPUT="$(strings "$BINARY_PATH")"
fi

HIT=0
for marker in "${MARKERS[@]}"; do
  if grep -q -- "$marker" <<< "$SCAN_OUTPUT"; then
    echo "PRIVATE API MARKER FOUND: $marker"
    HIT=1
  fi
done

if [ "$HIT" -eq 1 ]; then
  exit 1
fi

exit 0
