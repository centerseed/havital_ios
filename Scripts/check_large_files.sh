#!/usr/bin/env bash
# 擋下單檔超過 10 MB 的 commit。錄影、模擬器輸出、build 產物不進 git——
# 0e69e4cd 曾把 566M 的 maestro 錄影一起 commit，GitHub 拒收整段歷史。
set -euo pipefail
LIMIT=$((10 * 1024 * 1024))
status=0
while IFS= read -r -d '' path; do
  size=$(git cat-file -s ":$path" 2>/dev/null || echo 0)
  if [ "$size" -gt "$LIMIT" ]; then
    echo "❌ $path 有 $((size / 1024 / 1024)) MB，超過 10 MB，不能進 git"
    status=1
  fi
done < <(git diff --cached --name-only --diff-filter=AM -z)
if [ "$status" -ne 0 ]; then
  echo "   錄影、截圖、log 放 scratchpad 或 .gitignore 的目錄，不要 commit。"
fi
exit "$status"
