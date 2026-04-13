#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
FLOWS_DIR="$PROJECT_ROOT/Havital/.maestro/flows"
CLEANUP_WRAPPER="$SCRIPT_DIR/run-maestro-with-artifact-cleanup.sh"
IAP_REGRESSION_WRAPPER="$SCRIPT_DIR/run-iap-regression.sh"
FAILED_FLOWS_FILE="${MAESTRO_FAILED_FLOWS_FILE:-$PROJECT_ROOT/Havital/.maestro/.last_failed_flows.txt}"
FAIL_FAST="${MAESTRO_FAIL_FAST:-0}"            # 1 = stop current category on first failure
ONLY_FAILED="${MAESTRO_ONLY_FAILED:-0}"        # 1 = run only items listed in FAILED_FLOWS_FILE

# Category prefixes (stable command surface)
# - CAT-IAP: IAP active regression set
# - CAT-ONB: Onboarding core/variant flows
# - CAT-BND: Boundary matrix flows
# - CAT-WKY: Weekly/overview/summary/preview flows
# - CAT-EDT: Edit schedule flows
# - CAT-REG: Regression single-item flows (non-suite)
# - CAT-SUITE: Regression suite bundles
# - CAT-UTL: Utility/reset/smoke helpers
# - CAT-DBG: Debug/tmp flows
# - CAT-ARC-IAP: Archived legacy IAP flows

CAT_IAP=(
  "iap-regression-active-unlocked.yaml"
  "iap-regression-expired-paywall.yaml"
  "iap-regression-console-states.yaml"
  "iap-regression-billing-banner.yaml"
  "iap-regression-state-switch-phase1.yaml"
  "iap-regression-state-switch-phase2.yaml"
  "iap-regression-rizo-quota.yaml"
  "iap-regression-reset-weekly-plan.yaml"
)

CAT_ONB=(
  "onboarding-beginner.yaml"
  "onboarding-fresh-beginner.yaml"
  "onboarding-fresh-maintenance.yaml"
  "onboarding-maintenance.yaml"
  "onboarding-race-hansons.yaml"
  "onboarding-race-marathon.yaml"
  "onboarding-race-norwegian.yaml"
  "onboarding-race-paceriz.yaml"
  "onboarding-race-polarized.yaml"
  "onboarding-race-start-from-base.yaml"
  "onboarding-race-start-from-build.yaml"
)

CAT_BND=(
  "boundary-beginner-24weeks-7days.yaml"
  "boundary-maintenance-4weeks-2days.yaml"
  "boundary-race-paceriz-2days.yaml"
  "boundary-race-paceriz-7days.yaml"
)

CAT_WKY=(
  "overview-weekly-consistency.yaml"
  "weekly-plan-delete-and-regenerate.yaml"
  "weekly-plan-display.yaml"
  "weekly-plan-quality-checks.yaml"
  "weekly-preview-qa.yaml"
  "qa_weekly_preview_manual.yaml"
  "weekly-summary-generate.yaml"
)

CAT_EDT=(
  "edit-schedule-full-test.yaml"
  "edit-schedule-modify-and-save.yaml"
  "edit-schedule-move-strength-day.yaml"
  "edit-schedule-preserve-data.yaml"
  "edit-schedule-running-gear.yaml"
  "edit-schedule-strength-editor.yaml"
  "edit-schedule-strength-save.yaml"
  "edit-schedule-supplementary-strength.yaml"
  "edit-schedule-swap-days.yaml"
)

CAT_REG=(
  "regression-i18n-english.yaml"
  "regression-i18n-japanese.yaml"
  "regression-settings-profile.yaml"
  "regression-target-crud.yaml"
  "regression-v2-weekly-flow.yaml"
)

CAT_SUITE=(
  "regression-beginner-5k-suite.yaml"
  "regression-full-suite.yaml"
  "regression-maintenance-speed-suite.yaml"
  "regression-maintenance-suite.yaml"
  "regression-race-hansons-suite.yaml"
  "regression-race-norwegian-suite.yaml"
  "regression-race-paceriz-suite.yaml"
  "regression-race-polarized-suite.yaml"
)

