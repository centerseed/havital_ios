#!/bin/bash

# ==============================================================================
# Training Plan Loading Flow Tests
#
# 專門測試 ARCH-006 文件中描述的所有載入流程場景
#
# Usage:
#   ./Scripts/test_training_plan_flow.sh           # 執行所有載入流程測試
#   ./Scripts/test_training_plan_flow.sh --quick   # 只執行關鍵修復測試
#   ./Scripts/test_training_plan_flow.sh --verbose # 詳細輸出
#
# 測試覆蓋：
#   1. App 啟動情境（5 種 nextAction 狀態）
#   2. App 背景恢復（跨週/未跨週）
#   3. 週數切換
#   4. 產生下週課表（關鍵修復驗證）
#   5. 事件驅動更新
#   6. 錯誤處理
#   7. 狀態一致性
# ==============================================================================

set -e

# Default configurations
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"
XC_BUILD_WRAPPER="$SCRIPT_DIR/run_xcodebuild.sh"

SCHEME="Havital"
PROJECT="Havital.xcodeproj"
TEST_TARGET="HavitalTests"
TEST_CLASS="TrainingPlanLoadingFlowTests"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ================================
# Helper Functions
# ================================

print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_scenario() {
    echo -e "${CYAN}📋 $1${NC}"
}

detect_simulator() {
    local sim_name=$(xcrun simctl list devices available | grep "iPhone 17" | head -1 | sed 's/^[[:space:]]*//' | sed 's/ (.*//')

    if [ -z "$sim_name" ]; then
        sim_name=$(xcrun simctl list devices available | grep "iPhone" | head -1 | sed 's/^[[:space:]]*//' | sed 's/ (.*//')
    fi

    if [ -z "$sim_name" ]; then
        echo -e "${RED}❌ No suitable simulator found!${NC}"
        exit 1
    fi

    echo "$sim_name"
}

# ================================
# Argument Parsing
# ================================

VERBOSE=false
QUICK=false
FILTER=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --quick)
            QUICK=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --filter)
            FILTER="$2"
            shift 2
            ;;
        *)
            echo -e "${RED}Unknown argument: $1${NC}"
            echo "Usage: $0 [--quick] [--verbose] [--filter <test_method>]"
            exit 1
            ;;
    esac
done

# ================================
# Test Scenarios Description
# ================================

print_header "🧪 Training Plan Loading Flow Tests (ARCH-006)"

echo -e "${YELLOW}📄 Reference: Docs/01-architecture/ARCH-006-WeeklyPlan-Loading-Flow.md${NC}"
echo ""

print_scenario "測試場景覆蓋："
echo ""
echo "  1️⃣  App 乾淨啟動情境"
echo "      - viewPlan → .ready(plan)"
echo "      - createSummary → .noPlan"
echo "      - createPlan → .noPlan"
echo "      - trainingCompleted → .completed"
echo "      - noActivePlan → .noPlan"
echo ""
echo "  2️⃣  App 背景恢復"
echo "      - 未跨週：reinitialize"
echo "      - 跨週且有課表"
echo "      - 跨週且需產生週回顧"
echo ""
echo "  3️⃣  週數切換"
echo "      - 切換到過去週"
echo "      - 切換到未來週"
echo "      - 返回當前週"
echo ""
echo "  4️⃣  產生下週課表 ⭐ 關鍵修復驗證"
echo "      - 產生後立即顯示新課表"
echo "      - 產生時先設為 .loading"
echo "      - 需要先產生週回顧的流程"
echo ""
echo "  5️⃣  事件驅動更新"
echo "      - dataChanged.trainingPlan"
echo "      - targetUpdated"
echo ""
echo "  6️⃣  錯誤處理"
echo "  7️⃣  狀態一致性"
echo ""

# ================================
# Environment Setup
# ================================

SIMULATOR_NAME=$(detect_simulator)
echo -e "📱 Simulator: ${SIMULATOR_NAME}"
echo -e "🎯 Scheme:    ${SCHEME}"
echo -e "🧪 Test:      ${TEST_CLASS}"
echo ""

# Ensure Simulator is Booted
echo "🔄 Ensuring simulator is ready..."
DEVICE_ID=$(xcrun simctl list devices | grep "$SIMULATOR_NAME" | head -1 | grep -oE "[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}")

if [ -z "$DEVICE_ID" ]; then
    echo "❌ Could not find device ID for $SIMULATOR_NAME"
    exit 1
fi

DEVICE_STATE=$(xcrun simctl list devices | grep "$DEVICE_ID" | grep -o "Booted")

if [ "$DEVICE_STATE" != "Booted" ]; then
    echo "   Booting simulator ($DEVICE_ID)..."
    xcrun simctl boot "$DEVICE_ID"
    echo "   Waiting 10s for simulator services..."
    sleep 10
else
    echo "   Simulator already booted."
fi

echo ""

# ================================
# Build Test Command
# ================================

TEST_CMD=(
    "$XC_BUILD_WRAPPER" "test"
    "-project" "$PROJECT"
    "-scheme" "$SCHEME"
    "-destination" "platform=iOS Simulator,name=$SIMULATOR_NAME"
    "-configuration" "Debug"
    "-enableCodeCoverage" "YES"
    "-parallel-testing-enabled" "NO"
)

