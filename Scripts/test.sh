#!/bin/bash

# ==============================================================================
# Unified Test Runner
#
# Usage: ./test.sh [type] [options]
#
# Types:
#   unit        Run only unit tests (skips integration tests)
#   integration Run only integration tests
#   ui          Run only UI tests
#   flow        Run loading flow tests (ARCH-006 scenarios)
#   all         Run all tests (default)
#
# Options:
#   --clean     Clear simulator cache before running
#   -v, --verbose Show verbose output
#   --filter <Class> Run specific test class
#
# Example:
#   ./test.sh unit
#   ./test.sh integration --verbose
#   ./test.sh flow              # ARCH-006 載入流程測試
#   ./test.sh all --clean
# ==============================================================================

# set -e


# Default configurations
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"
XC_BUILD_WRAPPER="$SCRIPT_DIR/run_xcodebuild.sh"

SCHEME="Havital"
PROJECT="Havital.xcodeproj"
TEST_TARGET="HavitalTests"

# Known Integration Tests (Add new integration tests here)
INTEGRATION_TESTS=(
    "TrainingPlanRepositoryIntegrationTests"
    "TrainingPlanUseCaseIntegrationTests"
    "TrainingPlanFlowIntegrationTests"
    "TrainingPlanViewModelIntegrationTests"
    "TargetToOverviewIntegrationTests"
)

# Loading Flow Tests (ARCH-006 scenarios)
LOADING_FLOW_TESTS=(
    "TrainingPlanLoadingFlowTests"
)

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ================================
# Helper Functions
# ================================

print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# 測試跑在**專用模擬器**上，不借用使用者自己在用的那一台。
#
# `xcodebuild test` 每一輪都會重裝 app，被借用的那台就會掉登入狀態——2026-09-02
# 使用者在模擬器登入後被連續洗掉兩次（「iOS 我登入，你不要在給我登出了」）。
# 名稱可用 `PACERIZ_TEST_SIMULATOR` 覆寫；那台不存在就現建一台。
TEST_SIMULATOR_NAME="${PACERIZ_TEST_SIMULATOR:-Paceriz Tests}"

simulator_exists() {
    xcrun simctl list devices available | grep -q "^[[:space:]]*$1 ("
}

create_test_simulator() {
    local device_type runtime
    device_type=$(xcrun simctl list devicetypes | grep -m1 "iPhone 17 Pro (" | grep -oE "com\.apple\.CoreSimulator\.SimDeviceType\.[^)]*")
    [ -z "$device_type" ] && device_type=$(xcrun simctl list devicetypes | grep -m1 "iPhone" | grep -oE "com\.apple\.CoreSimulator\.SimDeviceType\.[^)]*")
    runtime=$(xcrun simctl list runtimes | grep -oE "com\.apple\.CoreSimulator\.SimRuntime\.iOS-[0-9-]+" | tail -1)
    [ -z "$device_type" ] || [ -z "$runtime" ] && return 1
    xcrun simctl create "$TEST_SIMULATOR_NAME" "$device_type" "$runtime" >/dev/null 2>&1
}

