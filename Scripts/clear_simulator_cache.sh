#!/bin/bash

# 清空 Simulator 中 App 的緩存
# 使用場景: 測試無緩存情況下 Manager 的 API 調用邏輯

echo "🗑️  清空 Simulator 中的 App 緩存"
echo ""

# 配置
APP_BUNDLE_ID="com.havital.Havital"
# 自動檢測第一個可用的 iPhone Simulator
SIMULATOR_NAME=$(xcrun simctl list devices available | grep "iPhone" | head -1 | sed 's/^[[:space:]]*//' | sed 's/ (.*//')
if [ -z "$SIMULATOR_NAME" ]; then
    SIMULATOR_NAME="iPhone 16e"  # 回退到默認值
fi

# 顏色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 獲取 Simulator UUID
SIMULATOR_UUID=$(xcrun simctl list devices | grep "$SIMULATOR_NAME" | grep -o '[0-9A-F-]\{36\}' | head -1)

if [ -z "$SIMULATOR_UUID" ]; then
    echo "❌ 找不到 Simulator: $SIMULATOR_NAME"
    echo "可用的 Simulator:"
    xcrun simctl list devices | grep "iPhone"
    exit 1
fi

echo -e "${BLUE}Simulator: $SIMULATOR_NAME${NC}"
echo -e "${BLUE}UUID: $SIMULATOR_UUID${NC}"
echo ""

# 查找 App 的數據目錄
APP_DATA_DIR=$(xcrun simctl get_app_container "$SIMULATOR_UUID" "$APP_BUNDLE_ID" data 2>/dev/null)

if [ -z "$APP_DATA_DIR" ]; then
    echo -e "${YELLOW}⚠️  App 未安裝在 Simulator 中${NC}"
    echo "請先運行 App 一次，或使用以下命令安裝:"
    echo "  xcodebuild build -project Havital.xcodeproj -scheme Havital -destination 'platform=iOS Simulator,name=$SIMULATOR_NAME'"
    exit 1
fi

echo -e "${BLUE}App 數據目錄: $APP_DATA_DIR${NC}"
echo ""

# 清空緩存目錄
echo "📋 清空緩存目錄..."

# 1. Library/Caches
CACHES_DIR="$APP_DATA_DIR/Library/Caches"
if [ -d "$CACHES_DIR" ]; then
    echo "  - 清空 Library/Caches"
    rm -rf "$CACHES_DIR"/*
    echo -e "${GREEN}    ✅ 已清空 $(du -sh "$CACHES_DIR" 2>/dev/null | cut -f1)${NC}"
fi

# 2. tmp
TMP_DIR="$APP_DATA_DIR/tmp"
if [ -d "$TMP_DIR" ]; then
    echo "  - 清空 tmp"
    rm -rf "$TMP_DIR"/*
    echo -e "${GREEN}    ✅ 已清空${NC}"
fi

# 3. UserDefaults (可選)
echo ""
read -p "是否清空 UserDefaults? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    PREFERENCES_DIR="$APP_DATA_DIR/Library/Preferences"
    if [ -d "$PREFERENCES_DIR" ]; then
        echo "  - 清空 Library/Preferences"
        rm -rf "$PREFERENCES_DIR"/*
        echo -e "${GREEN}    ✅ 已清空${NC}"
    fi
fi

# 4. Documents (Storage 文件，謹慎操作)
echo ""
read -p "是否清空 Documents (包含 Storage 數據)? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    DOCUMENTS_DIR="$APP_DATA_DIR/Documents"
    if [ -d "$DOCUMENTS_DIR" ]; then
        echo "  - 清空 Documents"
        rm -rf "$DOCUMENTS_DIR"/*
        echo -e "${GREEN}    ✅ 已清空${NC}"
    fi
fi

echo ""
echo -e "${GREEN}🎉 緩存清空完成！${NC}"
echo ""
echo "下一步:"
echo "  1. 啟動 Simulator"
echo "  2. 打開 Paceriz App"
echo "  3. 查看 Xcode Console 日誌"
echo "  4. 應該看到 '📡 API 調用' (因為沒有緩存)"
echo ""
echo "驗證雙軌緩存:"
echo "  - 第一次打開: 應該從 API 載入 (沒有緩存)"
echo "  - 下拉刷新後關閉 App"
echo "  - 第二次打開: 應該立即顯示緩存，然後背景刷新"
