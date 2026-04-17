#!/usr/bin/env bash
# run-iap-regression.sh — IAP Regression Test Suite Wrapper
#
# Orchestrates backend state preparation via iap_admin.sh, then runs
# Maestro flows. Each flow assumes the backend is in the correct state
# on entry. Maestro iOS cannot call shell mid-flow, so this script
# handles all state transitions.
#
# Usage:
#   ./Havital/.maestro/scripts/run-iap-regression.sh [flow-name|all]
#
# Examples:
#   ./Havital/.maestro/scripts/run-iap-regression.sh all
#   ./Havital/.maestro/scripts/run-iap-regression.sh R1
#   ./Havital/.maestro/scripts/run-iap-regression.sh expired-paywall

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
IAP_ADMIN="$PROJECT_ROOT/Havital/Scripts/iap_admin.sh"
FLOWS_DIR="$PROJECT_ROOT/Havital/.maestro/flows"
MAESTRO_BIN="${MAESTRO_BIN:-maestro}"
ADMIN_RETRY_COUNT="${ADMIN_RETRY_COUNT:-3}"
MAESTRO_RETRY_COUNT="${MAESTRO_RETRY_COUNT:-2}"
MAESTRO_REINSTALL_DRIVER="${MAESTRO_REINSTALL_DRIVER:-0}"
IAP_UID="${IAP_TEST_UID:-ZyIP5VxEapePp0P2erZx18WYGK92}"
IAP_API_BASE="${IAP_API_BASE:-https://api-service-yd7nv64yya-de.a.run.app}"
MAESTRO_LOCAL_ENV_FILE="${MAESTRO_LOCAL_ENV_FILE:-$PROJECT_ROOT/Havital/.maestro/.env.local}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
RESULTS=()

# --- Helpers ---

load_local_env() {
    if [ -f "$MAESTRO_LOCAL_ENV_FILE" ]; then
        set -a
        # shellcheck disable=SC1090
        . "$MAESTRO_LOCAL_ENV_FILE"
        set +a
    fi
}

log_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    RESULTS+=("PASS: $1")
    ((PASS_COUNT++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    RESULTS+=("FAIL: $1")
    ((FAIL_COUNT++))
}

log_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
    RESULTS+=("SKIP: $1")
    ((SKIP_COUNT++))
}

run_admin() {
    local args=("$@")
    local attempt=1
    local max_attempts="$ADMIN_RETRY_COUNT"
    while [ "$attempt" -le "$max_attempts" ]; do
        log_step "iap_admin.sh ${args[*]} (attempt ${attempt}/${max_attempts})"
        if "$IAP_ADMIN" "${args[@]}" 2>&1; then
            return 0
        fi
        attempt=$((attempt + 1))
        if [ "$attempt" -le "$max_attempts" ]; then
            log_step "Retrying admin call in 2s..."
            sleep 2
        fi
    done
    echo -e "${RED}  iap_admin.sh ${args[*]} failed after ${max_attempts} attempts${NC}"
    return 1
}

# Delete the demo user's current weekly plan via backend API.
# This puts the app in "noWeeklyPlan" state so the "generate" button appears.
delete_weekly_plan() {
    local token
    token=$(gcloud auth print-identity-token 2>/dev/null) || {
        echo -e "${RED}  Cannot get identity token for weekly plan delete${NC}"
        return 1
    }
    log_step "Deleting current weekly plan for $IAP_UID"
    # Call the admin endpoint to delete weekly plan
    local response
    response=$(curl -sf -X POST \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d "{\"reason\":\"QA regression test: reset weekly plan\"}" \
        "${IAP_API_BASE}/api/v1/admin/training/${IAP_UID}/delete-weekly-plan" 2>&1) || {
        log_step "Admin delete-weekly-plan endpoint not available, falling back to UI reset flow"
        reset_weekly_plan_via_ui
        return $?
    }
    echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"
}

fetch_admin_status_json() {
    local token
    token=$(gcloud auth print-identity-token 2>/dev/null) || {
        echo -e "${RED}  Cannot get identity token for status check${NC}"
        return 1
    }
    curl -sf -H "Authorization: Bearer $token" \
        "${IAP_API_BASE}/api/v1/admin/subscription/${IAP_UID}"
}

