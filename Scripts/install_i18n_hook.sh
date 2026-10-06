#!/usr/bin/env bash
# 安裝 i18n 防飄移 pre-commit gate 到本 checkout 的 .git/hooks。
# .git/hooks 不進版控,新 checkout 需執行一次本腳本。
set -euo pipefail
REPO="$(git rev-parse --show-toplevel)"
HOOKS_DIR="$(cd "$(git rev-parse --git-common-dir)" && pwd)/hooks"
mkdir -p "$HOOKS_DIR"
HOOK="$HOOKS_DIR/pre-commit"

# 若已存在非 i18n 的 pre-commit,鏈接而非覆蓋
if [[ -f "$HOOK" ]] && ! grep -q "i18n_lint.py" "$HOOK"; then
  echo "⚠️  已有 pre-commit,將 i18n 檢查附加在前。原 hook 備份為 pre-commit.bak"
  cp "$HOOK" "$HOOK.bak"
  cat > "$HOOK" <<EOF
#!/usr/bin/env bash
REPO="\$(git rev-parse --show-toplevel)"
"\$REPO/Scripts/check_large_files.sh" || exit 1
python3 "\$REPO/Scripts/i18n_lint.py" || { echo "❌ i18n pre-commit gate 未通過 (--no-verify 可跳過,不推薦)"; exit 1; }
exec "$HOOK.bak"
EOF
else
  cat > "$HOOK" <<'EOF'
#!/usr/bin/env bash
REPO="$(git rev-parse --show-toplevel)"
"$REPO/Scripts/check_large_files.sh" || exit 1
if ! python3 "$REPO/Scripts/i18n_lint.py"; then
  echo ""
  echo "❌ i18n pre-commit gate 未通過。修正後再 commit。"
  echo "   緊急跳過(不推薦): git commit --no-verify"
  exit 1
fi
exit 0
EOF
fi
chmod +x "$HOOK"
echo "✅ i18n pre-commit gate 已安裝: $HOOK"
echo "🧪 試跑一次:"
python3 "$REPO/Scripts/i18n_lint.py" --strings
