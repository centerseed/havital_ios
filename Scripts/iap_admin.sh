#!/usr/bin/env bash
# iap_admin.sh — IAP 訂閱狀態管理腳本（QA 測試用）
#
# 使用 gcloud auth 取得 identity token，透過 Admin API 管理測試帳號的訂閱狀態。
# 前提：已登入 gcloud（gcloud auth login）
#
# 用法：
#   ./Scripts/iap_admin.sh status              # 查詢當前訂閱狀態
#   ./Scripts/iap_admin.sh set-expired          # 設為已過期（觸發 403）
#   ./Scripts/iap_admin.sh set-subscribed       # 設為已訂閱（解除 403）
#   ./Scripts/iap_admin.sh set-trial            # 設為試用中（14 天）
#   ./Scripts/iap_admin.sh clear-override       # 清除 override，還原為自然狀態
#   ./Scripts/iap_admin.sh config               # 查詢全域 IAP 設定
#   ./Scripts/iap_admin.sh set-billing-issue    # 設 billing_issue=true（如果 API 支援）
#
# 環境變數（可選）：
#   IAP_TEST_UID    — 目標用戶 UID（預設：Demo User Cv5ADE73...）
#   IAP_API_BASE    — API base URL（預設：dev 環境）

set -euo pipefail

# --- 設定 ---
DEFAULT_UID="ZyIP5VxEapePp0P2erZx18WYGK92"
DEFAULT_API_BASE="https://api-service-yd7nv64yya-de.a.run.app"

TARGET_UID="${IAP_TEST_UID:-$DEFAULT_UID}"
API_BASE="${IAP_API_BASE:-$DEFAULT_API_BASE}"
ADMIN_PATH="api/v1/admin/subscription"

# --- Token ---
get_token() {
    local token
    token=$(gcloud auth print-identity-token 2>/dev/null) || {
        echo "❌ 無法取得 identity token。請先執行：gcloud auth login" >&2
        exit 1
    }
    echo "$token"
}

# --- API 呼叫 ---
api_get() {
    local path="$1"
    local token
    local response
    token=$(get_token)
    response=$(curl -sf -H "Authorization: Bearer $token" "${API_BASE}/${path}")
    print_response "$response"
}

api_post() {
    local path="$1"
    local body="$2"
    local token
    local response
    token=$(get_token)
    response=$(curl -sf -X POST \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d "$body" \
        "${API_BASE}/${path}")
    print_response "$response"
}

api_put() {
    local path="$1"
    local body="$2"
    local token
    local response
    token=$(get_token)
    response=$(curl -sf -X PUT \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d "$body" \
        "${API_BASE}/${path}")
    print_response "$response"
}

print_response() {
    local response="${1:-}"
    if [ -z "$response" ]; then
        echo "{}"
        return 0
    fi
    if echo "$response" | python3 -m json.tool >/dev/null 2>&1; then
        echo "$response" | python3 -m json.tool
    else
        echo "$response"
    fi
}

# --- 指令 ---
cmd_status() {
    echo "📋 查詢用戶訂閱狀態: ${TARGET_UID}"
    api_get "${ADMIN_PATH}/${TARGET_UID}"
}

cmd_config() {
    echo "⚙️  查詢全域 IAP 設定"
    api_get "${ADMIN_PATH}/config"
}

cmd_set_expired() {
    local expires_at
    expires_at=$(date -u -v-1d +"%Y-%m-%dT%H:%M:%SZ")
    echo "🔒 設定用戶為 expired: ${TARGET_UID} (expires_at: ${expires_at})"
    api_post "${ADMIN_PATH}/${TARGET_UID}/set-expires" \
        "{\"status\":\"expired\",\"expires_at\":\"$expires_at\",\"reason\":\"QA testing: force expired\"}"
}

cmd_set_subscribed() {
    local expires_at
    expires_at=$(date -u -v+30d +"%Y-%m-%dT%H:%M:%SZ")
    echo "🔓 設定用戶為 subscribed: ${TARGET_UID} (expires_at: ${expires_at})"
    api_post "${ADMIN_PATH}/${TARGET_UID}/set-expires" \
        "{\"status\":\"subscribed\",\"expires_at\":\"$expires_at\",\"reason\":\"QA testing: force subscribed\"}"
}

cmd_set_monthly() {
    local days="${2:-30}"
    local expires_at
    expires_at=$(date -u -v+"${days}"d +"%Y-%m-%dT%H:%M:%SZ")
    echo "🗓️ 設定用戶為 monthly: ${TARGET_UID} (+${days}d, expires_at: ${expires_at})"
    api_post "${ADMIN_PATH}/${TARGET_UID}/set-expires" \
        "{\"status\":\"subscribed\",\"plan_type\":\"monthly\",\"expires_at\":\"$expires_at\",\"reason\":\"QA testing: force monthly\"}"
}