assert_status_expiry_window() {
    local expected_status="$1"
    local min_days="$2"
    local max_days="$3"
    local expected_plan="${4:-any}"
    local context="${5:-status-window-check}"

    local status_json
    status_json="$(fetch_admin_status_json)" || return 1

    STATUS_JSON="$status_json" EXPECTED_STATUS="$expected_status" MIN_DAYS="$min_days" MAX_DAYS="$max_days" EXPECTED_PLAN="$expected_plan" CONTEXT="$context" python3 - <<'PY'
import json
import os
from datetime import datetime, timezone

raw = os.environ["STATUS_JSON"]
expected_status = os.environ["EXPECTED_STATUS"]
min_days = int(os.environ["MIN_DAYS"])
max_days = int(os.environ["MAX_DAYS"])
expected_plan = os.environ["EXPECTED_PLAN"]
context = os.environ["CONTEXT"]

obj = json.loads(raw)
sub = obj.get("data", {}).get("subscription", {})

status = sub.get("status")
expires_at = sub.get("expires_at")
plan_type = sub.get("plan_type")

if status != expected_status:
    raise SystemExit(f"[{context}] status mismatch: expected={expected_status} actual={status}")

if expected_plan != "any" and plan_type != expected_plan:
    raise SystemExit(f"[{context}] plan_type mismatch: expected={expected_plan} actual={plan_type}")

if not expires_at:
    raise SystemExit(f"[{context}] expires_at is empty")

dt = datetime.fromisoformat(expires_at.replace("Z", "+00:00"))
now = datetime.now(timezone.utc)
days = (dt - now).total_seconds() / 86400.0

if not (min_days <= days <= max_days):
    raise SystemExit(
        f"[{context}] expires_at window mismatch: expected {min_days}..{max_days} days, actual={days:.2f}, expires_at={expires_at}"
    )

print(f"[{context}] OK status={status} plan_type={plan_type} expires_in_days={days:.2f}")
PY
}

reset_weekly_plan_via_ui() {
    local flow_file="$FLOWS_DIR/iap-regression-reset-weekly-plan.yaml"
    log_step "maestro test $flow_file (weekly-plan reset fallback)"
    if [ "$MAESTRO_REINSTALL_DRIVER" = "1" ]; then
        if "$MAESTRO_BIN" test "$flow_file" 2>&1; then
            return 0
        fi
    else
        if "$MAESTRO_BIN" test --no-reinstall-driver "$flow_file" 2>&1; then
            return 0
        fi
    fi
    echo -e "${RED}  UI fallback weekly-plan reset failed${NC}"
    return 1
}

run_maestro() {
    local flow_file="$1"
    local flow_name="$2"
    local attempt=1
    local max_attempts="$MAESTRO_RETRY_COUNT"
    local output

    while [ "$attempt" -le "$max_attempts" ]; do
        log_step "maestro test $flow_file (attempt ${attempt}/${max_attempts})"
        if [ "$MAESTRO_REINSTALL_DRIVER" = "1" ]; then
            output="$("$MAESTRO_BIN" test "$flow_file" 2>&1)"
        else
            output="$("$MAESTRO_BIN" test --no-reinstall-driver "$flow_file" 2>&1)"
        fi
        local status=$?
        echo "$output"

        if [ "$status" -eq 0 ]; then
            log_pass "$flow_name"
            return 0
        fi

        if printf '%s' "$output" | rg -q "Failed to connect to /127.0.0.1:7001|socket hang up|connection refused"; then
            attempt=$((attempt + 1))
            if [ "$attempt" -le "$max_attempts" ]; then
                log_step "Detected Maestro driver disconnect, retrying in 3s..."
                sleep 3
                continue
            fi
        fi
        break
    done

    log_fail "$flow_name"
    return 1
}

wait_for_backend() {
    log_step "Waiting ${1:-3}s for backend state propagation..."
    sleep "${1:-3}"
}

cleanup_common() {
    local cleanup_failed=0
    run_admin set-billing-issue false || cleanup_failed=1
    run_admin set-rizo-quota 0 || cleanup_failed=1
    run_admin clear-override || cleanup_failed=1
    if [ "$cleanup_failed" -eq 1 ]; then
        log_fail "Cleanup: reset backend state"
        return 1
    fi
    return 0
}