if [ "$QUICK" = true ]; then
    echo -e "${YELLOW}⚡ Quick Mode: Only testing critical fix (generateNextWeekPlan)${NC}"
    TEST_CMD+=("-only-testing:$TEST_TARGET/$TEST_CLASS/test_generateNextWeekPlan_showsNewPlanImmediately")
elif [ -n "$FILTER" ]; then
    echo -e "🔍 Filter: $FILTER"
    TEST_CMD+=("-only-testing:$TEST_TARGET/$TEST_CLASS/$FILTER")
else
    echo -e "🌎 Mode: All Loading Flow Tests"
    TEST_CMD+=("-only-testing:$TEST_TARGET/$TEST_CLASS")
fi

echo ""

# ================================
# Run Tests
# ================================

echo "⏳ Running Tests..."
START_TIME=$(date +%s)
LOG_FILE="test_training_plan_flow.log"

if [ "$VERBOSE" = true ]; then
    "${TEST_CMD[@]}" 2>&1 | tee "$LOG_FILE"
    EXIT_CODE=${PIPESTATUS[0]}
else
    "${TEST_CMD[@]}" > "$LOG_FILE" 2>&1 &
    PID=$!

    count=0
    while kill -0 $PID 2>/dev/null; do
        current_test=$(grep "Test Case '-\[" "$LOG_FILE" | grep " started." | tail -1 | sed -E "s/.* \-\[.*\.([^ ]*) ([^\]]*)\].*/\2/" | head -c 50)
        finished_count=$(grep "Test Case '-\[" "$LOG_FILE" | grep -E " (passed|failed)" | wc -l | tr -d ' ')

        if [ -z "$current_test" ]; then
            printf "\r${BLUE}Building & Initializing...${NC}\033[K"
        else
            printf "\r${BLUE}Running Test #%d: %s${NC}\033[K" "$((finished_count+1))" "$current_test"
        fi
        sleep 0.2
    done
    printf "\r\033[K"
    wait $PID || EXIT_CODE=$?
fi

if [ -z "$EXIT_CODE" ]; then EXIT_CODE=0; fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""

# ================================
# Parse Results
# ================================

TOTAL_TESTS=$(grep -o "Executed [0-9]* tests" "$LOG_FILE" | awk '{sum+=$2} END {print sum}' || echo "0")
FAILED_TESTS=$(grep -o "with [0-9]* failures" "$LOG_FILE" | awk '{sum+=$2} END {print sum}' || echo "0")

if [ -z "$TOTAL_TESTS" ] || [ "$TOTAL_TESTS" = "0" ]; then TOTAL_TESTS=0; fi
if [ -z "$FAILED_TESTS" ] || [ "$FAILED_TESTS" = "0" ]; then FAILED_TESTS=0; fi

# ================================
# Report
# ================================

if [ $EXIT_CODE -eq 0 ] && [ "$FAILED_TESTS" -eq 0 ]; then
    print_header "✅ All Loading Flow Tests Passed in ${DURATION}s"
    echo -e "📊 Summary:"
    echo -e "   Total Tests: ${GREEN}$TOTAL_TESTS${NC}"
    echo -e "   Failures:    ${GREEN}0${NC}"
    echo ""
    echo -e "${GREEN}🎉 ARCH-006 所有載入流程場景驗證通過！${NC}"
    echo ""

    # Show passed tests
    echo -e "${CYAN}✓ Passed Tests:${NC}"
    grep "Test Case '-\[" "$LOG_FILE" | grep " passed " | sed -E "s/.* \-\[.*\.([^ ]*) ([^\]]*)\].*/   ✓ \2/" | head -20
    echo ""

else
    if [ "$TOTAL_TESTS" -eq 0 ]; then
        print_header "❌ Build Failed (No tests executed)"

        echo -e "${RED}🔍 Compilation/Build Errors:${NC}"
        grep -E "error:|fatal error:|build failed" "$LOG_FILE" | grep -v "Run script build phase" | sed 's/^/   /' | head -n 30

    else
        print_header "❌ Tests Failed in ${DURATION}s"

        echo -e "📊 Summary:"
        echo -e "   Total Tests: $TOTAL_TESTS"
        echo -e "   Failures:    ${RED}$FAILED_TESTS${NC}"
        echo ""

        echo -e "${RED}🔍 Failed Test Cases:${NC}"
        grep "Test Case .* failed" "$LOG_FILE" | sed 's/Test Case/   ●/' | sed "s/'-\[//g" | sed "s/\]'//g" | sed 's/ failed.*//'

        echo ""
        echo -e "${RED}📝 Error Details:${NC}"
        grep -C 2 "XCTAssert" "$LOG_FILE" | grep -E "(failed|error)" | head -20 | sed 's/^/   /'
    fi

    echo ""
    echo -e "${YELLOW}Full log: $LOG_FILE${NC}"
fi

# ================================
# Additional Info
# ================================

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}📚 Additional Commands:${NC}"
echo ""
echo -e "   Run all unit tests:           ./Scripts/test.sh unit"
echo -e "   Run with Demo account (E2E):  ./Scripts/test.sh integration"
echo -e "   Run specific test:            ./Scripts/test_training_plan_flow.sh --filter test_appStart_viewPlan_showsWeeklyPlan"
echo -e "   Quick fix verification:       ./Scripts/test_training_plan_flow.sh --quick"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

exit $EXIT_CODE
