#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_SCRIPT="$PROJECT_ROOT/Scripts/test.sh"
AUTH_TEST="$PROJECT_ROOT/HavitalTests/Features/Authentication/Integration/AuthenticationIntegrationTests.swift"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_not_contains() {
    local file="$1"
    local needle="$2"
    if grep -Fq "$needle" "$file"; then
        fail "$file must not contain $needle"
    fi
}

# This is a source contract only: the old teardown is intentionally never executed.
assert_not_contains "$AUTH_TEST" "FirebaseAuthDataSource()"
assert_not_contains "$AUTH_TEST" "UserDefaults.standard"
grep -Fq "IsolatedAuthRepository" "$AUTH_TEST" || fail "authentication integration tests must use an injected auth double"
grep -Fq "UserDefaults(suiteName:" "$AUTH_TEST" || fail "authentication integration tests must use a per-test defaults suite"

temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/havital-test-contract.XXXXXX")"
trap 'rm -rf "$temp_dir"' EXIT
mkdir -p "$temp_dir/bin"

cat > "$temp_dir/bin/xcrun" <<'EOF'
#!/bin/sh
case "$*" in
    "simctl list devices available"|"simctl list devices")
        echo "    iPhone 17 Pro (AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE) (Shutdown)"
        ;;
    "simctl list devicetypes"|"simctl list runtimes")
        ;;
    "simctl boot AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")
        ;;
    *)
        exit 1
        ;;
esac
EOF
cat > "$temp_dir/bin/sleep" <<'EOF'
#!/bin/sh
exit 0
EOF
cat > "$temp_dir/bin/xcodebuild" <<'EOF'
#!/bin/sh
exit 99
EOF
chmod +x "$temp_dir/bin/xcrun" "$temp_dir/bin/sleep" "$temp_dir/bin/xcodebuild"

set +e
output=$(PATH="$temp_dir/bin:$PATH" PACERIZ_TEST_SIMULATOR="Missing Paceriz Tests" "$TEST_SCRIPT" unit 2>&1)
status=$?
set -e

[ "$status" -ne 0 ] || fail "missing dedicated simulator must fail"
if grep -Fq "改用既有模擬器" <<<"$output"; then
    fail "missing dedicated simulator must not fall back to an existing iPhone"
fi
grep -Fq "No dedicated simulator named" <<<"$output" || fail "failure must identify the missing dedicated simulator"

echo "PASS: iOS test runner and authentication isolation contracts"