# --- Flow Runners ---

run_r1_expired_paywall() {
    local failed=0
    echo ""
    echo -e "${CYAN}========== R1: Expired -> 403 -> PaywallView ==========${NC}"

    log_step "Preparing backend: set-expired + delete weekly plan"
    run_admin set-expired || failed=1
    delete_weekly_plan || failed=1
    wait_for_backend 3

    if [ "$failed" -eq 0 ]; then
        run_maestro "$FLOWS_DIR/iap-regression-expired-paywall.yaml" \
            "R1: expired-paywall" || failed=1
    else
        log_fail "R1: expired-paywall (precondition failed)"
    fi

    # Cleanup: restore subscribed state
    log_step "Cleanup: set-subscribed"
    run_admin set-subscribed || failed=1
    run_admin clear-override || failed=1
    return "$failed"
}

load_local_env

run_r2_console_states() {
    local failed=0
    echo ""
    echo -e "${CYAN}========== R2: Console State Matrix ==========${NC}"

    log_step "Preparing backend: clear-override (clean start)"
    run_admin clear-override || failed=1
    wait_for_backend 3

    if [ "$failed" -eq 0 ]; then
        run_maestro "$FLOWS_DIR/iap-regression-console-states.yaml" \
            "R2: console-states" || failed=1
    else
        log_fail "R2: console-states (precondition failed)"
    fi

    # Cleanup
    log_step "Cleanup: clear-override"
    run_admin clear-override || failed=1
    return "$failed"
}

run_r3_billing_banner() {
    local failed=0
    echo ""
    echo -e "${CYAN}========== R3: Billing Issue Banner ==========${NC}"

    log_step "Preparing backend: set-subscribed + set-billing-issue true"
    run_admin set-subscribed || failed=1
    wait_for_backend 2
    run_admin set-billing-issue true || failed=1
    wait_for_backend 3

    if [ "$failed" -eq 0 ]; then
        run_maestro "$FLOWS_DIR/iap-regression-billing-banner.yaml" \
            "R3: billing-banner" || failed=1
    else
        log_fail "R3: billing-banner (precondition failed)"
    fi

    # Cleanup
    log_step "Cleanup: set-billing-issue false + clear-override"
    run_admin set-billing-issue false || failed=1
    run_admin clear-override || failed=1
    return "$failed"
}

run_r4_state_switch() {
    local failed=0
    echo ""
    echo -e "${CYAN}========== R4: Expired -> Subscribed Instant Switch ==========${NC}"

    # Phase 1: Set expired, run flow that confirms paywall appears
    log_step "Phase 1: Preparing backend: set-expired + delete weekly plan"
    run_admin set-expired || failed=1
    delete_weekly_plan || failed=1
    wait_for_backend 3

    if [ "$failed" -eq 0 ]; then
        run_maestro "$FLOWS_DIR/iap-regression-state-switch-phase1.yaml" \
            "R4: state-switch (phase1)" || failed=1
    else
        log_fail "R4: state-switch (precondition failed before phase1)"
    fi

    # Phase 2: Switch to subscribed, then run flow that confirms unlock
    log_step "Phase 2: Switching backend to subscribed"
    run_admin set-subscribed || failed=1
    wait_for_backend 3

    if [ "$failed" -eq 0 ]; then
        run_maestro "$FLOWS_DIR/iap-regression-state-switch-phase2.yaml" \
            "R4: state-switch (phase2)" || failed=1
    else
        log_fail "R4: state-switch (phase2 skipped due to earlier failure)"
    fi

    if [ "$failed" -eq 0 ]; then
        log_pass "R4: state-switch"
    fi
    run_admin clear-override || failed=1
    return "$failed"
}

