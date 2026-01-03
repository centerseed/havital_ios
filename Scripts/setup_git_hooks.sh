#!/bin/bash

# 設置 Git Hooks 自動化驗證

echo "🔧 設置 Git Hooks..."

GIT_DIR=$(git rev-parse --git-dir 2>/dev/null)
if [ -z "$GIT_DIR" ]; then
    echo "❌ 錯誤: 不在 Git 倉庫中"
    exit 1
fi

HOOKS_DIR="$GIT_DIR/hooks"
PROJECT_ROOT=$(git rev-parse --show-toplevel)

# ================================
# Pre-commit Hook
# ================================

cat > "$HOOKS_DIR/pre-commit" << 'EOF'
#!/bin/bash

echo "🔍 運行 pre-commit 驗證..."

# 切換到項目根目錄
cd "$(git rev-parse --show-toplevel)/apps/ios/Havital"

# 運行快速靜態檢查 (跳過編譯和測試，加快速度)
./Scripts/validate_managers.sh --quick

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Pre-commit 驗證失敗！"
    echo "   提示: 可以使用 'git commit --no-verify' 跳過驗證 (不推薦)"
    exit 1
fi

echo "✅ Pre-commit 驗證通過"
exit 0
EOF

chmod +x "$HOOKS_DIR/pre-commit"
echo "✅ Pre-commit hook 已安裝"

# ================================
# Pre-push Hook
# ================================

cat > "$HOOKS_DIR/pre-push" << 'EOF'
#!/bin/bash

echo "🔍 運行 pre-push 完整驗證..."

# 切換到項目根目錄
cd "$(git rev-parse --show-toplevel)/apps/ios/Havital"

# 運行完整驗證 (包括編譯和測試)
./Scripts/validate_managers.sh

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Pre-push 驗證失敗！"
    echo "   提示: 可以使用 'git push --no-verify' 跳過驗證 (不推薦)"
    exit 1
fi

echo "✅ Pre-push 驗證通過"
exit 0
EOF

chmod +x "$HOOKS_DIR/pre-push"
echo "✅ Pre-push hook 已安裝"

# ================================
# 測試 Hook
# ================================

echo ""
echo "🧪 測試 Git Hooks..."
if "$HOOKS_DIR/pre-commit"; then
    echo "✅ Pre-commit hook 測試通過"
else
    echo "⚠️  Pre-commit hook 測試失敗 (可能是警告)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Git Hooks 設置完成！"
echo ""
echo "現在每次 commit 和 push 都會自動驗證 Manager 架構"
echo ""
echo "如需跳過驗證 (不推薦):"
echo "  git commit --no-verify"
echo "  git push --no-verify"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
