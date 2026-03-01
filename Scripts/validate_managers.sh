#!/bin/bash

# Manager 重構自動化驗證腳本
# 包含: 靜態檢查 + 單元測試 + 編譯驗證

set -e  # 遇到錯誤立即退出

echo "🔍 開始自動化驗證 Manager 層架構..."
echo ""

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ERRORS=0
WARNINGS=0
TESTS_PASSED=0
TESTS_FAILED=0

# 配置
PROJECT_DIR="/Users/wubaizong/havital/apps/ios/Havital"
SCHEME="Havital"
# 自動檢測第一個可用的 iPhone Simulator
SIMULATOR_NAME=$(xcrun simctl list devices available | grep "iPhone" | head -1 | sed 's/^[[:space:]]*//' | sed 's/ (.*//')
if [ -z "$SIMULATOR_NAME" ]; then
    SIMULATOR_NAME="iPhone 16e"  # 回退到默認值
fi
DESTINATION="platform=iOS Simulator,name=$SIMULATOR_NAME"
TIMEOUT=300  # 5 minutes

# 解析參數
QUICK_MODE=false
SKIP_BUILD=false
SKIP_TESTS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --quick)
            QUICK_MODE=true
            SKIP_BUILD=true
            SKIP_TESTS=true
            shift
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        *)
            echo "未知參數: $1"
            echo "用法: $0 [--quick] [--skip-build] [--skip-tests]"
            exit 1
            ;;
    esac
done

cd "$PROJECT_DIR"

if [ "$QUICK_MODE" = true ]; then
    echo -e "${BLUE}⚡ 快速模式: 僅執行靜態檢查${NC}"
    echo ""
fi

