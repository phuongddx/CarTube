#!/bin/bash
#
# Hermetic six-case test suite for scripts/scan-private-apis.sh (INFRA-05).
# Fixtures are plain text files fed via the SCAN_INPUT_FILE override so no
# real Mach-O binary or build is required to validate match/no-match logic.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCAN_SCRIPT="$SCRIPT_DIR/../scan-private-apis.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PASS=0
FAIL=0
FIXTURE_COUNT=0

record_pass() {
  echo "PASS: $1"
  PASS=$((PASS + 1))
}

record_fail() {
  echo "FAIL: $1"
  FAIL=$((FAIL + 1))
}

# Sets LAST_OUTPUT / LAST_EXIT from a fixture built out of $1 (fixture body).
run_scan() {
  FIXTURE_COUNT=$((FIXTURE_COUNT + 1))
  local fixture_file="$TMP_DIR/fixture-$FIXTURE_COUNT.txt"
  printf '%s\n' "$1" > "$fixture_file"
  LAST_OUTPUT="$(SCAN_INPUT_FILE="$fixture_file" "$SCAN_SCRIPT" "$fixture_file" 2>&1)"
  LAST_EXIT=$?
}

# Test 1: MediaRemote marker detected, non-zero exit, marker name printed
run_scan "benign string one
MRMediaRemoteGetNowPlayingInfo
benign string two"
if [ "$LAST_EXIT" -ne 0 ] && echo "$LAST_OUTPUT" | grep -q "MRMediaRemote"; then
  record_pass "Test 1 - MRMediaRemote marker exits non-zero and is named"
else
  record_fail "Test 1 - MRMediaRemote marker exits non-zero and is named (exit=$LAST_EXIT, output=$LAST_OUTPUT)"
fi

# Test 2: BackBoardServices brightness marker detected
run_scan "benign string one
BKSDisplayBrightnessSet
benign string two"
if [ "$LAST_EXIT" -ne 0 ] && echo "$LAST_OUTPUT" | grep -q "BKSDisplayBrightness"; then
  record_pass "Test 2 - BKSDisplayBrightness marker exits non-zero and is named"
else
  record_fail "Test 2 - BKSDisplayBrightness marker exits non-zero and is named (exit=$LAST_EXIT, output=$LAST_OUTPUT)"
fi

# Test 3: clean fixture exits zero
run_scan "hello world
com.apple.foo.bar
just a totally benign string"
if [ "$LAST_EXIT" -eq 0 ]; then
  record_pass "Test 3 - clean fixture exits zero"
else
  record_fail "Test 3 - clean fixture exits zero (exit=$LAST_EXIT, output=$LAST_OUTPUT)"
fi

# Test 4: survivor fixture (surviving private WebKit calls + notify keys) exits zero
run_scan "_simulateTextEntered
_hasSleepDisabler
com.apple.springboard.hasBlankedScreen
com.apple.springboard.lockstate"
if [ "$LAST_EXIT" -eq 0 ]; then
  record_pass "Test 4 - survivor-only fixture never trips the gate"
else
  record_fail "Test 4 - survivor-only fixture never trips the gate (exit=$LAST_EXIT, output=$LAST_OUTPUT)"
fi

# Test 5: entitlement key marker detected (binary regression is the point,
# even though plan 02-01 already emptied the entitlements file)
run_scan "benign string one
platform-application
benign string two"
if [ "$LAST_EXIT" -ne 0 ] && echo "$LAST_OUTPUT" | grep -q "platform-application"; then
  record_pass "Test 5 - platform-application entitlement marker exits non-zero and is named"
else
  record_fail "Test 5 - platform-application entitlement marker exits non-zero and is named (exit=$LAST_EXIT, output=$LAST_OUTPUT)"
fi

# Test 6: usage/error behavior on zero arguments and on a nonexistent path
ZERO_ARG_OUTPUT="$("$SCAN_SCRIPT" 2>&1)"
ZERO_ARG_EXIT=$?
NONEXISTENT_OUTPUT="$("$SCAN_SCRIPT" "$TMP_DIR/does-not-exist-binary" 2>&1)"
NONEXISTENT_EXIT=$?
if [ "$ZERO_ARG_EXIT" -ne 0 ] && echo "$ZERO_ARG_OUTPUT" | grep -q "Usage" \
   && [ "$NONEXISTENT_EXIT" -ne 0 ] && echo "$NONEXISTENT_OUTPUT" | grep -q "Usage"; then
  record_pass "Test 6 - zero args and nonexistent path both exit non-zero with usage message"
else
  record_fail "Test 6 - zero args and nonexistent path both exit non-zero with usage message (zero_exit=$ZERO_ARG_EXIT, nonexistent_exit=$NONEXISTENT_EXIT)"
fi

echo ""
echo "$PASS passed, $FAIL failed"

if [ "$FAIL" -ne 0 ]; then
  exit 1
fi

exit 0
