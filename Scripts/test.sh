#!/bin/bash

# ==============================================================================
# Unified Test Runner
# 
# Usage: ./test.sh [type] [options]
# 
# Types:
#   unit        Run only unit tests (skips integration tests)
#   integration Run only integration tests
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
#   ./test.sh all --clean
# ==============================================================================

# set -e

# Default configurations
SCHEME="Havital"
PROJECT="Havital.xcodeproj"
TEST_TARGET="HavitalTests"

# Known Integration Tests (Add new integration tests here)
INTEGRATION_TESTS=(
    "TrainingPlanRepositoryIntegrationTests"
    "TrainingPlanUseCaseIntegrationTests"
    "TrainingPlanFlowIntegrationTests"
    "TrainingPlanViewModelIntegrationTests"
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

detect_simulator() {
    # Detect iPhone 17 first, fallback to others
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
        unit|integration|all)
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
            echo "Usage: $0 [unit|integration|all] [--clean] [--verbose] [--filter ClassName]"
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
    "xcodebuild" "test"
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
    for test in "${INTEGRATION_TESTS[@]}"; do
        TEST_CMD+=("-skip-testing:$TEST_TARGET/$test")
    done

elif [ "$TYPE" == "integration" ]; then
    echo "🔗 Mode: Integration Tests Only"
    for test in "${INTEGRATION_TESTS[@]}"; do
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
TOTAL_TESTS=$(grep -o "Executed [0-9]* tests" "$LOG_FILE" | awk '{sum+=$2} END {print sum}' || echo "0")
FAILED_TESTS=$(grep -o "with [0-9]* failures" "$LOG_FILE" | awk '{sum+=$2} END {print sum}' || echo "0")
# Unexpected failures usually part of the same line, just grabbing total failures is often enough, 
# but let's try to get a clean count. The output format is usually:
# Executed 3 tests, with 0 failures (0 unexpected) in 0.003 (0.004) seconds

# Filter out the "Executed 0 tests" noise from bundles that didn't run anything
ACTUAL_TEST_RUNS=$(grep "Executed [1-9][0-9]* tests" "$LOG_FILE" || true)

if [ -z "$TOTAL_TESTS" ] || [ "$TOTAL_TESTS" = "0" ]; then TOTAL_TESTS=0; fi
if [ -z "$FAILED_TESTS" ] || [ "$FAILED_TESTS" = "0" ]; then FAILED_TESTS=0; fi

# 6. Report
if [ $EXIT_CODE -eq 0 ] && [ "$FAILED_TESTS" -eq 0 ]; then
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