detect_simulator() {
    if simulator_exists "$TEST_SIMULATOR_NAME"; then
        echo "$TEST_SIMULATOR_NAME"
        return
    fi
    if create_test_simulator && simulator_exists "$TEST_SIMULATOR_NAME"; then
        echo "$TEST_SIMULATOR_NAME"
        return
    fi

    # 建不出來才退回借用既有的一台（會清掉那台的 app 資料）。
    echo -e "${YELLOW}⚠️  建不出測試專用模擬器「$TEST_SIMULATOR_NAME」，改用既有模擬器（那台的登入狀態會被清掉）${NC}" >&2
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

TYPE="all"
CLEAN_CACHE=false
VERBOSE=false
FILTER=""

while [[ $# -gt 0 ]]; do
    case $1 in
        unit|integration|ui|flow|all)
            TYPE="$1"
            shift
            ;;
        --clean)
            CLEAN_CACHE=true
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
            echo "Usage: $0 [unit|integration|ui|flow|all] [--clean] [--verbose] [--filter ClassName]"
            exit 1
            ;;
    esac
done

# ================================
# Execution
# ================================

print_header "🚀 Havital Test Runner: $TYPE"

# 1. Environment Setup
SIMULATOR_NAME=$(detect_simulator)
echo "📱 Simulator: $SIMULATOR_NAME"
echo "🎯 Scheme:    $SCHEME"
echo ""

# Ensure Simulator is Booted and Ready
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
    
    # Wait for networking to initialize
    echo "   Waiting 10s for simulator services..."
    sleep 10
else
    echo "   Simulator already booted."
fi

# 2. Cache Cleaning (Optional)
if [ "$CLEAN_CACHE" = true ]; then
    echo "🧹 Cleaning Simulator Cache..."
    ./Scripts/clear_simulator_cache.sh <<< "y
y"
    echo ""
fi

# 3. Build Test Command
TEST_CMD=(
    "$XC_BUILD_WRAPPER" "test"
    "-project" "$PROJECT"
    "-scheme" "$SCHEME"
    "-destination" "platform=iOS Simulator,name=$SIMULATOR_NAME"
    "-configuration" "Debug"
    "-enableCodeCoverage" "YES"
    "-parallel-testing-enabled" "NO"
)

# Apply Filter (Specific Class)
if [ -n "$FILTER" ]; then
    echo "🔍 Filter: $FILTER"
    TEST_CMD+=("-only-testing:$TEST_TARGET/$FILTER")

# Apply Type Logic
elif [ "$TYPE" == "unit" ]; then
    echo "🧪 Mode: Unit Tests (Skipping Integration)"
    TEST_CMD+=("-skip-testing:HavitalUITests")
    for test in "${INTEGRATION_TESTS[@]}"; do
        TEST_CMD+=("-skip-testing:$TEST_TARGET/$test")
    done

elif [ "$TYPE" == "integration" ]; then
    echo "🔗 Mode: Integration Tests Only"
    for test in "${INTEGRATION_TESTS[@]}"; do
        TEST_CMD+=("-only-testing:$TEST_TARGET/$test")
    done

elif [ "$TYPE" == "ui" ]; then
    echo "📱 Mode: UI Tests Only"
    TEST_CMD+=("-only-testing:HavitalUITests")

elif [ "$TYPE" == "flow" ]; then
    echo "🔄 Mode: Loading Flow Tests (ARCH-006)"
    for test in "${LOADING_FLOW_TESTS[@]}"; do
        TEST_CMD+=("-only-testing:$TEST_TARGET/$test")
    done

else # all
    echo "🌎 Mode: All Tests"
fi

# Verbose Handling
if [ "$VERBOSE" = true ]; then
    # In verbose mode, we don't suppress anything
    :
else
    # In normal mode, we don't use -quiet because we want to see Test Case progress
    # But we will filter the output below
    :
fi

echo ""

# 4. Run Tests
echo "⏳ Running Tests..."
START_TIME=$(date +%s)
LOG_FILE="test_output.log"
XC_LOG="xcodebuild.log"

# Enable pipefail
# set -o pipefail

# Run xcodebuild and capture output to file, while showing a simple progress spinner or just waiting.
# We don't pipe to grep for display to avoid the messy output properly.
echo "   (Logs are being written to $LOG_FILE)"

if [ "$VERBOSE" = true ]; then
    "${TEST_CMD[@]}" 2>&1 | tee "$LOG_FILE"
    test_pipeline_status=("${PIPESTATUS[@]}")
    EXIT_CODE=${test_pipeline_status[0]}
    if [ "$EXIT_CODE" -eq 0 ]; then EXIT_CODE=${test_pipeline_status[1]}; fi
else
    # Run silently-ish, just showing dots or simple progress
    "${TEST_CMD[@]}" > "$LOG_FILE" 2>&1 &
    PID=$!
    
    # Progress Loop
    count=0
    while kill -0 $PID 2>/dev/null; do
        # Extract last started test case name
        # Looking for: Test Case '-[Target.Class Method]' started.
        # We try to extract just the method name or Class.Method for brevity
        current_test=$(grep "Test Case '-\[" "$LOG_FILE" | grep " started." | tail -1 | sed -E "s/.* \-\[.*\.([^ ]*) ([^\]]*)\].*/\1 \2/")
        
        # Count completed tests (passed + failed)
        finished_count=$(grep "Test Case '-\[" "$LOG_FILE" | grep -E " (passed|failed)" | wc -l | tr -d ' ')
        
        if [ -z "$current_test" ]; then
             printf "\r${BLUE}Building & Initializing...${NC}\033[K"
        else
             # Show "Running Test #N: Class Method"
             # The count is finished_count + 1 because we are running the next one
             printf "\r${BLUE}Running Test #%d: %s${NC}\033[K" "$((finished_count+1))" "$current_test"
        fi
        sleep 0.2
    done
    printf "\r\033[K" # Clear the progress line when done
    wait $PID || EXIT_CODE=$?
fi

# If verbose, we already printed everything. If not, we just finished.
if [ -z "$EXIT_CODE" ]; then EXIT_CODE=0; fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# 5. Parse Results
echo ""

# Extract Summary Info
# 取最後一次出現，不是加總。xcodebuild 對同一份結果會印好幾次
# （每個 test class 一次，外加 bundle 與 "All tests" 兩個彙總），加總等於把每條測試重複計算——
# 實測一次只跑 2 條的 class，log 裡有 3 行 `Executed 2 tests`，加總得 6。
# 這個數字被當成「測試數量地板」在用，3 倍膨脹會讓任何人讀錯，也讓地板差值失去意義。
# 最後一行是 "All tests" 的總計，那才是這一次實際跑了幾條。
TOTAL_TESTS=$(grep -o "Executed [0-9]* tests" "$LOG_FILE" | tail -1 | awk '{print $2}' || echo "0")
FAILED_TESTS=$(grep -oE "with [0-9]+ failures?" "$LOG_FILE" | tail -1 | awk '{print $2}' || echo "0")
# Unexpected failures usually part of the same line, just grabbing total failures is often enough, 
# but let's try to get a clean count. The output format is usually:
# Executed 3 tests, with 0 failures (0 unexpected) in 0.003 (0.004) seconds

# Filter out the "Executed 0 tests" noise from bundles that didn't run anything
ACTUAL_TEST_RUNS=$(grep "Executed [1-9][0-9]* tests" "$LOG_FILE" || true)

if [ -z "$TOTAL_TESTS" ] || [ "$TOTAL_TESTS" = "0" ]; then TOTAL_TESTS=0; fi
if [ -z "$FAILED_TESTS" ] || [ "$FAILED_TESTS" = "0" ]; then FAILED_TESTS=0; fi
if [ "$FAILED_TESTS" -gt 0 ] && [ "$EXIT_CODE" -eq 0 ]; then EXIT_CODE=1; fi

# 5b. 測試數量地板 (T-0176)
#
# 只看 exit code 會被「測試靜默消失」騙過去：T-0176 那次 LoginViewModelTests 一個重複
# fulfill 丟出 NSInternalInconsistencyException，一口氣吞掉約 400 條測試，而回報是綠的。
# 綠燈若不附帶「到底跑了幾條」，它的意義是未知的。
#
# 因此：只在**無 filter 的完整 unit 跑**（唯一數量可比的情境）比對地板值。
# 地板值存在 scripts/.test-count-baseline.<type>，用 --update-baseline 更新。
BASELINE_FILE="$SCRIPT_DIR/.test-count-baseline.$TYPE"
COUNT_FLOOR_FAILED=0
if [ -z "$FILTER" ] && [ "$EXIT_CODE" -eq 0 ] && [ "$TOTAL_TESTS" -gt 0 ]; then
    if [ "${UPDATE_BASELINE:-0}" = "1" ]; then
        echo "$TOTAL_TESTS" > "$BASELINE_FILE"
        echo -e "${GREEN}📌 測試數量地板已更新為 $TOTAL_TESTS（$BASELINE_FILE）${NC}"
    elif [ -f "$BASELINE_FILE" ]; then
        BASELINE=$(cat "$BASELINE_FILE")
        if [ "$TOTAL_TESTS" -lt "$BASELINE" ]; then
            COUNT_FLOOR_FAILED=1
            MISSING=$((BASELINE - TOTAL_TESTS))
        elif [ "$TOTAL_TESTS" -gt "$BASELINE" ]; then
            echo "$TOTAL_TESTS" > "$BASELINE_FILE"
            echo -e "${GREEN}📌 測試數量成長 $BASELINE → $TOTAL_TESTS，地板已自動抬升${NC}"
        fi
    else
        echo "$TOTAL_TESTS" > "$BASELINE_FILE"
        echo -e "${YELLOW}📌 已建立測試數量地板：$TOTAL_TESTS（$BASELINE_FILE）${NC}"
    fi
fi

# 6. Report
if [ "$COUNT_FLOOR_FAILED" -eq 1 ]; then
    print_header "❌ 測試數量低於地板（有測試靜默消失）"
    echo -e "📊 Summary:"
    echo -e "   Total Tests: ${RED}$TOTAL_TESTS${NC}   (地板 $BASELINE，少了 $MISSING 條)"
    echo -e "   Failures:    ${GREEN}0${NC}"
    echo ""
    echo -e "${RED}測試全部通過，但跑的條數比基準少 —— 這正是 T-0176 的形狀：${NC}"
    echo -e "${RED}某個 test case crash 後吞掉整批測試，回報卻是綠的。${NC}"
    echo ""
    echo -e "   先確認是否有 test bundle 中途爆掉：grep -n 'crash\\|Inconsistency' $LOG_FILE"
    echo -e "   若是刻意刪除測試，更新地板：UPDATE_BASELINE=1 $0 $TYPE"
    echo ""
    exit 1
elif [ $EXIT_CODE -eq 0 ] && [ "$FAILED_TESTS" -eq 0 ]; then
    print_header "✅ All Tests Passed in ${DURATION}s"
    echo -e "📊 Summary:"
    echo -e "   Total Tests: ${GREEN}$TOTAL_TESTS${NC}"
    echo -e "   Failures:    ${GREEN}0${NC}"
    echo ""
else
    # Check if this was a build failure (No tests executed but exited with error)
    if [ "$TOTAL_TESTS" -eq 0 ]; then
         print_header "❌ Build Failed (No tests executed)"
         
         echo -e "${RED}🔍 Compilation/Build Errors:${NC}"
         # Grep only error lines, ignore some standard noise if needed, but usually error: is good
         grep -E "error:|fatal error:|build failed" "$LOG_FILE" | grep -v "Run script build phase" | sed 's/^/   /' | head -n 30
         
         if [ $(grep -c "error:" "$LOG_FILE") -eq 0 ]; then
             echo "   (No explicit 'error:' found in logs. Check full log for details.)"
             tail -n 20 "$LOG_FILE"
         fi
         
    else
        print_header "❌ Tests Failed in ${DURATION}s"
        
        echo -e "📊 Summary:"
        echo -e "   Total Tests: $TOTAL_TESTS"
        echo -e "   Failures:    ${RED}$FAILED_TESTS${NC}"
        echo ""
        
        echo -e "${RED}🔍 Failed Test Cases:${NC}"
        grep "Test Case .* failed" "$LOG_FILE" | sed 's/Test Case/   ●/' | sed "s/'-\[//g" | sed "s/\]'//g" | sed 's/ failed.*//'
        
        echo ""
        echo -e "${RED}📝 Error Details (Context):${NC}"
        # Print lines surrounding "error:" to give context
        grep -C 2 "error:" "$LOG_FILE" | head -20 | sed 's/^/   /'
    fi
    
    echo ""
    echo -e "${YELLOW}full log: $LOG_FILE${NC}"
fi

exit $EXIT_CODE