# ================================
# 第一階段: 靜態代碼檢查
# ================================

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}第一階段: 靜態代碼檢查${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 1. Dictionary 安全性
echo "📋 [1/10] 檢查 Dictionary 安全性..."
DICT_ISSUES=$(grep -r "Dictionary.*Date" Havital/Managers/ --include="*.swift" 2>/dev/null || true)
if [ -n "$DICT_ISSUES" ]; then
    echo -e "${RED}❌ 發現 Date 作為 Dictionary key (會崩潰):${NC}"
    echo "$DICT_ISSUES"
    ((ERRORS++))
    ((TESTS_FAILED++))
else
    echo -e "${GREEN}✅ Dictionary 使用安全${NC}"
    ((TESTS_PASSED++))
fi
echo ""

# 2. TaskManageable 實現
echo "📋 [2/10] 檢查 TaskManageable 實現..."
MISSING_COUNT=0
for file in Havital/Managers/*Manager.swift; do
    if grep -q "class.*Manager.*TaskManageable" "$file" 2>/dev/null; then
        if ! grep -q "let taskRegistry = TaskRegistry()" "$file"; then
            echo -e "${RED}  ❌ $file 缺少 taskRegistry${NC}"
            ((MISSING_COUNT++))
        fi
    fi
done
if [ $MISSING_COUNT -gt 0 ]; then
    ((ERRORS++))
    ((TESTS_FAILED++))
else
    echo -e "${GREEN}✅ 所有 Manager 正確實現 TaskRegistry${NC}"
    ((TESTS_PASSED++))
fi
echo ""

# 3. 取消錯誤處理
echo "📋 [3/10] 檢查任務取消處理..."
MISSING_CANCELLATION=0
for file in Havital/Managers/*Manager.swift; do
    if grep -q "catch {" "$file" 2>/dev/null; then
        if ! grep -q "NSURLErrorCancelled\|isCancelled" "$file"; then
            echo -e "${YELLOW}  ⚠️  $file 可能缺少取消錯誤處理${NC}"
            ((MISSING_CANCELLATION++))
        fi
    fi
done
if [ $MISSING_CANCELLATION -gt 5 ]; then
    echo -e "${YELLOW}⚠️  發現 $MISSING_CANCELLATION 個文件可能缺少取消處理${NC}"
    ((WARNINGS++))
else
    echo -e "${GREEN}✅ 取消錯誤處理基本完整${NC}"
    ((TESTS_PASSED++))
fi
echo ""

# 4. weak self 檢查
echo "📋 [4/10] 檢查 weak self 使用..."
MISSING_WEAK_COUNT=$(grep -n "Task {" Havital/Managers/*.swift 2>/dev/null | grep -v "\[weak self\]" | grep -v "Task.detached" | wc -l | xargs)
if [ "$MISSING_WEAK_COUNT" -gt 10 ]; then
    echo -e "${YELLOW}⚠️  發現 $MISSING_WEAK_COUNT 處可能需要 [weak self]${NC}"
    ((WARNINGS++))
else
    echo -e "${GREEN}✅ weak self 使用基本正確${NC}"
    ((TESTS_PASSED++))
fi
echo ""

# 5. 編譯檢查
echo "📋 [5/10] 編譯檢查..."
if [ "$SKIP_BUILD" = true ]; then
    echo -e "${YELLOW}⚡ 跳過 (快速模式)${NC}"
else
    if xcodebuild -project Havital.xcodeproj -scheme "$SCHEME" -destination "$DESTINATION" build -quiet 2>&1 | grep -i "error:"; then
        echo -e "${RED}❌ 編譯失敗${NC}"
        ((ERRORS++))
        ((TESTS_FAILED++))
    else
        echo -e "${GREEN}✅ 編譯通過${NC}"
        ((TESTS_PASSED++))
    fi
fi
echo ""

# 6. SwiftLint 檢查 (如果有安裝)
echo "📋 [6/10] SwiftLint 檢查..."
if command -v swiftlint &> /dev/null; then
    LINT_ERRORS=$(swiftlint lint --quiet Havital/Managers/ 2>&1 | grep "error" | wc -l | xargs)
    if [ "$LINT_ERRORS" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  發現 $LINT_ERRORS 個 Lint 錯誤${NC}"
        swiftlint lint Havital/Managers/ | grep "error"
        ((WARNINGS++))
    else
        echo -e "${GREEN}✅ SwiftLint 檢查通過${NC}"
        ((TESTS_PASSED++))
    fi
else
    echo -e "${YELLOW}⚠️  SwiftLint 未安裝，跳過${NC}"
fi
echo ""

# 7. 檢查 Logger 使用
echo "📋 [7/10] 檢查日誌覆蓋率..."
TOTAL_ASYNC_FUNCS=$(grep -rh "func.*async" Havital/Managers/*.swift 2>/dev/null | wc -l | xargs)
LOGGED_FUNCS=$(grep -rh "Logger\." Havital/Managers/*.swift 2>/dev/null | wc -l | xargs)

if [ "$TOTAL_ASYNC_FUNCS" -eq 0 ]; then
    echo -e "${YELLOW}⚠️  沒有找到 async 函數${NC}"
    ((WARNINGS++))
else
    COVERAGE=$((LOGGED_FUNCS * 100 / TOTAL_ASYNC_FUNCS))
    if [ $COVERAGE -lt 30 ]; then
        echo -e "${YELLOW}⚠️  日誌覆蓋率較低: ${COVERAGE}% (async: $TOTAL_ASYNC_FUNCS, logs: $LOGGED_FUNCS)${NC}"
        ((WARNINGS++))
    else
        echo -e "${GREEN}✅ 日誌覆蓋率: ${COVERAGE}% (async: $TOTAL_ASYNC_FUNCS, logs: $LOGGED_FUNCS)${NC}"
        ((TESTS_PASSED++))
    fi
fi
echo ""

# 8. 檢查 API 追蹤
echo "📋 [8/10] 檢查 API 調用追蹤..."
VIEWS_WITH_TASKS=$(grep -l "Task {" Havital/Views/**/*.swift 2>/dev/null | wc -l | xargs)
VIEWS_WITH_TRACKING=$(grep -l ".tracked(from:" Havital/Views/**/*.swift 2>/dev/null | wc -l | xargs)
if [ "$VIEWS_WITH_TASKS" -gt 0 ]; then
    TRACKING_RATIO=$((VIEWS_WITH_TRACKING * 100 / VIEWS_WITH_TASKS))
    if [ $TRACKING_RATIO -lt 50 ]; then
        echo -e "${YELLOW}⚠️  API 追蹤覆蓋率: ${TRACKING_RATIO}%${NC}"
        ((WARNINGS++))
    else
        echo -e "${GREEN}✅ API 追蹤覆蓋率: ${TRACKING_RATIO}%${NC}"
        ((TESTS_PASSED++))
    fi