cmd_set_yearly() {
    local days="${2:-365}"
    local expires_at
    expires_at=$(date -u -v+"${days}"d +"%Y-%m-%dT%H:%M:%SZ")
    echo "📅 設定用戶為 yearly: ${TARGET_UID} (+${days}d, expires_at: ${expires_at})"
    api_post "${ADMIN_PATH}/${TARGET_UID}/set-expires" \
        "{\"status\":\"subscribed\",\"plan_type\":\"yearly\",\"expires_at\":\"$expires_at\",\"reason\":\"QA testing: force yearly\"}"
}

cmd_set_cancelled() {
    local days="${2:-7}"
    local expires_at
    expires_at=$(date -u -v+"${days}"d +"%Y-%m-%dT%H:%M:%SZ")
    echo "⛔ 設定用戶為 cancelled(仍有效至到期): ${TARGET_UID} (+${days}d, expires_at: ${expires_at})"
    api_post "${ADMIN_PATH}/${TARGET_UID}/set-expires" \
        "{\"status\":\"cancelled\",\"plan_type\":\"monthly\",\"expires_at\":\"$expires_at\",\"reason\":\"QA testing: force cancelled\"}"
}

cmd_set_trial() {
    local expires_at
    expires_at=$(date -u -v+14d +"%Y-%m-%dT%H:%M:%SZ")
    echo "⏳ 設定用戶為 trial_active: ${TARGET_UID} (expires_at: ${expires_at})"
    api_post "${ADMIN_PATH}/${TARGET_UID}/set-expires" \
        "{\"status\":\"trial_active\",\"expires_at\":\"$expires_at\",\"reason\":\"QA testing: force trial\"}"
}

cmd_clear_override() {
    echo "🧹 清除 override: ${TARGET_UID}"
    api_post "${ADMIN_PATH}/${TARGET_UID}/override" \
        "{\"override\":false,\"reason\":\"QA testing: clear override\"}"
}

cmd_set_rizo_quota() {
    local used_count="${2:-200}"
    echo "🤖 設定 Rizo 用量: ${TARGET_UID} (used_count: ${used_count})"
    api_post "${ADMIN_PATH}/${TARGET_UID}/set-rizo-quota" \
        "{\"used_count\":${used_count},\"reason\":\"QA testing: set rizo quota\"}"
}

cmd_set_billing_issue() {
    local value="${2:-true}"
    echo "💳 設定 billing_issue: ${TARGET_UID} (${value})"
    api_post "${ADMIN_PATH}/${TARGET_UID}/set-billing-issue" \
        "{\"billing_issue\":${value},\"reason\":\"QA testing: set billing issue\"}"
}

# --- 主程式 ---
usage() {
    echo "用法：$0 <command> [args]"
    echo ""
    echo "Commands:"
    echo "  status              查詢用戶訂閱狀態"
    echo "  config              查詢全域 IAP 設定"
    echo "  set-expired         設為已過期（後端會回 403）"
    echo "  set-subscribed      設為已訂閱（功能解鎖）"
    echo "  set-monthly [days]  設為月訂（預設 +30 天）"
    echo "  set-yearly [days]   設為年訂（預設 +365 天）"
    echo "  set-cancelled [days]  設為已取消續訂但未到期（預設 +7 天）"
    echo "  set-trial           設為試用中（14 天）"
    echo "  clear-override      清除 override，還原自然狀態"
    echo "  set-rizo-quota [N]  設定 Rizo 用量（預設 200 = 耗盡，0 = 重置）"
    echo "  set-billing-issue [true|false]  設定帳單問題旗標"
    echo ""
    echo "環境變數："
    echo "  IAP_TEST_UID     目標 UID（預設：Demo User）"
    echo "  IAP_API_BASE     API URL（預設：$DEFAULT_API_BASE）"
}

case "${1:-}" in
    status)             cmd_status ;;
    config)             cmd_config ;;
    set-expired)        cmd_set_expired ;;
    set-subscribed)     cmd_set_subscribed ;;
    set-monthly)        cmd_set_monthly "$@" ;;
    set-yearly)         cmd_set_yearly "$@" ;;
    set-cancelled)      cmd_set_cancelled "$@" ;;
    set-trial)          cmd_set_trial ;;
    clear-override)     cmd_clear_override ;;
    set-rizo-quota)     cmd_set_rizo_quota "$@" ;;
    set-billing-issue)  cmd_set_billing_issue "$@" ;;
    -h|--help)          usage ;;
    *)                  usage; exit 1 ;;
esac