CAT_UTL=(
  "demo-login-only.yaml"
  "demo-login.yaml"
  "reset-goal.yaml"
  "restart-app.yaml"
  "screenshot-sheet.yaml"
)

CAT_DBG=(
  "_debug-assert.yaml"
  "_debug-iap-nav.yaml"
  "_debug-id-assert.yaml"
  "_debug-id-text.yaml"
  "_debug-labeled-content.yaml"
  "tmp-ensure-goal-type.yaml"
  "tmp-smoke-race-paceriz-with-login.yaml"
)

CAT_ARC_IAP=(
  "archive/iap-console-expired-smoke.yaml"
  "archive/iap-console-scenarios-2-4.yaml"
  "archive/iap-console-scenarios-3-4.yaml"
  "archive/iap-e1-c3-test.yaml"
  "archive/iap-e3-instant-switch.yaml"
  "archive/iap-full-test.yaml"
  "archive/iap-paywall-test.yaml"
  "archive/iap-trigger-403.yaml"
  "archive/qa-iap-b1-full.yaml"
  "archive/qa-iap-b1-generate-plan.yaml"
  "archive/qa-iap-b1-trigger-paywall.yaml"
  "archive/qa-iap-b1-via-debug-menu.yaml"
  "archive/qa-iap-c1-delete-week.yaml"
  "archive/qa-iap-c1-full.yaml"
  "archive/qa-iap-c1-trigger-403.yaml"
  "archive/qa-iap-debug-delete-plan.yaml"
  "archive/qa-iap-e3-retry.yaml"
  "archive/qa-iap-generate-and-verify-paywall.yaml"
  "archive/qa-iap-login-only.yaml"
  "archive/qa-iap-navigate-debug.yaml"
  "archive/qa-iap-paywall-b1b2b4b5.yaml"
)

print_usage() {
  cat <<'EOF'
Usage:
  .maestro/scripts/run-maestro-categories.sh list
  .maestro/scripts/run-maestro-categories.sh <CATEGORY_PREFIX>
  .maestro/scripts/run-maestro-categories.sh FULL-REGRESSION
  .maestro/scripts/run-maestro-categories.sh RETRY-FAILED

Category Prefixes:
  CAT-IAP
  CAT-ONB
  CAT-BND
  CAT-WKY
  CAT-EDT
  CAT-REG
  CAT-SUITE
  CAT-UTL
  CAT-DBG
  CAT-ARC-IAP
  FULL-REGRESSION
  RETRY-FAILED

Notes:
  - FULL-REGRESSION = CAT-IAP + CAT-ONB + CAT-BND + CAT-WKY + CAT-EDT + CAT-REG
  - RETRY-FAILED = rerun only flows that failed in previous run (stored in .last_failed_flows.txt)
  - CAT-IAP is orchestrated via run-iap-regression.sh all (with backend preconditions)
  - Each non-IAP flow is executed through run-maestro-with-artifact-cleanup.sh
  - Env speed knobs:
      MAESTRO_FAIL_FAST=1   # stop category immediately on first fail
      MAESTRO_ONLY_FAILED=1 # for category commands, run only failures from last run
  - Optional pre-flow by category:
      MAESTRO_PREP_ONB / MAESTRO_PREP_ONB_MODE
      MAESTRO_PREP_BND / MAESTRO_PREP_BND_MODE
      MAESTRO_PREP_WKY / MAESTRO_PREP_WKY_MODE
      MAESTRO_PREP_EDT / MAESTRO_PREP_EDT_MODE
      MAESTRO_PREP_REG / MAESTRO_PREP_REG_MODE
    where MODE is one of: none, once, each
EOF
}

