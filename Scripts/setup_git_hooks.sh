#!/bin/bash
#
# 安裝本專案的 git hooks。hooks 不進版控，新 clone / 新 worktree 後要跑這支。
#
# 目前兩道關：
#   pre-commit — i18n 防飄移（.strings 三語完整性 + staged Swift 寫死 CJK）
#   pre-push   — unit tests + 測試數量地板
#
# 註：本檔舊版會寫入一份呼叫 Scripts/validate_managers.sh 的 hook，並 cd 到
# `$(git rev-parse --show-toplevel)/apps/ios/Havital`。apps/ios/Havital 本身就是
# 一個獨立 git repo，toplevel 已經是它，那個路徑解不出來；而且它會覆蓋掉真正在用的
# i18n pre-commit。已改為安裝實際在用的兩道關。

set -euo pipefail

echo "🔧 設置 Git Hooks..."

if ! GIT_COMMON_DIR=$(git rev-parse --git-common-dir 2>/dev/null); then
    echo "❌ 錯誤: 不在 Git 倉庫中"
    exit 1
fi

# worktree 的 .git 是檔案不是目錄；hooks 一律放在 common dir，所有 worktree 共用
HOOKS_DIR="$(cd "$GIT_COMMON_DIR" && pwd)/hooks"
REPO_ROOT=$(git rev-parse --show-toplevel)
mkdir -p "$HOOKS_DIR"

# ================================
# Pre-commit: i18n 防飄移
# ================================

if [ -x "$REPO_ROOT/scripts/install_i18n_hook.sh" ]; then
    "$REPO_ROOT/scripts/install_i18n_hook.sh"
else
    cat > "$HOOKS_DIR/pre-commit" << 'HOOK'
#!/usr/bin/env bash
# i18n 防飄移 gate
REPO="$(git rev-parse --show-toplevel)"
if ! python3 "$REPO/Scripts/i18n_lint.py"; then
  echo ""
  echo "❌ i18n pre-commit gate 未通過。修正後再 commit。"
  echo "   緊急跳過(不推薦): git commit --no-verify"
  exit 1
fi
exit 0
HOOK
    chmod +x "$HOOKS_DIR/pre-commit"
fi
echo "✅ Pre-commit hook 已安裝（i18n 防飄移）"

# ================================
# Pre-push: unit tests + 測試數量地板
# ================================

cat > "$HOOKS_DIR/pre-push" << 'HOOK'
#!/usr/bin/env bash
# 單元測試 gate — 由 scripts/setup_git_hooks.sh 安裝
#
# 為什麼要有這道關：六次存檔丟欄位的 regression（74dc9396 / 24529353 / 72561b1a /
# 757d4329 / bd1e4d48 / f696f05e）全部是在「測試存在但沒人跑」的狀態下 ship 出去的。
# 專案沒有 CI，push 是唯一還來得及攔的時機。
#
# 只跑 unit：整套 all 會拉到 UI/Integration，時間長到一定會被 --no-verify 繞過，
# 那就變成裝飾品。UI 與 Maestro 維持人工 / 發版前跑。
#
# 模擬器選擇、iPhone 17 Pro、-parallel-testing-enabled NO 等規則一律沿用
# scripts/test.sh，這裡不重寫一份。
REPO="$(git rev-parse --show-toplevel)"

if [ ! -x "$REPO/scripts/test.sh" ]; then
  echo "⚠️  找不到 scripts/test.sh，略過 unit test gate。"
  exit 0
fi

echo "🧪 pre-push: 執行 unit tests（略過需 --no-verify）..."
START=$(date +%s)

if ! "$REPO/scripts/test.sh" unit; then
  echo ""
  echo "❌ pre-push gate 未通過：unit tests 失敗，或測試數量低於地板。"
  echo "   緊急跳過(不推薦): git push --no-verify"
  exit 1
fi

echo "✅ pre-push gate 通過（$(($(date +%s) - START))s）"
exit 0
HOOK

chmod +x "$HOOKS_DIR/pre-push"
echo "✅ Pre-push hook 已安裝（unit tests + 數量地板）"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Git Hooks 設置完成（$HOOKS_DIR）"
echo ""
echo "如需跳過驗證 (不推薦):"
echo "  git commit --no-verify"
echo "  git push --no-verify"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
