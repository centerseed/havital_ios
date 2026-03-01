# Manager 自動化驗證工具

## 🚀 快速使用

### 方案 A: 代碼檢查 (推薦用於日常開發)

```bash
# 1. 一次性設置 Git Hooks
./Scripts/setup_git_hooks.sh

# 2. 手動快速檢查 (~10秒)
./Scripts/validate_managers.sh --quick

# 3. 完整檢查 (~5分鐘，包括編譯和測試)
./Scripts/validate_managers.sh
```

### 方案 B: 緩存測試 (用於驗證 API 層)

```bash
# 方式 1: 自動化測試 (完整流程，約 10 分鐘)
./Scripts/test_with_cache_clear.sh

# 方式 2: 手動測試 (推薦，更靈活)
./Scripts/clear_simulator_cache.sh  # 清空緩存
# 然後手動打開 Simulator 中的 App，查看日誌
```

## 驗證內容

### 自動檢查項目
1. ✅ Dictionary 安全性 (Date 不能作為 key)
2. ✅ TaskManageable 實現 (taskRegistry)
3. ⚠️ 任務取消處理
4. ⚠️ weak self 使用
5. ✅ 編譯通過
6. ✅ 日誌覆蓋率
7. ⚠️ API 追蹤覆蓋率
8. ✅ 雙軌緩存模式
9. ✅ 初始化順序

### 結果說明
- **✅ 通過**: 沒有問題
- **⚠️ 警告**: 建議修復，不阻止提交
- **❌ 錯誤**: 必須修復才能提交

## Git Hooks

安裝後:
- **Pre-commit**: 每次 `git commit` 前運行快速檢查
- **Pre-push**: 每次 `git push` 前運行完整驗證

跳過驗證 (不推薦):
```bash
git commit --no-verify
git push --no-verify
```

## 報告

每次驗證會生成報告: `validation_report_YYYYMMDD_HHMMSS.txt`

查看最新報告:
```bash
ls -t validation_report_*.txt | head -1 | xargs cat
```

## 🧪 緩存測試詳解

### 為什麼需要緩存測試？

因為雙軌緩存的存在：
- ✅ **有緩存**: App 總是立即顯示數據 → 看起來正常
- ❌ **無緩存**: 才會真正測試 API 層 → 可能發現問題

### 完整測試流程 (推薦)

```bash
# 1. 清空緩存
./Scripts/clear_simulator_cache.sh

# 2. 啟動 Simulator 和 App
# (在 Xcode 中運行，或手動打開)

# 3. 查看 Xcode Console 日誌
# 應該看到:
#   📡 [API Call] TrainingPlanView: loadPlanStatus → GET /plan/...
#   ✅ [API End] TrainingPlanView: loadPlanStatus → 200 | 0.45s

# 4. 驗證雙軌緩存
# - 第一次打開: 從 API 載入 (無緩存)
# - 下拉刷新: 背景更新
# - 關閉 App
# - 第二次打開: 立即顯示緩存 + 背景刷新
```

### 預期日誌輸出

**無緩存時 (第一次打開)**:
```
📱 [TrainingPlanManager] 開始載入
📡 [API 調用] 從 API 載入 (無緩存)
✅ [API End] 載入成功
```

**有緩存時 (第二次打開)**:
```
📱 [TrainingPlanManager] 開始載入
✅ [緩存命中] 立即顯示緩存
🔄 [背景刷新] 開始
✅ [背景刷新] 完成
```

## 常見問題

**Q: 驗證失敗怎麼辦？**
A: 查看報告文件，修復標記為 ❌ 的錯誤

**Q: 警告必須修復嗎？**
A: 不強制，但建議修復以提高代碼質量

**Q: 如何禁用自動驗證？**
A: 刪除 `.git/hooks/pre-commit` 和 `.git/hooks/pre-push`