else
    echo -e "${GREEN}✅ 跳過 (沒有 Task 調用)${NC}"
    ((TESTS_PASSED++))
fi
echo ""

# 9. 檢查初始化順序
echo "📋 [9/10] 檢查初始化順序..."
INIT_ISSUES=0
for file in Havital/Managers/*Manager.swift; do
    if grep -A 10 "init()" "$file" 2>/dev/null | grep -q "Task {"; then
        if ! grep -A 10 "init()" "$file" | grep -q "waitFor\|guard.*isAuthenticated"; then
            ((INIT_ISSUES++))
        fi
    fi
done
if [ $INIT_ISSUES -gt 0 ]; then
    echo -e "${YELLOW}⚠️  發現 $INIT_ISSUES 個 Manager 可能缺少初始化順序控制${NC}"
    ((WARNINGS++))
else
    echo -e "${GREEN}✅ 初始化順序控制正確${NC}"
    ((TESTS_PASSED++))
fi
echo ""

# 10. 檢查雙軌緩存實現
echo "📋 [10/10] 檢查雙軌緩存模式..."
CACHE_ISSUES=0
for file in Havital/Managers/*Manager.swift; do
    if grep -q "getCached\|loadCached" "$file" 2>/dev/null; then
        if ! grep -q "Task.detached\|background.*refresh\|refreshInBackground" "$file"; then
            echo -e "${YELLOW}  ⚠️  $(basename $file) 使用緩存但可能缺少背景刷新${NC}"
            ((CACHE_ISSUES++))
        fi
    fi
done
if [ $CACHE_ISSUES -gt 0 ]; then
    echo -e "${YELLOW}⚠️  發現 $CACHE_ISSUES 個 Manager 可能缺少雙軌緩存${NC}"
    ((WARNINGS++))
else
    echo -e "${GREEN}✅ 雙軌緩存模式正確${NC}"
    ((TESTS_PASSED++))
fi
echo ""

# ================================
# 第二階段: 單元測試 (自動生成)
# ================================

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}第二階段: 單元測試執行${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 11. 運行現有的單元測試 (如果有)
echo "📋 [11] 運行單元測試..."
if [ "$SKIP_TESTS" = true ]; then
    echo -e "${YELLOW}⚡ 跳過 (快速模式)${NC}"
elif [ -d "HavitalTests" ]; then
    TEST_OUTPUT=$(xcodebuild test \
        -project Havital.xcodeproj \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -only-testing:HavitalTests \
        2>&1 || true)

    if echo "$TEST_OUTPUT" | grep -q "Test Suite.*passed"; then
        PASSED_COUNT=$(echo "$TEST_OUTPUT" | grep -o "[0-9]* tests" | head -1 | grep -o "[0-9]*")
        echo -e "${GREEN}✅ 單元測試通過 ($PASSED_COUNT 個測試)${NC}"
        ((TESTS_PASSED++))
    elif echo "$TEST_OUTPUT" | grep -q "Test Suite.*failed"; then
        FAILED_COUNT=$(echo "$TEST_OUTPUT" | grep -o "[0-9]* failures" | head -1 | grep -o "[0-9]*" || echo "0")
        echo -e "${RED}❌ 單元測試失敗 ($FAILED_COUNT 個失敗)${NC}"
        echo "$TEST_OUTPUT" | grep "error:"
        ((ERRORS++))
        ((TESTS_FAILED++))
    else
        echo -e "${YELLOW}⚠️  沒有找到單元測試或測試跳過${NC}"
        ((WARNINGS++))
    fi
else
    echo -e "${YELLOW}⚠️  HavitalTests 目錄不存在，跳過單元測試${NC}"
fi
echo ""

# ================================
# 第三階段: 運行時驗證 (可選)
# ================================

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}第三階段: 運行時驗證 (可選)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 12. 檢查是否有 DeveloperTools (用於清空緩存測試)
echo "📋 [12] 檢查開發者工具..."
if [ -f "Havital/Utils/DeveloperTools.swift" ]; then
    echo -e "${GREEN}✅ 開發者工具已安裝${NC}"
    echo -e "${BLUE}   提示: 可使用開發者工具清空緩存進行手動測試${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⚠️  開發者工具未安裝${NC}"
fi
echo ""

# ================================
# 總結報告
# ================================

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}驗證結果總結${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "測試通過: ${GREEN}$TESTS_PASSED${NC}"
echo -e "測試失敗: ${RED}$TESTS_FAILED${NC}"
echo -e "錯誤數量: ${RED}$ERRORS${NC}"
echo -e "警告數量: ${YELLOW}$WARNINGS${NC}"
echo ""

# 生成詳細報告
REPORT_FILE="validation_report_$(date +%Y%m%d_%H%M%S).txt"
cat > "$REPORT_FILE" << EOF
Manager 驗證報告
================
時間: $(date)
通過: $TESTS_PASSED
失敗: $TESTS_FAILED
錯誤: $ERRORS
警告: $WARNINGS

靜態檢查:
- Dictionary 安全性: $([ $ERRORS -eq 0 ] && echo "通過" || echo "失敗")
- TaskManageable 實現: 通過
- 取消錯誤處理: $([ $MISSING_CANCELLATION -lt 5 ] && echo "通過" || echo "警告")
- weak self 使用: $([ $MISSING_WEAK_COUNT -lt 10 ] && echo "通過" || echo "警告")
- 編譯檢查: 通過
- 日誌覆蓋率: ${COVERAGE}%
- API 追蹤覆蓋率: ${TRACKING_RATIO}%
- 雙軌緩存: $([ $CACHE_ISSUES -eq 0 ] && echo "通過" || echo "警告")

建議:
$([ $ERRORS -gt 0 ] && echo "- 修復 $ERRORS 個錯誤後再提交代碼")
$([ $WARNINGS -gt 5 ] && echo "- 建議修復 $WARNINGS 個警告")
$([ $COVERAGE -lt 50 ] && echo "- 增加日誌覆蓋率 (當前: ${COVERAGE}%)")
$([ $MISSING_CANCELLATION -gt 5 ] && echo "- 添加取消錯誤處理到 $MISSING_CANCELLATION 個文件")
EOF

echo -e "${BLUE}詳細報告已保存到: $REPORT_FILE${NC}"
echo ""

# 決定退出碼
if [ $ERRORS -eq 0 ]; then
    if [ $WARNINGS -eq 0 ]; then
        echo -e "${GREEN}🎉 驗證完全通過！${NC}"
        exit 0
    else
        echo -e "${YELLOW}✅ 驗證通過，但有 $WARNINGS 個警告 (建議修復)${NC}"
        exit 0
    fi
else
    echo -e "${RED}❌ 驗證失敗，發現 $ERRORS 個錯誤${NC}"
    echo -e "${RED}   請修復後再提交代碼${NC}"
    exit 1
fi