show_list() {
  cat <<'EOF'
CATEGORY PREFIX MAP
  CAT-IAP      In-app purchase active regression
  CAT-ONB      Onboarding flows
  CAT-BND      Boundary matrix flows
  CAT-WKY      Weekly/overview/summary/preview flows
  CAT-EDT      Edit schedule flows
  CAT-REG      Regression single-item flows
  CAT-SUITE    Regression bundle suites
  CAT-UTL      Utility/reset/smoke flows
  CAT-DBG      Debug/tmp flows
  CAT-ARC-IAP  Archived legacy IAP flows
  FULL-REGRESSION  All active categories (excluding suite/debug/archive/utility)
  RETRY-FAILED     Only flows failed in previous run
EOF
}

flow_in_failed_cache() {
  local category="$1"
  local rel="$2"
  [ -f "$FAILED_FLOWS_FILE" ] || return 1
  rg -Fxq "${category}|${rel}" "$FAILED_FLOWS_FILE"
}

run_flow_list() {
  local category="$1"
  local pre_flow="${2:-}"
  local pre_mode="${3:-none}" # none|once|each
  shift 3
  local flows=("$@")
  local pass=0
  local fail=0

  echo "[CATEGORY] $category (${#flows[@]} flows)"

  if [ -n "$pre_flow" ] && [ "$pre_mode" = "once" ]; then
    local pre_abs="$FLOWS_DIR/$pre_flow"
    if [ ! -f "$pre_abs" ]; then
      echo "[FAIL] Missing pre-flow: $pre_flow"
      echo "[SUMMARY][$category] PASS=0 FAIL=${#flows[@]}"
      return 1
    fi
    echo "[PRE ] $pre_flow (once)"
    if ! "$CLEANUP_WRAPPER" test "$pre_abs"; then
      echo "[FAIL] pre-flow failed: $pre_flow"
      echo "[SUMMARY][$category] PASS=0 FAIL=${#flows[@]}"
      return 1
    fi
  fi

  for rel in "${flows[@]}"; do
    if [ "$ONLY_FAILED" = "1" ] && ! flow_in_failed_cache "$category" "$rel"; then
      echo "[SKIP] $rel (not in failed cache)"
      continue
    fi

    local abs="$FLOWS_DIR/$rel"
    if [ ! -f "$abs" ]; then
      echo "[FAIL] Missing flow: $rel"
      fail=$((fail + 1))
      echo "${category}|${rel}" >> "$FAILED_FLOWS_FILE"
      if [ "$FAIL_FAST" = "1" ]; then
        break
      fi
      continue
    fi

    if [ -n "$pre_flow" ] && [ "$pre_mode" = "each" ]; then
      local pre_abs="$FLOWS_DIR/$pre_flow"
      if [ ! -f "$pre_abs" ]; then
        echo "[FAIL] Missing pre-flow: $pre_flow"
        fail=$((fail + 1))
        continue
      fi
      echo "[PRE ] $pre_flow (before $rel)"
      if ! "$CLEANUP_WRAPPER" test "$pre_abs"; then
        echo "[FAIL] pre-flow failed before: $rel"
        fail=$((fail + 1))
        echo "${category}|${rel}" >> "$FAILED_FLOWS_FILE"
        if [ "$FAIL_FAST" = "1" ]; then
          break
        fi
        continue
      fi
    fi

    echo "[RUN ] $rel"
    if "$CLEANUP_WRAPPER" test "$abs"; then
      echo "[PASS] $rel"
      pass=$((pass + 1))
    else
      echo "[FAIL] $rel"
      fail=$((fail + 1))
      echo "${category}|${rel}" >> "$FAILED_FLOWS_FILE"
      if [ "$FAIL_FAST" = "1" ]; then
        break
      fi
    fi
  done

  echo "[SUMMARY][$category] PASS=$pass FAIL=$fail"
  [ "$fail" -eq 0 ]
}