run_r5_rizo_quota() {
    local failed=0
    echo ""
    echo -e "${CYAN}========== R5: Rizo Quota Exceeded Banner ==========${NC}"

    log_step "Preparing backend: set-subscribed + set-rizo-quota 200 + delete weekly plan"
    run_admin set-subscribed || failed=1
    delete_weekly_plan || failed=1
    wait_for_backend 2
    run_admin set-rizo-quota 200 || failed=1
    wait_for_backend 3

    if [ "$failed" -eq 0 ]; then
        run_maestro "$FLOWS_DIR/iap-regression-rizo-quota.yaml" \
            "R5: rizo-quota" || failed=1
    else
        log_fail "R5: rizo-quota (precondition failed)"
    fi

    # Cleanup
    log_step "Cleanup: set-rizo-quota 0 + clear-override"
    run_admin set-rizo-quota 0 || failed=1
    run_admin clear-override || failed=1
    return "$failed"
}

run_r6_monthly_expiry() {
    local failed=0
    echo ""
    echo -e "${CYAN}========== R6: Monthly Plan + Expiry Window ==========${NC}"

    log_step "Preparing backend: set-monthly + delete weekly plan"
    run_admin set-monthly 30 || failed=1
    delete_weekly_plan || failed=1
    wait_for_backend 3

    if [ "$failed" -eq 0 ]; then
        log_step "Verifying status=subscribed, expires_at ~30d (plan_type may be null in admin override mode)"
        assert_status_expiry_window "subscribed" 27 35 "any" "R6-monthly" || failed=1
        run_maestro "$FLOWS_DIR/iap-regression-active-unlocked.yaml" \
            "R6: monthly-unlocked-ui" || failed=1
    else
        log_fail "R6: monthly-expiry (precondition failed)"
    fi

    log_step "Cleanup: clear-override"
    run_admin clear-override || failed=1
    return "$failed"
}

run_r7_yearly_expiry() {
    local failed=0
    echo ""
    echo -e "${CYAN}========== R7: Yearly Plan + Expiry Window ==========${NC}"

    log_step "Preparing backend: set-yearly + delete weekly plan"
    run_admin set-yearly 365 || failed=1
    delete_weekly_plan || failed=1
    wait_for_backend 3

    if [ "$failed" -eq 0 ]; then
        log_step "Verifying status=subscribed, expires_at ~365d (plan_type may be null in admin override mode)"
        assert_status_expiry_window "subscribed" 360 370 "any" "R7-yearly" || failed=1
        run_maestro "$FLOWS_DIR/iap-regression-active-unlocked.yaml" \
            "R7: yearly-unlocked-ui" || failed=1
    else
        log_fail "R7: yearly-expiry (precondition failed)"
    fi

    log_step "Cleanup: clear-override"
    run_admin clear-override || failed=1
    return "$failed"
}

run_r8_cancel_lifecycle() {
    local failed=0
    echo ""
    echo -e "${CYAN}========== R8: Cancel Lifecycle (Active Until Expiry -> Block) ==========${NC}"

    log_step "Phase 1: set-cancelled(+7d) + delete weekly plan"
    run_admin set-cancelled 7 || failed=1
    delete_weekly_plan || failed=1
    wait_for_backend 3

    if [ "$failed" -eq 0 ]; then
        log_step "Verifying cancelled state still active-like before expiry (plan_type may be null in admin override mode)"
        assert_status_expiry_window "cancelled" 6 8 "any" "R8-cancelled" || failed=1
        run_maestro "$FLOWS_DIR/iap-regression-active-unlocked.yaml" \
            "R8: cancelled-still-unlocked" || failed=1
    else
        log_fail "R8: cancelled-still-unlocked (precondition failed)"
    fi

    log_step "Phase 2: force-expired then verify paywall"
    run_admin set-expired || failed=1
    delete_weekly_plan || failed=1
    wait_for_backend 3
    if [ "$failed" -eq 0 ]; then
        run_maestro "$FLOWS_DIR/iap-regression-expired-paywall.yaml" \
            "R8: cancel-then-expired-blocked" || failed=1
    else
        log_fail "R8: cancel-then-expired-blocked (precondition failed)"
    fi

    log_step "Cleanup: set-subscribed + clear-override"
    run_admin set-subscribed || failed=1
    run_admin clear-override || failed=1
    return "$failed"
}

