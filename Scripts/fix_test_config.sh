#!/bin/bash

# 修復 Xcode 測試配置問題
# 解決 TEST_HOST 路徑錯誤

echo "🔧 修復 Xcode 測試配置..."
echo ""

PROJECT_DIR="/Users/wubaizong/havital/apps/ios/Havital"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

# 顏色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# ================================
# 檢查測試配置
# ================================

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}檢查當前測試配置${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 檢查 TEST_HOST 設置
echo "📋 檢查 TEST_HOST 配置..."

TEST_HOST_VALUE=$("$SCRIPT_DIR/run_xcodebuild.sh" -project Havital.xcodeproj -scheme Havital -showBuildSettings | grep "TEST_HOST = " | head -1)

if echo "$TEST_HOST_VALUE" | grep -q "Paceriz.app"; then
    echo -e "${YELLOW}⚠️  發現問題: TEST_HOST 指向 Paceriz.app${NC}"
    echo "   $TEST_HOST_VALUE"
    echo ""
    echo "這會導致測試失敗，因為 App bundle 名稱可能不匹配。"
    echo ""
else
    echo -e "${GREEN}✅ TEST_HOST 配置看起來正常${NC}"
    echo "   $TEST_HOST_VALUE"
    echo ""
fi

# ================================
# 建議的修復方法
# ================================

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}修復建議${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "修復 TEST_HOST 配置問題的方法:"
echo ""
echo "方法 1: 在 Xcode 中手動修復 (推薦)"
echo "  1. 打開 Havital.xcodeproj"
echo "  2. 選擇 HavitalTests target"
echo "  3. Build Settings → Testing"
echo "  4. 找到 'Bundle Loader' 或 'TEST_HOST'"
echo "  5. 確保路徑正確指向實際的 App bundle"
echo ""

echo "方法 2: 使用依賴注入 (更好的測試方式)"
echo "  不依賴 TEST_HOST，而是通過依賴注入 mock 對象"
echo "  - 我已經在 TrainingPlanManagerTests.swift 中提供了示例"
echo "  - 需要在 Manager 中添加依賴注入支持"
echo ""

echo "方法 3: 使用 Swift Package Manager"
echo "  考慮將測試遷移到 SPM，避免 Xcode 配置問題"
echo ""

# ================================
# 提供快速測試選項
# ================================

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}快速驗證選項${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

read -p "是否嘗試運行測試? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "運行測試..."

    # 嘗試運行測試
    "$SCRIPT_DIR/run_xcodebuild.sh" test \
        -project Havital.xcodeproj \
        -scheme Havital \
        -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
        -only-testing:HavitalTests/TrainingPlanManagerTests \
        2>&1 | tee test_output.log

    if grep -q "Test Suite.*passed" test_output.log; then
        echo ""
        echo -e "${GREEN}🎉 測試通過！${NC}"
    elif grep -q "Could not find test host" test_output.log; then
        echo ""
        echo -e "${RED}❌ TEST_HOST 配置問題仍然存在${NC}"
        echo ""
        echo "建議: 使用方法 2 (依賴注入) 來避免這個問題"
        echo "我已經創建了測試模板，只需要在 Manager 中添加依賴注入即可"
    else
        echo ""
        echo -e "${YELLOW}⚠️  測試失敗，查看 test_output.log 了解詳情${NC}"
    fi
fi

echo ""
echo -e "${GREEN}✅ 配置檢查完成${NC}"
echo ""
echo "下一步:"
echo "  1. 查看測試文件: HavitalTests/Managers/TrainingPlanManagerTests.swift"
echo "  2. 在 Manager 中添加依賴注入支持"
echo "  3. 運行測試驗證重構"