main() {
  local target="${1:-}"
  local rc=0
  local prep_onb="${MAESTRO_PREP_ONB:-}"
  local prep_onb_mode="${MAESTRO_PREP_ONB_MODE:-none}"
  local prep_bnd="${MAESTRO_PREP_BND:-}"
  local prep_bnd_mode="${MAESTRO_PREP_BND_MODE:-none}"
  local prep_wky="${MAESTRO_PREP_WKY:-}"
  local prep_wky_mode="${MAESTRO_PREP_WKY_MODE:-none}"
  local prep_edt="${MAESTRO_PREP_EDT:-}"
  local prep_edt_mode="${MAESTRO_PREP_EDT_MODE:-none}"
  local prep_reg="${MAESTRO_PREP_REG:-}"
  local prep_reg_mode="${MAESTRO_PREP_REG_MODE:-none}"

  case "$target" in
    list)
      show_list
      ;;
    CAT-IAP)
      echo "[CATEGORY] CAT-IAP (orchestrated via run-iap-regression.sh all)"
      "$IAP_REGRESSION_WRAPPER" all
      ;;
    CAT-ONB)
      run_flow_list "CAT-ONB" "$prep_onb" "$prep_onb_mode" "${CAT_ONB[@]}"
      ;;
    CAT-BND)
      run_flow_list "CAT-BND" "$prep_bnd" "$prep_bnd_mode" "${CAT_BND[@]}"
      ;;
    CAT-WKY)
      run_flow_list "CAT-WKY" "$prep_wky" "$prep_wky_mode" "${CAT_WKY[@]}"
      ;;
    CAT-EDT)
      run_flow_list "CAT-EDT" "$prep_edt" "$prep_edt_mode" "${CAT_EDT[@]}"
      ;;
    CAT-REG)
      run_flow_list "CAT-REG" "$prep_reg" "$prep_reg_mode" "${CAT_REG[@]}"
      ;;
    CAT-SUITE)
      run_flow_list "CAT-SUITE" "" "none" "${CAT_SUITE[@]}"
      ;;
    CAT-UTL)
      run_flow_list "CAT-UTL" "" "none" "${CAT_UTL[@]}"
      ;;
    CAT-DBG)
      run_flow_list "CAT-DBG" "" "none" "${CAT_DBG[@]}"
      ;;
    CAT-ARC-IAP)
      run_flow_list "CAT-ARC-IAP" "" "none" "${CAT_ARC_IAP[@]}"
      ;;
    RETRY-FAILED|retry-failed)
      if [ ! -f "$FAILED_FLOWS_FILE" ] || [ ! -s "$FAILED_FLOWS_FILE" ]; then
        echo "[INFO] No failed cache found: $FAILED_FLOWS_FILE"
        return 0
      fi
      ONLY_FAILED=1
      run_flow_list "CAT-ONB" "$prep_onb" "$prep_onb_mode" "${CAT_ONB[@]}" || rc=1
      run_flow_list "CAT-BND" "$prep_bnd" "$prep_bnd_mode" "${CAT_BND[@]}" || rc=1
      run_flow_list "CAT-WKY" "$prep_wky" "$prep_wky_mode" "${CAT_WKY[@]}" || rc=1
      run_flow_list "CAT-EDT" "$prep_edt" "$prep_edt_mode" "${CAT_EDT[@]}" || rc=1
      run_flow_list "CAT-REG" "$prep_reg" "$prep_reg_mode" "${CAT_REG[@]}" || rc=1
      return "$rc"
      ;;
    FULL-REGRESSION|full-regression)
      : > "$FAILED_FLOWS_FILE"
      echo "[CATEGORY] CAT-IAP (orchestrated via run-iap-regression.sh all)"
      "$IAP_REGRESSION_WRAPPER" all || rc=1
      run_flow_list "CAT-ONB" "$prep_onb" "$prep_onb_mode" "${CAT_ONB[@]}" || rc=1
      run_flow_list "CAT-BND" "$prep_bnd" "$prep_bnd_mode" "${CAT_BND[@]}" || rc=1
      run_flow_list "CAT-WKY" "$prep_wky" "$prep_wky_mode" "${CAT_WKY[@]}" || rc=1
      run_flow_list "CAT-EDT" "$prep_edt" "$prep_edt_mode" "${CAT_EDT[@]}" || rc=1
      run_flow_list "CAT-REG" "$prep_reg" "$prep_reg_mode" "${CAT_REG[@]}" || rc=1
      return "$rc"
      ;;
    *)
      print_usage
      exit 1
      ;;
  esac
}

main "${1:-}"