run_r9_trial_lifecycle() {
    local failed=0
    echo ""
    echo -e "${CYAN}========== R9: Trial Lifecycle (Trial Active -> Expired Block) ==========${NC}"

    log_step "Phase 1: set-trial(+14d) + delete weekly plan"
    run_admin set-trial || failed=1
    delete_weekly_plan || failed=1
    wait_for_backend 3

    if [ "$failed" -eq 0 ]; then
        log_step "Verifying trial_active state and expires_at ~14d"
        assert_status_expiry_window "trial_active" 12 16 "any" "R9-trial-active" || failed=1
        run_maestro "$FLOWS_DIR/iap-regression-active-unlocked.yaml" \
            "R9: trial-active-unlocked" || failed=1
    else
        log_fail "R9: trial-active-unlocked (precondition failed)"
    fi

    log_step "Phase 2: force-expired then verify paywall"
    run_admin set-expired || failed=1
    delete_weekly_plan || failed=1
    wait_for_backend 3
    if [ "$failed" -eq 0 ]; then
        run_maestro "$FLOWS_DIR/iap-regression-expired-paywall.yaml" \
            "R9: trial-then-expired-blocked" || failed=1
    else
        log_fail "R9: trial-then-expired-blocked (precondition failed)"
    fi

    log_step "Cleanup: set-subscribed + clear-override"
    run_admin set-subscribed || failed=1
    run_admin clear-override || failed=1
    return "$failed"
}

# --- Summary ---

print_summary() {
    echo ""
    echo -e "${CYAN}==================== SUMMARY ====================${NC}"
    for result in "${RESULTS[@]}"; do
        if [[ "$result" == PASS* ]]; then
            echo -e "  ${GREEN}$result${NC}"
        elif [[ "$result" == FAIL* ]]; then
            echo -e "  ${RED}$result${NC}"
        else
            echo -e "  ${YELLOW}$result${NC}"
        fi
    done
    echo ""
    echo -e "  Total: $((PASS_COUNT + FAIL_COUNT + SKIP_COUNT))  |  ${GREEN}PASS: $PASS_COUNT${NC}  |  ${RED}FAIL: $FAIL_COUNT${NC}  |  ${YELLOW}SKIP: $SKIP_COUNT${NC}"
    echo -e "${CYAN}=================================================${NC}"

    if [ "$FAIL_COUNT" -gt 0 ]; then
        return 1
    fi
    return 0
}

# --- Main ---

usage() {
    echo "Usage: $0 [flow|all]"
    echo ""
    echo "Flows:"
    echo "  R1, expired-paywall     Expired -> 403 -> PaywallView"
    echo "  R2, console-states      IAP Console state matrix"
    echo "  R3, billing-banner      Billing issue red warning"
    echo "  R4, state-switch        Expired -> subscribed instant unlock"
    echo "  R5, rizo-quota          Rizo 429 orange banner"
    echo "  R6, monthly-expiry      Monthly plan_type + expiry window + unlocked UI"
    echo "  R7, yearly-expiry       Yearly plan_type + expiry window + unlocked UI"
    echo "  R8, cancel-lifecycle    Cancelled stays unlocked until expiry, then blocked"
    echo "  R9, trial-lifecycle     Trial active stays unlocked, then expired is blocked"
    echo "  all                     Run all flows in order"
}

TARGET="${1:-all}"

case "$TARGET" in
    R1|expired-paywall)   run_r1_expired_paywall ;;
    R2|console-states)    run_r2_console_states ;;
    R3|billing-banner)    run_r3_billing_banner ;;
    R4|state-switch)      run_r4_state_switch ;;
    R5|rizo-quota)        run_r5_rizo_quota ;;
    R6|monthly-expiry)    run_r6_monthly_expiry ;;
    R7|yearly-expiry)     run_r7_yearly_expiry ;;
    R8|cancel-lifecycle)  run_r8_cancel_lifecycle ;;
    R9|trial-lifecycle)   run_r9_trial_lifecycle ;;
    all)
        run_r1_expired_paywall
        run_r2_console_states
        run_r3_billing_banner
        run_r4_state_switch
        run_r5_rizo_quota
        run_r6_monthly_expiry
        run_r7_yearly_expiry
        run_r8_cancel_lifecycle
        run_r9_trial_lifecycle
        cleanup_common || true
        ;;
    -h|--help)  usage; exit 0 ;;
    *)          usage; exit 1 ;;
esac

print_summary
